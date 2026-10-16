import { throwDatabaseError } from '@/lib/api/database';
import { errorResponse, ok } from '@/lib/api/response';
import { requireAdmin } from '@/lib/auth/require-admin';

export const dynamic = 'force-dynamic';

const previewLimit = 3;

export async function GET(request: Request) {
  try {
    const { supabase } = await requireAdmin(request);

    const [
      contactCountResult,
      prayerCountResult,
      churchCountResult,
      eventCountResult,
    ] = await Promise.all([
      supabase
        .schema('app')
        .from('contact_requests')
        .select('*', { count: 'exact', head: true })
        .in('status', ['todo', 'inprogress']),
      supabase
        .schema('prayer')
        .from('prayer_intentions')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'pending'),
      supabase
        .schema('app')
        .from('church_change_requests')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'pending'),
      supabase
        .schema('app')
        .from('events')
        .select('*', { count: 'exact', head: true })
        .eq('status', 'pending'),
    ]);

    throwDatabaseError(contactCountResult.error, 'Unable to count contacts.');
    throwDatabaseError(
      prayerCountResult.error,
      'Unable to count prayer intentions.',
    );
    throwDatabaseError(
      churchCountResult.error,
      'Unable to count church change requests.',
    );
    throwDatabaseError(eventCountResult.error, 'Unable to count events.');

    const [
      contactPreviewResult,
      prayerPreviewResult,
      churchPreviewResult,
      eventPreviewResult,
    ] = await Promise.all([
      supabase
        .schema('app')
        .from('contact_requests')
        .select('id, name, subject, created_at')
        .in('status', ['todo', 'inprogress'])
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .limit(previewLimit),
      supabase
        .schema('prayer')
        .from('prayer_intentions')
        .select('id, title, created_at')
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .limit(previewLimit),
      supabase
        .schema('app')
        .from('church_change_requests')
        .select('id, request_type, church_id, created_at')
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .limit(previewLimit),
      supabase
        .schema('app')
        .from('events')
        .select('id, title, starts_at, created_at')
        .eq('status', 'pending')
        .order('created_at', { ascending: false })
        .order('id', { ascending: false })
        .limit(previewLimit),
    ]);

    throwDatabaseError(
      contactPreviewResult.error,
      'Unable to load contact previews.',
    );
    throwDatabaseError(
      prayerPreviewResult.error,
      'Unable to load prayer intention previews.',
    );
    throwDatabaseError(
      churchPreviewResult.error,
      'Unable to load church change request previews.',
    );
    throwDatabaseError(
      eventPreviewResult.error,
      'Unable to load event previews.',
    );

    const contacts = {
      count: contactCountResult.count ?? 0,
      items: (contactPreviewResult.data ?? []).map((contact) => ({
        id: contact.id,
        name: contact.name,
        subject: contact.subject,
        createdAt: contact.created_at,
      })),
    };
    const prayerIntentions = {
      count: prayerCountResult.count ?? 0,
      items: (prayerPreviewResult.data ?? []).map((intention) => ({
        id: intention.id,
        title: intention.title,
        createdAt: intention.created_at,
      })),
    };
    const churchChangeRequests = {
      count: churchCountResult.count ?? 0,
      items: (churchPreviewResult.data ?? []).map((changeRequest) => ({
        id: changeRequest.id,
        requestType: changeRequest.request_type,
        churchId: changeRequest.church_id,
        createdAt: changeRequest.created_at,
      })),
    };
    const events = {
      count: eventCountResult.count ?? 0,
      items: (eventPreviewResult.data ?? []).map((event) => ({
        id: event.id,
        title: event.title,
        startsAt: event.starts_at,
        createdAt: event.created_at,
      })),
    };

    return ok(
      {
        total:
          contacts.count +
          prayerIntentions.count +
          churchChangeRequests.count +
          events.count,
        contacts,
        prayerIntentions,
        churchChangeRequests,
        events,
      },
      { headers: { 'Cache-Control': 'no-store' } },
    );
  } catch (error) {
    return errorResponse(error, request);
  }
}
