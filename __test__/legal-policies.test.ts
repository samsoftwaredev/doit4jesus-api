import { toLegalAcceptanceStatus } from '../src/lib/legal/policies';

describe('legal acceptance policy', () => {
  it('grandfathers an account created one millisecond before the cutoff', () => {
    expect(
      toLegalAcceptanceStatus('2026-10-27T04:59:59.999Z', null),
    ).toMatchObject({ required: false, accepted: false, grandfathered: true });
  });

  it('requires an account created exactly at the cutoff', () => {
    expect(
      toLegalAcceptanceStatus('2026-10-27T05:00:00.000Z', null),
    ).toMatchObject({ required: true, accepted: false, grandfathered: false });
  });

  it('does not require a current-version acceptance twice', () => {
    expect(
      toLegalAcceptanceStatus(
        '2026-10-27T05:00:00.000Z',
        '2026-10-27T05:01:00.000Z',
      ),
    ).toMatchObject({ required: false, accepted: true, grandfathered: false });
  });
});
