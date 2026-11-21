import { throwDatabaseError } from '@/lib/api/database';
import { ApiError } from '@/lib/api/errors';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import {
  churchToRpcPayload,
  serviceTimesToRpcPayload,
} from '@/lib/churches/admin-rpc';
import {
  importAdminChurchesSchema,
  importChurchEntrySchema,
} from '@/lib/schemas/church-subscription';

export const dynamic = 'force-dynamic';

type ImportResult = {
  index: number;
  label: string;
  action: 'create' | 'update' | 'ambiguous' | 'invalid' | 'error';
  applied: boolean;
  message?: string;
  churchId?: string;
  churchName?: string;
  currentServiceTimes?: unknown;
  proposedServiceTimes?: unknown;
};

function labelOf(entry: unknown, index: number) {
  const candidate = entry as {
    label?: unknown;
    church?: { name?: unknown };
  } | null;
  if (typeof candidate?.label === 'string' && candidate.label.trim())
    return candidate.label.trim();
  return typeof candidate?.church?.name === 'string' && candidate.church.name
    ? candidate.church.name
    : `Church #${index + 1}`;
}

/**
 * Imports church schedules from a JSON file. With dryRun (the default) it only reports what would be created or
 * updated; with dryRun false it applies each valid church independently.
 */
export async function POST(request: Request) {
  try {
    const input = importAdminChurchesSchema.parse(await readJson(request));
    const { supabase } = await requireAdmin(request);
    const results: ImportResult[] = [];

    for (const [index, raw] of input.churches.entries()) {
      const label = labelOf(raw, index);
      const parsed = importChurchEntrySchema.safeParse(raw);
      if (!parsed.success) {
        results.push({
          index,
          label,
          action: 'invalid',
          applied: false,
          message: parsed.error.issues
            .slice(0, 3)
            .map(
              (issue) => `${issue.path.join('.') || 'entry'}: ${issue.message}`,
            )
            .join('; '),
        });
        continue;
      }

      const entry = parsed.data;
      const { data, error } = await supabase
        .schema('api')
        .rpc('admin_import_church_schedule', {
          p_church_id: entry.churchId ?? null,
          p_church: churchToRpcPayload(entry.church ?? {}),
          p_service_times: serviceTimesToRpcPayload(entry.serviceTimes),
          p_dry_run: input.dryRun,
        });

      try {
        throwDatabaseError(error, 'Unable to import this church.');
      } catch (failure) {
        results.push({
          index,
          label,
          action: 'error',
          applied: false,
          message:
            failure instanceof ApiError
              ? failure.message
              : 'Unable to import this church.',
        });
        continue;
      }

      const outcome = (data ?? {}) as Record<string, unknown>;
      const action = outcome.action as ImportResult['action'];
      results.push({
        index,
        label,
        action,
        applied: !input.dryRun && (action === 'create' || action === 'update'),
        message:
          action === 'ambiguous'
            ? `${String(outcome.matches)} churches match this name and address; add churchId to choose one.`
            : typeof outcome.reason === 'string'
              ? outcome.reason
              : undefined,
        churchId:
          typeof outcome.churchId === 'string' ? outcome.churchId : undefined,
        churchName:
          typeof outcome.churchName === 'string' ? outcome.churchName : label,
        currentServiceTimes: outcome.currentServiceTimes,
        proposedServiceTimes: entry.serviceTimes,
      });
    }

    const count = (action: ImportResult['action']) =>
      results.filter((result) => result.action === action).length;
    return ok(
      {
        dryRun: input.dryRun,
        results,
        summary: {
          create: count('create'),
          update: count('update'),
          failed: results.length - count('create') - count('update'),
        },
      },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
