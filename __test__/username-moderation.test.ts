import {
  assertUsernameAllowed,
  evaluateUsername,
  normalizeUsernameForModeration,
} from '../src/lib/usernames/moderation';
import { generateUsernameCandidates } from '../src/lib/usernames/suggestions';

describe('username moderation', () => {
  it.each([
    ['fuck', 'PROHIBITED_TERM'],
    ['faithful_fuck_guy', 'PROHIBITED_TERM'],
    ['n1gga', 'PROHIBITED_TERM'],
    ['pussycat', 'PROHIBITED_TERM'],
    ['puta_123', 'PROHIBITED_TERM'],
    ['pendejo77', 'PROHIBITED_TERM'],
    ['mierda', 'PROHIBITED_TERM'],
    ['ab', 'INVALID_LENGTH'],
    ['saint-peter', 'INVALID_CHARACTERS'],
  ])('rejects %s with %s', (username, reason) => {
    expect(evaluateUsername(username)).toEqual({ valid: false, reason });
  });

  it.each(['cassidy', 'scunthorpe', 'grapefruit', 'classical_clare'])(
    'does not reject the benign username %s',
    (username) => {
      expect(evaluateUsername(username)).toEqual({ valid: true, reason: null });
    },
  );

  it('normalizes accents, case, separators, and common leetspeak', () => {
    expect(normalizeUsernameForModeration('NÍ_GG4')).toBe('nigga');
  });

  it('throws a validation error without exposing the matched term', () => {
    expect(() => assertUsernameAllowed('faithful_fuck')).toThrow(
      expect.objectContaining({
        status: 422,
        code: 'VALIDATION_ERROR',
        message: 'Username is not allowed.',
        details: { reason: 'PROHIBITED_TERM' },
      }),
    );
  });
});

describe('Christian username suggestions', () => {
  it('creates unique, valid, time-seeded word-soup candidates', () => {
    const options = { count: 60, now: 1_787_934_245_000, entropy: 12345 };
    const first = generateUsernameCandidates(options);
    const second = generateUsernameCandidates(options);

    expect(first).toEqual(second);
    expect(first).toHaveLength(60);
    expect(new Set(first).size).toBe(60);
    expect(
      first.every(
        (candidate) =>
          candidate.length >= 3 &&
          candidate.length <= 30 &&
          evaluateUsername(candidate).valid,
      ),
    ).toBe(true);
    expect(
      first.some((candidate) => /peter|paul|joseph|therese/.test(candidate)),
    ).toBe(true);
  });
});
