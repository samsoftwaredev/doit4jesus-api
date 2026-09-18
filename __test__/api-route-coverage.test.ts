import {
  GET as getActivities,
  POST as postActivity,
} from '../src/app/api/v1/activities/route';
import { PATCH as reviewChurchChangeRequest } from '../src/app/api/v1/admin/church-change-requests/[requestId]/route';
import { GET as getAdminChurchChangeRequests } from '../src/app/api/v1/admin/church-change-requests/route';
import { GET as getBadges } from '../src/app/api/v1/badges/route';
import { POST as claimChallenge } from '../src/app/api/v1/challenges/[assignmentId]/claim/route';
import { GET as getChallenges } from '../src/app/api/v1/challenges/route';
import {
  GET as getChurchChangeRequests,
  POST as postChurchChangeRequest,
} from '../src/app/api/v1/church-change-requests/route';
import { GET as getChurch } from '../src/app/api/v1/churches/[churchId]/route';
import { GET as searchChurches } from '../src/app/api/v1/churches/route';
import { GET as getDemon } from '../src/app/api/v1/demons/[demonCode]/route';
import { GET as getDemons } from '../src/app/api/v1/demons/route';
import { POST as abandonEncounter } from '../src/app/api/v1/encounters/[encounterId]/abandon/route';
import { POST as completeDefense } from '../src/app/api/v1/encounters/[encounterId]/defenses/[assignmentId]/complete/route';
import { GET as getEncounter } from '../src/app/api/v1/encounters/[encounterId]/route';
import {
  GET as getEncounters,
  POST as startEncounter,
} from '../src/app/api/v1/encounters/route';
import { GET as healthCheck } from '../src/app/api/v1/health/route';
import { GET as getLevels } from '../src/app/api/v1/levels/route';
import {
  PATCH as setPrimaryChurch,
  DELETE as unlinkChurch,
} from '../src/app/api/v1/me/churches/[churchId]/route';
import {
  GET as getMyChurches,
  POST as linkChurch,
} from '../src/app/api/v1/me/churches/route';
import {
  DELETE as cancelFriendRequest,
  PATCH as reviewFriendRequest,
} from '../src/app/api/v1/me/friend-requests/[requestId]/route';
import { POST as sendFriendRequest } from '../src/app/api/v1/me/friend-requests/route';
import { DELETE as unfriend } from '../src/app/api/v1/me/friends/[friendId]/route';
import { GET as getFriendsComparison } from '../src/app/api/v1/me/friends/comparison/route';
import { GET as getFriendsLeaderboard } from '../src/app/api/v1/me/friends/leaderboard/route';
import { GET as getFriends } from '../src/app/api/v1/me/friends/route';
import { GET as getRosaryCompletion } from '../src/app/api/v1/me/rosary/completion/route';
import { GET as getRosaryReminder } from '../src/app/api/v1/me/rosary/reminder/route';
import { GET as getRosaryStats } from '../src/app/api/v1/me/rosary/stats/route';
import { GET as getRosaryStreak } from '../src/app/api/v1/me/rosary/streak/route';
import { PATCH as markNotificationRead } from '../src/app/api/v1/notifications/[notificationId]/read/route';
import { GET as getNotifications } from '../src/app/api/v1/notifications/route';
import { GET as getPrayerMap } from '../src/app/api/v1/prayer-map/route';
import { GET as getProgress } from '../src/app/api/v1/progress/route';
import { GET as searchUsers } from '../src/app/api/v1/users/search/route';
import { GET as getVirtues } from '../src/app/api/v1/virtues/route';
import { requireUser } from '../src/lib/auth/require-user';

jest.mock('../src/lib/auth/require-user', () => ({
  requireUser: jest.fn(),
}));

jest.mock('../src/lib/api/response', () => ({
  ok: (data: unknown, _init: unknown, meta?: unknown) => ({
    status: 200,
    json: async () => (meta ? { data, meta } : { data }),
  }),
  created: (data: unknown) => ({ status: 201, json: async () => ({ data }) }),
  noContent: () => ({ status: 204, json: async () => null }),
  errorResponse: (error: unknown) => ({ status: 500, error }),
}));

