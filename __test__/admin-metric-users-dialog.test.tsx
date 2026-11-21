import { act } from 'react';
import { type Root, createRoot } from 'react-dom/client';

import AdminMetricUsersDialog from '../src/components/admin/AdminMetricUsersDialog';

const reactTestGlobal = globalThis as typeof globalThis & {
  IS_REACT_ACT_ENVIRONMENT: boolean;
};

const user = {
  id: 'u1',
  email: 'pat@example.com',
  displayName: 'Pat Doe',
  username: 'pat',
  signedUpAt: '2026-11-01T10:00:00Z',
  lastActivityAt: '2026-11-18T10:00:00Z',
  firstActivityAt: '2026-11-02T10:00:00Z',
  activityCount: 4,
  rosariesStarted: 3,
  rosariesCompleted: 2,
  profileSetupComplete: true,
  positive: true,
};

describe('AdminMetricUsersDialog', () => {
  let container: HTMLDivElement;
  let root: Root;
  let originalFetch: typeof fetch;

  beforeEach(() => {
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = true;
    originalFetch = global.fetch;
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(async () => {
    await act(async () => root.unmount());
    container.remove();
    global.fetch = originalFetch;
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = false;
  });

  async function open(fetchImpl: jest.Mock) {
    global.fetch = fetchImpl as unknown as typeof fetch;
    await act(async () => {
      root.render(
        <AdminMetricUsersDialog
          accessToken="admin-token"
          metric={{
            metricKey: 'retention_d7',
            label: 'Retention D7',
            description: 'Retained after a week.',
          }}
          onClose={() => undefined}
        />,
      );
    });
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 0));
    });
  }

  it('requests the metric and shows email, name and the yes/no column', async () => {
    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({
        data: {
          total: 1,
          scopeTotal: 10,
          positiveTotal: 1,
          hasPositiveSplit: true,
          users: [user],
        },
      }),
    });
    await open(fetchMock);

    expect(fetchMock.mock.calls[0][0]).toBe(
      '/api/v1/admin/app-metrics/users?metric=retention_d7&filter=all&limit=50&offset=0',
    );
    const text = document.body.textContent ?? '';
    expect(text).toContain('Retention D7 — users');
    expect(text).toContain('pat@example.com');
    expect(text).toContain('Pat Doe');
    expect(text).toContain('@pat');
    expect(text).toContain('Returned day 7');
    expect(text).toContain('Not retained');
    expect(text).toContain('2/3');
  });

  it('shows an error state when the request fails', async () => {
    await open(
      jest.fn().mockResolvedValue({
        ok: false,
        status: 500,
        json: async () => ({ error: { message: 'nope' } }),
      }),
    );
    expect(document.body.textContent).toContain(
      'The users for this metric could not be loaded.',
    );
  });
});
