import { loadPrayerIntentions } from '../src/lib/screen-data/loaders';

describe('screen-data prayer-intention loader', () => {
  it('includes the creator ID required by the Prayer by Others cards', async () => {
    const creatorId = '11111111-1111-4111-8111-111111111111';
    const row = {
      id: 'd9000000-0000-4000-8000-000000000001',
      creator_id: creatorId,
      title: 'Praying for my brother',
      description: 'He is currently having back pain.',
      symbol: 'candle',
      approved_at: '2026-11-01T12:00:00.000Z',
      expires_at: '2026-12-01T12:00:00.000Z',
      created_at: '2026-11-01T12:00:00.000Z',
      creator_display_name: 'Michael R.',
      creator_avatar_url: null,
      creator_country_code: 'US',
      prayer_count: 4,
    };
    const query: Record<string, jest.Mock> = {};
    for (const method of ['select', 'order'] as const) {
      query[method] = jest.fn().mockReturnValue(query);
    }
    query.range = jest.fn().mockResolvedValue({ data: [row], error: null });
    const context = {
      userId: creatorId,
      supabase: {
        schema: jest.fn(() => ({ from: jest.fn(() => query) })),
      },
    } as never;

    const result = await loadPrayerIntentions(context);

    expect(result.data).toEqual([
      expect.objectContaining({
        id: row.id,
        creator: {
          userId: creatorId,
          displayName: 'Michael R.',
          avatarUrl: null,
          countryCode: 'US',
        },
      }),
    ]);
  });
});
