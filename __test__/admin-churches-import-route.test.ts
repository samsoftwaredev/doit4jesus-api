import { readFileSync } from 'node:fs';
import { join } from 'node:path';

import { POST } from '../src/app/api/v1/admin/churches/import/route';
import { errorResponse } from '../src/lib/api/response';
import { readJson } from '../src/lib/api/validation';
import { requireAdmin } from '../src/lib/auth/require-admin';
import { churchImportExample } from '../src/lib/churches/import-example';
import { importChurchEntrySchema } from '../src/lib/schemas/church-subscription';

jest.mock('../src/lib/auth/require-admin', () => ({ requireAdmin: jest.fn() }));
jest.mock('../src/lib/api/validation', () => ({ readJson: jest.fn() }));
jest.mock('../src/lib/api/response', () => ({
  errorResponse: jest.fn(),
  ok: (data: unknown) => ({ json: async () => ({ data }) }),
}));

const mockedRequireAdmin = jest.mocked(requireAdmin);
const mockedReadJson = jest.mocked(readJson);
const mockedErrorResponse = jest.mocked(errorResponse);
const request = {
  url: 'http://localhost/api/v1/admin/churches/import',
} as Request;
const mass = { serviceType: 'mass', weekday: 'sunday', startTime: '09:00' };
const id = '11111111-1111-4111-8111-111111111111';

function mockRpc(...results: { data: unknown; error: unknown }[]) {
  const rpc = jest.fn();
  for (const result of results) rpc.mockResolvedValueOnce(result);
  mockedRequireAdmin.mockResolvedValue({
    supabase: { schema: jest.fn(() => ({ rpc })) },
  } as never);
  return rpc;
}

describe('church import example', () => {
  it('stays valid against the real import schema', () => {
    for (const entry of churchImportExample.churches) {
      expect(importChurchEntrySchema.safeParse(entry).success).toBe(true);
    }
  });

  it('matches the downloadable docs file', () => {
    const file = JSON.parse(
      readFileSync(
        join(__dirname, '../docs/church-schedule-import.example.json'),
        'utf8',
      ),
    );
    expect(file).toEqual(JSON.parse(JSON.stringify(churchImportExample)));
  });
});

describe('POST /api/v1/admin/churches/import', () => {
  beforeEach(() => jest.clearAllMocks());

  it('previews by default and never applies', async () => {
    const rpc = mockRpc({
      data: {
        action: 'update',
        churchId: id,
        churchName: 'St. A',
        currentServiceTimes: [],
      },
      error: null,
    });
    mockedReadJson.mockResolvedValue({
      churches: [{ churchId: id, serviceTimes: [mass] }],
    });

    const body = await (await POST(request)).json();

    expect(rpc).toHaveBeenCalledWith('admin_import_church_schedule', {
      p_church_id: id,
      p_church: expect.any(Object),
      p_service_times: [
        { service_type: 'mass', weekday: 0, starts_at: '09:00', ends_at: null },
      ],
      p_dry_run: true,
    });
    expect(body.data.summary).toEqual({ create: 0, update: 1, failed: 0 });
    expect(body.data.results[0]).toMatchObject({
      action: 'update',
      applied: false,
    });
  });

  it('applies each valid church and reports bad entries without blocking the rest', async () => {
    const rpc = mockRpc(
      { data: { action: 'create', churchId: 'new' }, error: null },
      { data: { action: 'ambiguous', matches: 2 }, error: null },
      {
        data: null,
        error: { code: 'P0001', message: 'INCOMPLETE_CHURCH_SERVICE_TIMES' },
      },
    );
    const named = {
      church: { name: 'St. B', addressLine1: '1 Way' },
      serviceTimes: [mass],
    };
    mockedReadJson.mockResolvedValue({
      dryRun: false,
      churches: [
        named,
        named,
        named,
        {
          churchId: id,
          serviceTimes: [{ ...mass, serviceType: 'confession' }],
        },
        { serviceTimes: [mass] },
      ],
    });

    const body = await (await POST(request)).json();
    const actions = body.data.results.map(
      (result: { action: string; applied: boolean }) => [
        result.action,
        result.applied,
      ],
    );

    expect(rpc).toHaveBeenCalledTimes(3);
    expect(rpc.mock.calls[0][1].p_dry_run).toBe(false);
    expect(actions).toEqual([
      ['create', true],
      ['ambiguous', false],
      ['error', false],
      ['invalid', false],
      ['invalid', false],
    ]);
    expect(body.data.summary).toEqual({ create: 1, update: 0, failed: 4 });
  });

  it('rejects an empty or oversized envelope before authorization work', async () => {
    mockedReadJson.mockResolvedValue({ churches: [] });
    await POST(request);
    expect(mockedRequireAdmin).not.toHaveBeenCalled();
    expect(mockedErrorResponse).toHaveBeenCalledTimes(1);
  });
});
