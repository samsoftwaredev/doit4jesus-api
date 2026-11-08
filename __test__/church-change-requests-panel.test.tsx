import { act } from 'react';
import { type Root, createRoot } from 'react-dom/client';

import { ChurchRequestsPanel } from '../src/components/admin/AdminManagementCards';

// Sibling panels pull in ESM-only dependencies and aren't under test here.
jest.mock('../src/components/admin/AdminAppMetrics', () => () => null);
jest.mock('../src/components/admin/AdminEventsPanel', () => () => null);
jest.mock('../src/components/admin/ChurchesAdminPanel', () => () => null);
jest.mock('../src/components/admin/EmailCenter', () => () => null);
jest.mock('next/navigation', () => ({
  useRouter: () => ({ replace: jest.fn() }),
  useSearchParams: () => new URLSearchParams(),
}));

const reactTestGlobal = globalThis as typeof globalThis & {
  IS_REACT_ACT_ENVIRONMENT: boolean;
};

describe('ChurchRequestsPanel', () => {
  let container: HTMLDivElement;
  let root: Root;
  let originalFetch: typeof fetch;

  beforeEach(() => {
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = true;
    originalFetch = global.fetch;
    global.fetch = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({ data: [], meta: { hasMore: false } }),
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

  it('reloads the list as soon as a different status is picked', async () => {
    await act(async () =>
      root.render(
        <ChurchRequestsPanel token="admin-token" onClose={jest.fn()} />,
      ),
    );
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 0));
    });

    const fetchMock = global.fetch as jest.Mock;
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect(fetchMock.mock.calls[0][0]).toContain(
      '/api/v1/admin/church-change-requests?status=all&limit=20&offset=0',
    );
    expect(
      Array.from(container.querySelectorAll('button')).some(
        (button) => button.textContent === 'Apply',
      ),
    ).toBe(false);

    const statusSelect = container.querySelector('[role="combobox"]');
    await act(async () => {
      statusSelect?.dispatchEvent(
        new MouseEvent('mousedown', { bubbles: true, button: 0 }),
      );
    });
    const pendingOption = Array.from(
      document.body.querySelectorAll('[role="option"]'),
    ).find((option) => option.textContent === 'pending');
    await act(async () => {
      pendingOption?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });
    await act(async () => {
      await new Promise((resolve) => setTimeout(resolve, 0));
    });

    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(fetchMock.mock.calls[1][0]).toContain(
      '/api/v1/admin/church-change-requests?status=pending&limit=20&offset=0',
    );
  });
});
