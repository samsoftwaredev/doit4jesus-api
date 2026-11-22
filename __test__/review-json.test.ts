import {
  describeScheduleChanges,
  parseReviewJson,
  toReviewJson,
  toReviewJsonText,
} from '../src/lib/churches/review-json';
import { importChurchEntrySchema } from '../src/lib/schemas/church-subscription';

const id = 'c6000000-0000-4000-8000-000000000005';
const church = {
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
};
const mass = {
  serviceType: 'mass' as const,
  weekday: 'sunday' as const,
  startTime: '09:00',
  endTime: null,
};

describe('review JSON', () => {
  it('produces an entry the Import JSON tab accepts', () => {
    expect(
      importChurchEntrySchema.safeParse(toReviewJson(id, church, [mass]))
        .success,
    ).toBe(true);
    expect(
      importChurchEntrySchema.safeParse(
        toReviewJson(id, { ...church, latitude: null, longitude: null }, [
          mass,
        ]),
      ).success,
    ).toBe(true);
  });

  it('round-trips and applies edits', () => {
    const text = toReviewJsonText(id, church, [mass]);
    const edited = JSON.parse(text);
    edited.church.city = 'Dallas';
    edited.serviceTimes.push({
      serviceType: 'confession',
      weekday: 'saturday',
      startTime: '15:00',
    });
    const result = parseReviewJson(JSON.stringify(edited), id, church);
    expect(result).toMatchObject({ ok: true });
    if (!result.ok) return;
    expect(result.church.address.city).toBe('Dallas');
    expect(result.serviceTimes).toHaveLength(2);
    expect(describeScheduleChanges([mass], result.serviceTimes)).toEqual([
      '+ confession saturday 15:00',
    ]);
  });

  it('keeps current values for omitted church fields', () => {
    const result = parseReviewJson(
      JSON.stringify({ serviceTimes: [mass], churchId: id }),
      id,
      church,
    );
    expect(result).toMatchObject({ ok: true, church });
  });

  it('rejects bad JSON, other churches, missing Mass and bad times', () => {
    const other = parseReviewJson(
      JSON.stringify({
        churchId: 'd6000000-0000-4000-8000-000000000009',
        serviceTimes: [mass],
      }),
      id,
      church,
    );
    expect(other).toMatchObject({ ok: false });
    expect(parseReviewJson('{nope', id, church)).toMatchObject({ ok: false });
    expect(
      parseReviewJson(
        JSON.stringify({
          churchId: id,
          serviceTimes: [{ ...mass, serviceType: 'confession' }],
        }),
        id,
        church,
      ),
    ).toMatchObject({ ok: false });
    expect(
      parseReviewJson(
        JSON.stringify({
          churchId: id,
          serviceTimes: [{ ...mass, startTime: '9am' }],
        }),
        id,
        church,
      ),
    ).toMatchObject({ ok: false });
  });
});
