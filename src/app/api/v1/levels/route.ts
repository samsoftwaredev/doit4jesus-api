import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireUser } from '@/lib/auth/require-user';

export const dynamic = 'force-dynamic';

export async function GET(request: Request) {
  try {
    const { supabase } = await requireUser(request);
    const { data, error } = await supabase
      .schema('competition')
      .from('level_definitions')
      .select('*')
      .eq('is_active', true)
      .order('level_number', { ascending: true });

    throwDatabaseError(error, 'Unable to load levels.');
    return ok(data);
  } catch (error) {
    return errorResponse(error, request);
  }
}
