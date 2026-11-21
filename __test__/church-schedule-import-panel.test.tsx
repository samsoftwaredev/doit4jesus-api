import { act } from 'react';
import { type Root, createRoot } from 'react-dom/client';

import ChurchScheduleImportPanel from '../src/components/admin/ChurchScheduleImportPanel';

const reactTestGlobal = globalThis as typeof globalThis & {
  IS_REACT_ACT_ENVIRONMENT: boolean;
};

function setTextarea(textarea: HTMLTextAreaElement, value: string) {
  const setter = Object.getOwnPropertyDescriptor(
    HTMLTextAreaElement.prototype,
    'value',
  )?.set;
  setter?.call(textarea, value);
  textarea.dispatchEvent(new Event('input', { bubbles: true }));
}

describe('ChurchScheduleImportPanel', () => {
  let container: HTMLDivElement;
  let root: Root;
  let originalFetch: typeof fetch;

  beforeEach(async () => {
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = true;
    originalFetch = global.fetch;
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
    await act(async () => root.render(<ChurchScheduleImportPanel token="t" />));
  });

  afterEach(async () => {
    await act(async () => root.unmount());
    container.remove();
    global.fetch = originalFetch;
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = false;
  });

  const button = (label: string) =>
    Array.from(container.querySelectorAll('button')).find((item) =>
      item.textContent?.includes(label),
    );

  it('shows the expected format with an example and download button', () => {
    expect(container.textContent).toContain('Expected format');
    expect(container.textContent).toContain('"serviceType": "mass"');
    expect(container.textContent).toContain('"churches"');
    expect(button('Download example')).toBeTruthy();
  });

  it('rejects invalid JSON without calling the API', async () => {
    global.fetch = jest.fn() as unknown as typeof fetch;
    const textarea = container.querySelector('textarea')!;
    await act(async () => setTextarea(textarea, '{ nope'));
    await act(async () => button('Preview changes')!.click());

    expect(container.textContent).toContain('This is not valid JSON');
    expect(global.fetch).not.toHaveBeenCalled();
  });

  it('previews first, then applies only after confirmation', async () => {
    const fetchMock = jest
      .fn()
      .mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({
          data: {
            dryRun: true,
            summary: { create: 0, update: 1, failed: 0 },
            results: [
              {
                index: 0,
                label: 'St. A',
                churchName: 'St. A',
                action: 'update',
                applied: false,
                currentServiceTimes: [],
                proposedServiceTimes: [
                  {
                    serviceType: 'mass',
                    weekday: 'sunday',
                    startTime: '09:00',
                  },
                ],
              },
            ],
          },
        }),
      })
      .mockResolvedValueOnce({
        ok: true,
        status: 200,
        json: async () => ({
          data: {
            dryRun: false,
            summary: { create: 0, update: 1, failed: 0 },
            results: [
              { index: 0, label: 'St. A', action: 'update', applied: true },
            ],
          },
        }),
      });
    global.fetch = fetchMock as unknown as typeof fetch;

    const textarea = container.querySelector('textarea')!;
    await act(async () =>
      setTextarea(
        textarea,
        JSON.stringify({
          churches: [
            {
              churchId: '11111111-1111-4111-8111-111111111111',
              serviceTimes: [
                { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' },
              ],
            },
          ],
        }),
      ),
    );
    await act(async () => button('Preview changes')!.click());

    expect(JSON.parse(fetchMock.mock.calls[0][1].body).dryRun).toBe(true);
    expect(container.textContent).toContain(
      'Preview: 0 to create, 1 to update',
    );
    expect(container.textContent).toContain('mass sun 09:00');

    await act(async () => button('Apply 1 change')!.click());

    expect(JSON.parse(fetchMock.mock.calls[1][1].body).dryRun).toBe(false);
    expect(container.textContent).toContain(
      'Applied: 0 to create, 1 to update',
    );
    expect(container.textContent).toContain('Changes were saved.');
  });

  it('lets the admin pick a church from the directory and fills its ID into the JSON', async () => {
    jest.useFakeTimers();
    const churchId = '22222222-2222-4222-8222-222222222222';
    const fetchMock = jest.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: async () => ({
        data: [
          {
            id: churchId,
            name: 'St. Picked Parish',
            address: {
              line1: '5 Pick St',
              city: 'Austin',
              regionName: 'TX',
              postalCode: '78701',
            },
          },
        ],
      }),
    });
    global.fetch = fetchMock as unknown as typeof fetch;

    const search = container.querySelector(
      '[aria-label="Search churches by name"]',
    ) as HTMLInputElement;
    const setter = Object.getOwnPropertyDescriptor(
      HTMLInputElement.prototype,
      'value',
    )?.set;
    await act(async () => {
      setter?.call(search, 'picked');
      search.dispatchEvent(new Event('input', { bubbles: true }));
    });
    await act(async () => {
      jest.advanceTimersByTime(400);
    });
    jest.useRealTimers();

    expect(fetchMock.mock.calls[0][0]).toContain('countryCode=US');
    expect(container.textContent).toContain(`ID: ${churchId}`);

    await act(async () =>
      (
        container.querySelector(
          '[aria-label="Add St. Picked Parish to JSON"]',
        ) as HTMLButtonElement
      ).click(),
    );

    const textarea = container.querySelector('textarea') as HTMLTextAreaElement;
    const parsed = JSON.parse(textarea.value);
    expect(parsed.churches).toHaveLength(1);
    expect(parsed.churches[0]).toMatchObject({
      churchId,
      label: 'St. Picked Parish, 5 Pick St, Austin TX',
    });
  });
});
