import { act } from 'react';
import { type Root, createRoot } from 'react-dom/client';

import AddChurchPanel from '../src/components/admin/AddChurchPanel';

const reactTestGlobal = globalThis as typeof globalThis & {
  IS_REACT_ACT_ENVIRONMENT: boolean;
};

const postalLookup = {
  primaryCity: 'Austin',
  regionCodes: ['TX'],
  latitude: 30.270569,
  longitude: -97.742589,
  timezone: 'America/Chicago',
  dioceses: [{ id: 'diocese-austin', name: 'Diocese of Austin' }],
};
const similarChurch = {
  id: 'church-existing',
  name: 'St. Missing Parish',
  address: { line1: '1 Overlooked Way', city: 'Austin', regionName: 'TX' },
};

function jsonResponse(data: unknown, status = 200) {
  return { ok: status < 400, status, json: async () => ({ data }) };
}

describe('AddChurchPanel', () => {
  let container: HTMLDivElement;
  let root: Root;
  let originalFetch: typeof fetch;
  let fetchMock: jest.Mock;

  beforeEach(async () => {
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = true;
    originalFetch = global.fetch;
    fetchMock = jest.fn(async (url: string, init?: RequestInit) => {
      if (url.startsWith('/api/v1/locations/postal-codes/'))
        return jsonResponse(postalLookup);
      if (url.startsWith('/api/v1/churches?'))
        return jsonResponse([similarChurch]);
      if (url === '/api/v1/admin/churches' && init?.method === 'POST')
        return jsonResponse({ churchId: 'new-church' }, 201);
      throw new Error(`Unexpected request ${url}`);
    });
    global.fetch = fetchMock as unknown as typeof fetch;
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
    await act(async () => root.render(<AddChurchPanel token="admin-token" />));
  });

  afterEach(async () => {
    await act(async () => root.unmount());
    container.remove();
    global.fetch = originalFetch;
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = false;
  });

  const wait = (ms = 0) =>
    act(async () => {
      await new Promise((resolve) => setTimeout(resolve, ms));
    });

  function field(label: string) {
    const element = Array.from(container.querySelectorAll('label')).find(
      (candidate) => candidate.textContent?.replace(/\s*\*$/, '') === label,
    );
    return container.querySelector(`#${element?.htmlFor}`) as HTMLInputElement;
  }

  async function type(input: HTMLInputElement, value: string) {
    await act(async () => {
      Object.getOwnPropertyDescriptor(
        HTMLInputElement.prototype,
        'value',
      )?.set?.call(input, value);
      input.dispatchEvent(new Event('input', { bubbles: true }));
    });
  }

  async function click(element: Element | undefined) {
    await act(async () => {
      element?.dispatchEvent(new MouseEvent('click', { bubbles: true }));
    });
  }

  const button = (label: string) =>
    Array.from(container.querySelectorAll('button')).find(
      (candidate) => candidate.textContent === label,
    );

  it('fills location details from the ZIP and warns about similar churches', async () => {
    await type(field('ZIP code'), '78701');
    await wait();

    expect(field('City').value).toBe('Austin');
    expect(field('State/region').value).toBe('TX');
    expect(field('Time zone').value).toBe('America/Chicago');
    expect(field('Latitude').value).toBe('30.270569');
    expect(field('Longitude').value).toBe('-97.742589');
    expect(container.textContent).toContain('filled from the ZIP');

    await type(field('Name'), 'St. Missing Parish');
    await wait(500);
    expect(container.textContent).toContain(
      'Similar churches are already in the directory',
    );
    expect(container.textContent).toContain('1 Overlooked Way');
  });

  it('does not overwrite a field the admin already edited when the ZIP changes', async () => {
    await type(field('City'), 'Custom City');
    await type(field('ZIP code'), '78701');
    await wait();

    expect(field('City').value).toBe('Custom City');
    expect(field('State/region').value).toBe('TX');
  });

  it('requires a Mass time, then saves a Mass-only church and clears the form', async () => {
    await type(field('ZIP code'), '78701');
    await wait();
    await type(field('Name'), 'St. Missing Parish');
    await type(field('Address'), '1 Overlooked Way');

    await click(button('Add church'));
    expect(container.textContent).toContain('Add at least one Mass time.');
    expect(
      fetchMock.mock.calls.some(([, init]) => init?.method === 'POST'),
    ).toBe(false);

    const massSection = container.querySelector(
      'section[aria-label="Mass times"]',
    ) as HTMLElement;
    await type(massSection.querySelector('input') as HTMLInputElement, '9, 11');
    await click(
      Array.from(massSection.querySelectorAll('button')).find(
        (candidate) => candidate.textContent === 'Add',
      ),
    );
    await click(button('Add church'));
    await wait();

    const post = fetchMock.mock.calls.find(
      ([, init]) => init?.method === 'POST',
    );
    expect(JSON.parse(post?.[1].body)).toEqual({
      church: {
        name: 'St. Missing Parish',
        addressLine1: '1 Overlooked Way',
        addressLine2: null,
        city: 'Austin',
        regionName: 'TX',
        postalCode: '78701',
        countryCode: 'US',
        timezone: 'America/Chicago',
        latitude: 30.270569,
        longitude: -97.742589,
        dioceseId: null,
      },
      serviceTimes: [
        {
          serviceType: 'mass',
          weekday: 'sunday',
          startTime: '09:00',
          endTime: null,
        },
        {
          serviceType: 'mass',
          weekday: 'sunday',
          startTime: '11:00',
          endTime: null,
        },
      ],
    });
    expect(container.textContent).toContain('Added St. Missing Parish');
    expect(field('Name').value).toBe('');
  });

  it('shows the server message when the church already exists', async () => {
    fetchMock.mockImplementation(async (url: string, init?: RequestInit) => {
      if (init?.method === 'POST')
        return {
          ok: false,
          status: 409,
          json: async () => ({
            error: {
              message:
                'A church with the same name and address already exists.',
            },
          }),
        };
      if (url.startsWith('/api/v1/locations/postal-codes/'))
        return jsonResponse(postalLookup);
      return jsonResponse([]);
    });
    await type(field('ZIP code'), '78701');
    await wait();
    await type(field('Name'), 'St. Missing Parish');
    await type(field('Address'), '1 Overlooked Way');
    const massSection = container.querySelector(
      'section[aria-label="Mass times"]',
    ) as HTMLElement;
    await type(massSection.querySelector('input') as HTMLInputElement, '9');
    await click(
      Array.from(massSection.querySelectorAll('button')).find(
        (candidate) => candidate.textContent === 'Add',
      ),
    );
    await click(button('Add church'));
    await wait();

    expect(container.textContent).toContain(
      'A church with the same name and address already exists.',
    );
    expect(field('Name').value).toBe('St. Missing Parish');
  });
});