const mockedRequireUser = jest.mocked(requireUser);

const USER_ID = '11111111-1111-4111-8111-111111111111';
const RESOURCE_ID = '22222222-2222-4222-8222-222222222222';

type QueryResult = { data: unknown; error: null };
type RouteFixture = {
  tableResults?: Record<string, QueryResult>;
  rpcResults?: Record<string, QueryResult>;
};

const result = (data: unknown = []): QueryResult => ({ data, error: null });

function createQuery(queryResult: QueryResult) {
  const query: Record<
    string,
    jest.Mock | ((...args: unknown[]) => Promise<QueryResult>)
  > = {};
  const chainMethods = [
    'select',
    'eq',
    'order',
    'limit',
    'lt',
    'range',
    'in',
    'is',
    'gte',
    'lte',
    'insert',
    'update',
  ];

  for (const method of chainMethods) {
    query[method] = jest.fn(() => query);
  }

  query.single = jest.fn().mockResolvedValue(queryResult);
  query.maybeSingle = jest.fn().mockResolvedValue(queryResult);
  query.then = (onFulfilled: (value: QueryResult) => unknown) =>
    Promise.resolve(queryResult).then(onFulfilled);

  return query;
}

function createSupabase(fixture: RouteFixture = {}) {
  const from = jest.fn((table: string) =>
    createQuery(fixture.tableResults?.[table] ?? result()),
  );
  const storageFrom = jest.fn((bucket: string) => ({
    getPublicUrl: jest.fn((path: string) => ({
      data: {
        publicUrl: `https://storage.example.test/${bucket}/${path}`,
      },
    })),
  }));
  const rpc = jest.fn((name: string) =>
    Promise.resolve(fixture.rpcResults?.[name] ?? result()),
  );
  const supabase = {
    schema: jest.fn(() => ({ from, rpc })),
    storage: { from: storageFrom },
  };

  mockedRequireUser.mockResolvedValue({ supabase, userId: USER_ID } as never);
  return { from, rpc, storageFrom, supabase };
}

function request(
  url: string,
  init: {
    method?: string;
    headers?: Record<string, string>;
    body?: string;
  } = {},
) {
  const headers = Object.fromEntries(
    Object.entries(init.headers ?? {}).map(([name, value]) => [
      name.toLowerCase(),
      value,
    ]),
  );

  return {
    url,
    method: init.method ?? 'GET',
    headers: { get: (name: string) => headers[name.toLowerCase()] ?? null },
    json: async () => (init.body ? JSON.parse(init.body) : undefined),
  } as Request;
}

function jsonRequest(
  url: string,
  body: unknown,
  headers: Record<string, string> = {},
) {
  return request(url, {
    method: 'POST',
    headers: { 'content-type': 'application/json', ...headers },
    body: JSON.stringify(body),
  });
}

function context(params: Record<string, string>) {
  return { params: Promise.resolve(params) };
}

function expectOk(response: { status: number; error?: unknown }) {
  if (response.error) throw response.error;
  expect(response.status).toBe(200);
}

