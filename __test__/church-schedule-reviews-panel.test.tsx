import { act } from 'react';
import { type Root, createRoot } from 'react-dom/client';

import ChurchScheduleReviewsPanel from '../src/components/admin/ChurchScheduleReviewsPanel';

const review = {
  id: 'cc000000-0000-4000-8000-000000000001',
  status: 'pending',
  outcome: null,
  reviewReason: 'missing_schedule',
  church: {
    id: 'c6000000-0000-4000-8000-000000000005',
    name: 'St. Test Parish',
    address: {
      line1: '100 Church Street',
      line2: null,
      city: 'Austin',
      regionName: 'Texas',
      postalCode: '78701',
      countryCode: 'US',
    },
    timezone: 'America/Chicago',
    latitude: 30.2,
    longitude: -97.7,
    scheduleVerifiedAt: null,
  },
  subscriberCount: 2,
  schedule: [
    {
      id: 'cd000000-0000-4000-8000-000000000001',
      serviceType: 'mass',
      weekday: 'sunday',
      startTime: '09:00',
      endTime: null,
    },
  ],
  createdAt: '2026-11-07T12:00:00.000Z',
  completedAt: null,
};

const reactTestGlobal = globalThis as typeof globalThis & {
  IS_REACT_ACT_ENVIRONMENT: boolean;
};

describe('ChurchScheduleReviewsPanel', () => {
  let container: HTMLDivElement;
  let root: Root;
  let originalFetch: typeof fetch;

  beforeEach(() => {
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = true;
    originalFetch = global.fetch;
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ data: [review], meta: { hasMore: false } }),
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

  it('opens missing schedules with all three required service rows and blocks incomplete verification', async () => {
    await act(async () =>
      root.render(
        <ChurchScheduleReviewsPanel token="admin-token" onClose={jest.fn()} />,
      ),
    );
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 0));
    });

    expect(container.textContent).toContain('St. Test Parish');
    expect(container.textContent).toContain('Missing schedule');
    const reviewButton = Array.from(container.querySelectorAll('button')).find(
      (button) => button.textContent === 'Review schedule',
    );
    await act(async () => {
      reviewButton?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });

    expect(document.body.textContent).toContain(
      'Mass, confession, and adoration times',
    );
    expect(document.body.querySelectorAll('input[type="time"]')).toHaveLength(
      6,
    );
    const verifyButton = Array.from(
      document.body.querySelectorAll('button'),
    ).find((button) => button.textContent === 'Verify schedule');
    await act(async () => {
      verifyButton?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });

    expect(document.body.textContent).toContain(
      'Enter a valid time for Mass, confession, and adoration.',
    );
    expect(global.fetch).toHaveBeenCalledTimes(1);
  });

  async function renderPanel() {
    await act(async () =>
      root.render(
        <ChurchScheduleReviewsPanel token="admin-token" onClose={jest.fn()} />,
      ),
    );
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 0));
    });
  }

  function findButton(scope: ParentNode, label: string) {
    return Array.from(scope.querySelectorAll('button')).find(
      (button) => button.textContent === label,
    );
  }

  async function click(button: HTMLButtonElement | undefined) {
    await act(async () => {
      button?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });
  }

  it('shows completed reviews as read-only without review actions', async () => {
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      json: async () => ({
        data: [
          {
            ...review,
            status: 'completed',
            outcome: 'verified',
            completedAt: '2026-11-07T18:25:19.000Z',
          },
        ],
        meta: { hasMore: false },
      }),
    }) as typeof fetch;
    await renderPanel();

    expect(container.textContent).toContain('Completed · verified');
    expect(findButton(container, 'Review schedule')).toBeUndefined();
    await click(findButton(container, 'View review'));

    expect(document.body.textContent).toContain('is read-only');
    expect(findButton(document.body, 'Verify schedule')).toBeUndefined();
    expect(findButton(document.body, 'Mark church closed')).toBeUndefined();
    expect(findButton(document.body, 'Close')).toBeDefined();
    const dialog = document.body.querySelector('[role="dialog"]');
    const inputs = Array.from(dialog?.querySelectorAll('input') ?? []);
    expect(inputs.length).toBeGreaterThan(0);
    expect(inputs.every((input) => input.disabled)).toBe(true);
  });

  it('switches to read-only and refreshes the list when the review was already completed', async () => {
    const fetchMock = jest
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          data: [
            {
              ...review,
              schedule: [
                ...review.schedule,
                {
                  serviceType: 'confession',
                  weekday: 'saturday',
                  startTime: '16:00',
                  endTime: '16:45',
                },
                {
                  serviceType: 'adoration',
                  weekday: 'friday',
                  startTime: '18:00',
                  endTime: null,
                },
              ],
            },
          ],
          meta: { hasMore: false },
        }),
      })
      .mockResolvedValueOnce({
        ok: false,
        status: 409,
        json: async () => ({
          error: {
            message: 'The church schedule review has already been completed.',
          },
        }),
      })
      .mockResolvedValue({
        ok: true,
        json: async () => ({ data: [], meta: { hasMore: false } }),
      });
    global.fetch = fetchMock as typeof fetch;
    await renderPanel();

    await click(findButton(container, 'Review schedule'));
    await click(findButton(document.body, 'Verify schedule'));

    expect(document.body.textContent).toContain(
      'This review has already been completed',
    );
    expect(findButton(document.body, 'Verify schedule')).toBeUndefined();
    expect(fetchMock).toHaveBeenCalledTimes(3);
    expect(fetchMock.mock.calls[2][0]).toContain(
      '/api/v1/admin/church-schedule-reviews?status=pending',
    );
  });
  it('reloads the list as soon as a different status is picked', async () => {
    await renderPanel();
    expect(global.fetch).toHaveBeenCalledTimes(1);
    expect(findButton(container, 'Apply')).toBeUndefined();

    const statusSelect = container.querySelector('[role="combobox"]');
    await act(async () => {
      statusSelect?.dispatchEvent(
        new MouseEvent('mousedown', { bubbles: true, button: 0 }),
      );
    });
    const completedOption = Array.from(
      document.body.querySelectorAll('[role="option"]'),
    ).find((option) => option.textContent === 'completed');
    await click(completedOption as HTMLButtonElement | undefined);
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 0));
    });

    expect(global.fetch).toHaveBeenCalledTimes(2);
    expect((global.fetch as jest.Mock).mock.calls[1][0]).toContain(
      '/api/v1/admin/church-schedule-reviews?status=completed&limit=20&offset=0',
    );
  });
});
