import prohibitedTerms from '@/data/username-prohibited-terms.json';
import { ApiError } from '@/lib/api/errors';
import { USERNAME_PATTERN } from '@/lib/schemas/username';

export type UsernameValidationReason =
  | 'INVALID_LENGTH'
  | 'INVALID_CHARACTERS'
  | 'PROHIBITED_TERM';

export type UsernameModerationResult =
  | { valid: true; reason: null }
  | { valid: false; reason: UsernameValidationReason };

const exactTerms = new Set(prohibitedTerms.exactTerms);
const substringTerms = prohibitedTerms.substringTerms;
const leetCharacters: Readonly<Record<string, string>> = {
  '0': 'o',
  '1': 'i',
  '3': 'e',
  '4': 'a',
  '5': 's',
  '6': 'g',
  '7': 't',
  '8': 'b',
  '9': 'g',
};

export function normalizeUsernameForModeration(value: string) {
  return value
    .normalize('NFKD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .split('')
    .map((character) => leetCharacters[character] ?? character)
    .join('')
    .replace(/[^a-z0-9]/g, '');
}

function containsProhibitedTerm(username: string) {
  const compact = normalizeUsernameForModeration(username);
  const compactWithoutNumericAffixes = normalizeUsernameForModeration(
    username.replace(/^\d+|\d+$/g, ''),
  );
  if (exactTerms.has(compact) || exactTerms.has(compactWithoutNumericAffixes)) {
    return true;
  }

  const tokens = username
    .split('_')
    .flatMap((token) => [
      normalizeUsernameForModeration(token),
      normalizeUsernameForModeration(token.replace(/^\d+|\d+$/g, '')),
    ]);

  if (tokens.some((token) => token && exactTerms.has(token))) return true;

  return substringTerms.some((term) => compact.includes(term));
}

export function evaluateUsername(value: string): UsernameModerationResult {
  const username = value.trim();

  if (username.length < 3 || username.length > 30) {
    return { valid: false, reason: 'INVALID_LENGTH' };
  }

  if (!USERNAME_PATTERN.test(username)) {
    return { valid: false, reason: 'INVALID_CHARACTERS' };
  }

  if (containsProhibitedTerm(username)) {
    return { valid: false, reason: 'PROHIBITED_TERM' };
  }

  return { valid: true, reason: null };
}

export function assertUsernameAllowed(value: string) {
  const result = evaluateUsername(value);
  if (!result.valid) {
    throw new ApiError(422, 'VALIDATION_ERROR', 'Username is not allowed.', {
      reason: result.reason,
    });
  }
}
