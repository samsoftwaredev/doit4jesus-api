import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireUser } from '@/lib/auth/require-user';
import { loadLegalAcceptance } from '@/lib/profiles/current-profile';
import { legalAcceptanceSchema } from '@/lib/schemas/legal-acceptance';

export const dynamic = 'force-dynamic';

export async function POST(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const input = legalAcceptanceSchema.parse(await readJson(request));
    const { error } = await supabase
      .schema('api')
      .rpc('accept_current_user_legal_documents', {
        p_accepted_locale: input.locale,
        p_adult_confirmed: input.adultConfirmed,
        p_us_resident_confirmed: input.usResidentConfirmed,
      });

    throwDatabaseError(error, 'Unable to record legal acceptance.');

    return ok(await loadLegalAcceptance(supabase), {
      headers: { 'Cache-Control': 'no-store' },
    });
  } catch (error) {
    return errorResponse(error, request);
  }
}
