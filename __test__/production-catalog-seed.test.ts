import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';

const repositoryFile = (path: string) =>
  readFileSync(resolve(process.cwd(), path), 'utf8');

const fixtureEmails = [
  'test@test.com',
  'test@admin.com',
  'maria@example.com',
  'john@example.com',
];
const fixtureIds = [
  '9629e3e7-72dc-4bb1-94d3-b5a2bdd9f002',
  '33333333-3333-4333-8333-333333333333',
  '11111111-1111-4111-8111-111111111111',
  '22222222-2222-4222-8222-222222222222',
];

describe('production-safe catalog and local fixture separation', () => {
  it('keeps credentials and fixture identities out of the default seed path', () => {
    const config = repositoryFile('supabase/config.toml');
    const defaultSeed = repositoryFile('supabase/seed.sql');

    expect(config).not.toContain('local-fixtures.sql');
    expect(config).not.toContain('verify-local-fixtures.sql');
    expect(defaultSeed).not.toMatch(/insert\s+into\s+auth\.users/i);
    expect(defaultSeed).not.toMatch(
      /encrypted_password|password_hash|crypt\s*\(/i,
    );
    for (const value of [...fixtureEmails, ...fixtureIds]) {
      expect(defaultSeed).not.toContain(value);
    }
  });

  it('keeps all known-password accounts only in the explicit local fixture', () => {
    const localFixture = repositoryFile('supabase/seed/local-fixtures.sql');

    expect(localFixture).toMatch(/insert\s+into\s+auth\.users/i);
    expect(localFixture).toContain("crypt('12345678'");
    for (const value of [...fixtureEmails, ...fixtureIds]) {
      expect(localFixture).toContain(value);
    }
  });

  it('guards the forward catalog migration without seeding operational data', () => {
    const migration = repositoryFile(
      'supabase/migrations/20261018130000_seed_production_catalog.sql',
    );

    expect(migration).toContain('PRODUCTION_DEV_ACCOUNT_PRESENT');
    expect(migration).toMatch(/insert\s+into\s+app\.countries/i);
    expect(migration).toMatch(
      /insert\s+into\s+competition\.activity_definitions/i,
    );
    expect(migration).toMatch(
      /insert\s+into\s+app\.examination_of_conscience_questions/i,
    );
    expect(migration).not.toMatch(/insert\s+into\s+auth\.users/i);
    expect(migration).not.toMatch(
      /insert\s+into\s+(app\.(users|user_profiles|churches|contact_requests)|competition\.(spiritual_activities|point_ledger|user_progress)|prayer\.prayer_intentions)/i,
    );
  });

  it('keeps the production account audit read-only', () => {
    const audit = repositoryFile('scripts/audit-development-accounts.sql');

    expect(audit).toMatch(/begin\s+transaction\s+read\s+only/i);
    expect(audit).toContain('PRODUCTION_DEV_ACCOUNT_PRESENT');
    expect(audit).not.toMatch(/\b(delete|insert|update|truncate)\b/i);
  });
});
