import { throwDatabaseError } from '@/lib/api/database';
import { created, errorResponse } from '@/lib/api/response';
import { readJson } from '@/lib/api/validation';
import { requireAdmin } from '@/lib/auth/require-admin';
import {
  churchToRpcPayload,
  serviceTimesToRpcPayload,
} from '@/lib/churches/admin-rpc';
import { createAdminChurchSchema } from '@/lib/schemas/church-subscription';

export const dynamic = 'force-dynamic';

/** Adds a church missing from the directory, verified, with its recurring schedule. */
export async function POST(request: Request) {
  try {
    const input = createAdminChurchSchema.parse(await readJson(request));
    const { supabase } = await requireAdmin(request);
    const { data, error } = await supabase
      .schema('api')
      .rpc('admin_create_church', {
        p_church: churchToRpcPayload(input.church),
        p_service_times: serviceTimesToRpcPayload(input.serviceTimes),
      });
    throwDatabaseError(error, 'Unable to add the church.');
    return created(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