describe('previously uncovered API route handlers', () => {
  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('lists and records activities', async () => {
    createSupabase({
      rpcResults: { record_spiritual_activity: result({ id: RESOURCE_ID }) },
    });

    expectOk(
      await getActivities(request('http://localhost/api/v1/activities')),
    );
    const response = await postActivity(
      jsonRequest(
        'http://localhost/api/v1/activities',
        {
          activityCode: 'rosary',
          occurredAt: '2026-08-22T12:00:00.000Z',
          quantity: 1,
        },
        { 'idempotency-key': 'activity-1' },
      ),
    );

    expect(response.status).toBe(201);
  });

  it('lists and reviews church-change requests for administrators', async () => {
    const { rpc } = createSupabase({
      rpcResults: {
        is_current_user_admin: result(true),
        review_church_change_request: result({
          id: RESOURCE_ID,
          status: 'approved',
        }),
      },
    });

    expectOk(
      await getAdminChurchChangeRequests(
        request('http://localhost/api/v1/admin/church-change-requests'),
      ),
    );
    expectOk(
      await reviewChurchChangeRequest(
        jsonRequest(
          'http://localhost/api/v1/admin/church-change-requests/' + RESOURCE_ID,
          {
            decision: 'approved',
          },
        ),
        context({ requestId: RESOURCE_ID }),
      ),
    );
    expect(rpc).toHaveBeenCalledWith('review_church_change_request', {
      p_request_id: RESOURCE_ID,
      p_decision: 'approved',
      p_rejection_reason: null,
    });
  });

  it('returns badge definitions with user progress', async () => {
    const { storageFrom } = createSupabase({
      tableResults: {
        badge_definitions: result([
          {
            id: RESOURCE_ID,
            icon_url: '/badges/first-rosary.png',
            locked_icon_url: '/badges/locked.png',
          },
        ]),
      },
    });
    const response = await getBadges(request('http://localhost/api/v1/badges'));

    expectOk(response);
    await expect(response.json()).resolves.toMatchObject({
      data: [
        {
          definition: {
            icon_url:
              'https://storage.example.test/images/badges/first-rosary.png',
            locked_icon_url:
              'https://storage.example.test/images/badges/locked.png',
          },
        },
      ],
    });
    expect(storageFrom).toHaveBeenCalledWith('images');
  });

  it('lists challenges and claims a challenge reward', async () => {
    createSupabase({
      rpcResults: { claim_challenge_reward: result({ claimed: true }) },
    });

    expectOk(
      await getChallenges(
        request('http://localhost/api/v1/challenges?status=active'),
      ),
    );
    expectOk(
      await claimChallenge(
        request(
          'http://localhost/api/v1/challenges/' + RESOURCE_ID + '/claim',
          {
            method: 'POST',
            headers: { 'idempotency-key': 'challenge-claim-1' },
          },
        ),
        context({ assignmentId: RESOURCE_ID }),
      ),
    );
  });

  it('lists and submits a church-change request', async () => {
    createSupabase();
    expectOk(
      await getChurchChangeRequests(
        request('http://localhost/api/v1/church-change-requests'),
      ),
    );

    const response = await postChurchChangeRequest(
      jsonRequest('http://localhost/api/v1/church-change-requests', {
        requestType: 'createChurch',
        church: {
          name: 'St Joseph Church',
          addressLine1: '100 Main Street',
          city: 'Dallas',
          countryCode: 'US',
          timezone: 'America/Chicago',
          latitude: 32.7767,
          longitude: -96.797,
        },
        serviceTimes: [
          { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
        ],
      }),
    );
    expect(response.status).toBe(201);
  });

  it('searches churches and returns a church detail', async () => {
    createSupabase();
    expectOk(
      await searchChurches(
        request('http://localhost/api/v1/churches?countryCode=US'),
      ),
    );

    createSupabase({
      tableResults: {
        churches: result({
          id: RESOURCE_ID,
          name: 'St Joseph Church',
          diocese_id: null,
          address_line_1: '100 Main Street',
          address_line_2: null,
          city: 'Dallas',
          region_name: 'Texas',
          postal_code: '75201',
          country_code: 'US',
          timezone: 'America/Chicago',
          latitude: 32.7767,
          longitude: -96.797,
        }),
      },
    });
    expectOk(
      await getChurch(
        request('http://localhost/api/v1/churches/' + RESOURCE_ID),
        context({ churchId: RESOURCE_ID }),
      ),
    );
  });

  it('lists demons and returns a demon detail', async () => {
    createSupabase();
    expectOk(await getDemons(request('http://localhost/api/v1/demons')));

    createSupabase({
      tableResults: {
        demon_definitions: result({
          id: RESOURCE_ID,
          code: 'PRIDE',
          saint_mentor_id: null,
        }),
      },
    });
    expectOk(
      await getDemon(
        request('http://localhost/api/v1/demons/pride'),
        context({ demonCode: 'pride' }),
      ),
    );
  });

  it('lists, starts, details, abandons, and completes encounter work', async () => {
    createSupabase();
    expectOk(
      await getEncounters(request('http://localhost/api/v1/encounters')),
    );

    createSupabase({
      tableResults: {
        user_demon_encounters: result({ id: RESOURCE_ID, demon_id: 'demon-1' }),
        demon_definitions: result({ id: 'demon-1', code: 'PRIDE' }),
      },
      rpcResults: {
        start_demon_encounter: result({ id: RESOURCE_ID }),
        abandon_demon_encounter: result({ abandoned: true }),
        complete_demon_defense: result({ completed: true }),
      },
    });

    expect(
      (
        await startEncounter(
          jsonRequest(
            'http://localhost/api/v1/encounters',
            { demonCode: 'pride' },
            { 'idempotency-key': 'encounter-start-1' },
          ),
        )
      ).status,
    ).toBe(201);
    expectOk(
      await getEncounter(
        request('http://localhost/api/v1/encounters/' + RESOURCE_ID),
        context({ encounterId: RESOURCE_ID }),
      ),
    );
    expectOk(
      await abandonEncounter(
        request(
          'http://localhost/api/v1/encounters/' + RESOURCE_ID + '/abandon',
          {
            method: 'POST',
            headers: { 'idempotency-key': 'encounter-abandon-1' },
          },
        ),
        context({ encounterId: RESOURCE_ID }),
      ),
    );
    expectOk(
      await completeDefense(
        request(
          'http://localhost/api/v1/encounters/' +
            RESOURCE_ID +
            '/defenses/' +
            USER_ID,
          {
            method: 'POST',
            headers: { 'idempotency-key': 'defense-complete-1' },
          },
        ),
        context({ encounterId: RESOURCE_ID, assignmentId: USER_ID }),
      ),
    );
  });

  it('returns health and level definitions', async () => {
    const { storageFrom } = createSupabase({
      tableResults: {
        level_definitions: result([
          {
            level_number: 1,
            icon_url: '/levels/awakened-icon.png',
            image_url: 'https://cdn.example.test/levels/awakened.png',
          },
        ]),
      },
    });
    expectOk(await healthCheck());
    const response = await getLevels(request('http://localhost/api/v1/levels'));

    expectOk(response);
    await expect(response.json()).resolves.toMatchObject({
      data: [
        {
          icon_url:
            'https://storage.example.test/images/levels/awakened-icon.png',
          image_url: 'https://cdn.example.test/levels/awakened.png',
        },
      ],
    });
    expect(storageFrom).toHaveBeenCalledTimes(1);
  });

  it('lists, links, prioritizes, and unlinks the current user churches', async () => {
    createSupabase({
      rpcResults: {
        link_current_user_church: result({ created: true }),
        set_current_user_primary_church: result({ churchId: RESOURCE_ID }),
        unlink_current_user_church: result({}),
      },
    });
    expectOk(
      await getMyChurches(request('http://localhost/api/v1/me/churches')),
    );
    expect(
      (
        await linkChurch(
          jsonRequest('http://localhost/api/v1/me/churches', {
            churchId: RESOURCE_ID,
            isPrimary: true,
          }),
        )
      ).status,
    ).toBe(201);
    expectOk(
      await setPrimaryChurch(
        jsonRequest('http://localhost/api/v1/me/churches/' + RESOURCE_ID, {
          isPrimary: true,
        }),
        context({ churchId: RESOURCE_ID }),
      ),
    );
    expect(
      (
        await unlinkChurch(
          request('http://localhost/api/v1/me/churches/' + RESOURCE_ID, {
            method: 'DELETE',
          }),
          context({ churchId: RESOURCE_ID }),
        )
      ).status,
    ).toBe(204);
  });

  it('sends, reviews, cancels, and deletes friend connections', async () => {
    createSupabase({
      rpcResults: {
        send_current_user_friend_request: result({ automatic: false }),
        review_current_user_friend_request: result({ status: 'rejected' }),
        cancel_current_user_friend_request: result({}),
        unfriend_current_user: result({}),
      },
    });
    expect(
      (
        await sendFriendRequest(
          jsonRequest('http://localhost/api/v1/me/friend-requests', {
            username: 'friend',
          }),
        )
      ).status,
    ).toBe(201);
    expectOk(
      await reviewFriendRequest(
        jsonRequest(
          'http://localhost/api/v1/me/friend-requests/' + RESOURCE_ID,
          {
            decision: 'rejected',
          },
        ),
        context({ requestId: RESOURCE_ID }),
      ),
    );
    expect(
      (
        await cancelFriendRequest(
          request('http://localhost/api/v1/me/friend-requests/' + RESOURCE_ID, {
            method: 'DELETE',
          }),
          context({ requestId: RESOURCE_ID }),
        )
      ).status,
    ).toBe(204);
    expect(
      (
        await unfriend(
          request('http://localhost/api/v1/me/friends/' + RESOURCE_ID, {
            method: 'DELETE',
          }),
          context({ friendId: RESOURCE_ID }),
        )
      ).status,
    ).toBe(204);
  });

  it('returns friends, comparison, and friends leaderboard data', async () => {
    createSupabase();
    expectOk(await getFriends(request('http://localhost/api/v1/me/friends')));
    expectOk(
      await getFriendsComparison(
        request(
          'http://localhost/api/v1/me/friends/comparison?periodType=weekly',
        ),
      ),
    );
    expectOk(
      await getFriendsLeaderboard(
        request(
          'http://localhost/api/v1/me/friends/leaderboard?periodType=weekly',
        ),
      ),
    );
  });

  it('returns Rosary completion, reminder, lifetime total, and streak summaries', async () => {
    const { rpc } = createSupabase({
      rpcResults: { get_my_rosary_stats: result({ rosariesPrayed: 42 }) },
    });
    expectOk(
      await getRosaryCompletion(
        request(
          'http://localhost/api/v1/me/rosary/completion?selectedYear=2026&selectedMonth=8',
        ),
      ),
    );
    expectOk(
      await getRosaryReminder(
        request('http://localhost/api/v1/me/rosary/reminder'),
      ),
    );
    expectOk(
      await getRosaryStreak(
        request('http://localhost/api/v1/me/rosary/streak'),
      ),
    );
    const stats = await getRosaryStats(
      request('http://localhost/api/v1/me/rosary/stats'),
    );
    expectOk(stats);
    expect(rpc).toHaveBeenCalledWith('get_my_rosary_stats');
    expect(await stats.json()).toEqual({ data: { rosariesPrayed: 42 } });
  });

  it('lists and marks notifications as read', async () => {
    createSupabase({
      tableResults: { notifications: result({ id: RESOURCE_ID }) },
    });
    expectOk(
      await getNotifications(request('http://localhost/api/v1/notifications')),
    );
    expect(
      (
        await markNotificationRead(
          request(
            'http://localhost/api/v1/notifications/' + RESOURCE_ID + '/read',
            {
              method: 'PATCH',
            },
          ),
          context({ notificationId: RESOURCE_ID }),
        )
      ).status,
    ).toBe(204);
  });

  it('returns prayer-map markers, progress, user search results, and virtues', async () => {
    createSupabase({
      tableResults: {
        user_progress: result({
          current_level: 1,
          total_xp: 50,
          lifetime_points: 50,
          weekly_points: 10,
          yearly_points: 50,
          last_activity_at: null,
          version: 1,
          updated_at: '2026-08-22T12:00:00.000Z',
        }),
        level_definitions: result([
          { level_number: 1, minimum_total_xp: 0 },
          { level_number: 2, minimum_total_xp: 100 },
        ]),
      },
    });
    expectOk(
      await getPrayerMap(
        request(
          'http://localhost/api/v1/prayer-map?level=country&from=2026-08-01T00:00:00.000Z&to=2026-08-31T23:59:59.000Z',
        ),
      ),
    );
    expectOk(await getProgress(request('http://localhost/api/v1/progress')));
    expectOk(
      await searchUsers(request('http://localhost/api/v1/users/search?q=John')),
    );
    expectOk(await getVirtues(request('http://localhost/api/v1/virtues')));
  });
});
