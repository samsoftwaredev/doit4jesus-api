import { act } from 'react';
import { type Root, createRoot } from 'react-dom/client';

import { supabaseClient } from '../src/app/classes/supabaseClient';
import AdminQueueBell from '../src/components/admin/AdminQueueBell';

jest.mock('../src/app/classes/supabaseClient', () => {
  const channelApi = {
    on: jest.fn(),
    subscribe: jest.fn(),
  };
  channelApi.on.mockReturnValue(channelApi);
  return {
    supabaseClient: {
      auth: {
        getSession: jest.fn().mockResolvedValue({
          data: { session: { access_token: 'admin-token' } },
        }),
        onAuthStateChange: jest.fn(() => ({
          data: { subscription: { unsubscribe: jest.fn() } },
        })),
      },
      realtime: { setAuth: jest.fn() },
      channel: jest.fn(() => channelApi),
      removeChannel: jest.fn(),
    },
  };
});

const summary = {
  total: 2,
  contacts: { count: 0, items: [] },
  prayerIntentions: { count: 0, items: [] },
  churchChangeRequests: { count: 0, items: [] },
  events: { count: 0, items: [] },
  churchScheduleReviews: {
    count: 1,
    items: [
      {
        id: 'cc000000-0000-4000-8000-000000000001',
        churchId: 'c6000000-0000-4000-8000-000000000005',
        createdAt: '2026-11-07T12:00:00.000Z',
      },
    ],
  },
  safetyReports: {
    count: 1,
    items: [
      {
        id: 'cf000000-0000-4000-8000-000000000001',
        targetType: 'event',
        reason: 'spam_manipulation',
        createdAt: '2026-11-07T12:00:00.000Z',
      },
    ],
  },
};

const reactTestGlobal = globalThis as typeof globalThis & {
  IS_REACT_ACT_ENVIRONMENT: boolean;
};

describe('AdminQueueBell', () => {
  let container: HTMLDivElement;
  let root: Root;
  let originalFetch: typeof fetch;

  beforeEach(() => {
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = true;
    originalFetch = global.fetch;
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: summary }),
    }) as typeof fetch;
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(async () => {
    await act(async () => root.unmount());
    document.body
      .querySelectorAll('[role="presentation"]')
      .forEach((node) => node.remove());
    container.remove();
    global.fetch = originalFetch;
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = false;
    jest.clearAllMocks();
  });

  it('shows church schedule and safety queues and subscribes to their realtime tables', async () => {
    await act(async () => root.render(<AdminQueueBell />));
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 0));
    });

    const button = container.querySelector('button');
    expect(button?.getAttribute('aria-label')).toBe(
      'Admin queue notifications: 2 open',
    );
    await act(async () => {
      button?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });

    expect(document.body.textContent).toContain('Church Schedule Reviews');
    expect(document.body.textContent).toContain('Safety Reports');
    expect(
      document.body.querySelector(
        'a[href="/dashboard?tab=admin&panel=churches&churchView=schedules"]',
      ),
    ).not.toBeNull();
    const channelApi = jest.mocked(supabaseClient.channel).mock.results[0]
      .value as ReturnType<typeof supabaseClient.channel>;
    expect(channelApi.on).toHaveBeenCalledWith(
      'postgres_changes',
      expect.objectContaining({ table: 'church_schedule_review_tasks' }),
      expect.any(Function),
    );
    expect(channelApi.on).toHaveBeenCalledWith(
      'postgres_changes',
      expect.objectContaining({ table: 'content_reports' }),
      expect.any(Function),
    );
  });
});
