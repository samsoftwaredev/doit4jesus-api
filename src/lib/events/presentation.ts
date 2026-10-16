type EventRow = {
  id: string;
  creator_id?: string;
  title: string;
  description: string;
  image_url: string | null;
  event_url: string | null;
  event_type: 'online' | 'physical';
  online_url: string | null;
  location_name: string | null;
  address_line_1: string | null;
  address_line_2: string | null;
  city: string | null;
  region_name: string | null;
  postal_code: string | null;
  country_code: string | null;
  timezone: string;
  starts_at: string;
  ends_at: string;
  lifespan_days: number;
  audiences: (
    | 'all'
    | 'kids'
    | 'youth'
    | 'men'
    | 'women'
    | 'single'
    | 'married'
  )[];
  created_at: string;
  attendee_count: number;
  view_count: number;
  status?: 'pending' | 'active' | 'inactive' | 'rejected';
  reviewed_by?: string | null;
  reviewed_at?: string | null;
  approved_at?: string;
  expires_at?: string | null;
};

export function toEventResponse(row: EventRow, includeModeration = false) {
  const location =
    row.event_type === 'physical'
      ? {
          name: row.location_name,
          addressLine1: row.address_line_1,
          addressLine2: row.address_line_2,
          city: row.city,
          regionName: row.region_name,
          postalCode: row.postal_code,
          countryCode: row.country_code,
        }
      : null;

  return {
    id: row.id,
    title: row.title,
    description: row.description,
    imageUrl: row.image_url,
    eventUrl: row.event_url,
    eventType: row.event_type,
    onlineUrl: row.event_type === 'online' ? row.online_url : null,
    location,
    timezone: row.timezone,
    startsAt: row.starts_at,
    endsAt: row.ends_at,
    lifespanDays: row.lifespan_days,
    audiences: row.audiences,
    approvedAt: row.approved_at ?? row.reviewed_at ?? null,
    expiresAt: row.expires_at ?? null,
    createdAt: row.created_at,
    attendeeCount: row.attendee_count,
    viewCount: row.view_count,
    ...(includeModeration
      ? {
          status: row.status,
          creatorId: row.creator_id ?? null,
          reviewedBy: row.reviewed_by ?? null,
          reviewedAt: row.reviewed_at ?? null,
        }
      : {}),
  };
}
