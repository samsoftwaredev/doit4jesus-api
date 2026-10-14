import { z } from 'zod';

import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, noContent } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';

export const dynamic = 'force-dynamic';
type Context = { params: Promise<{ recipientId: string }> };

export async function DELETE(request: Request, context: Context) {
  try {
    const recipientId = z.uuid().parse((await context.params).recipientId);
    const { supabase } = await requireAdmin(request);
    const { error } = await supabase
      .schema('app')
      .from('email_test_recipients')
      .delete()
      .eq('id', recipientId);
    throwDatabaseError(error, 'Unable to remove the test recipient.');
    return noContent();
  } catch (error) {
    return errorResponse(error, request);
  }
}
