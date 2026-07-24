import type { PostgrestError } from '@supabase/supabase-js';

import { ApiError } from '@/lib/api/errors';

export function throwDatabaseError(
  error: PostgrestError | null,
  fallbackMessage: string,
): asserts error is null {
  if (!error) return;

  if (error.code === '23505') {
    throw ApiError.conflict(
      'A record with the same unique value already exists.',
    );
  }

  if (error.code === '23503' || error.code === '22023') {
    throw new ApiError(422, 'VALIDATION_ERROR', error.message);
  }

  if (error.code === '42501') {
    throw ApiError.forbidden();
  }

  if (error.code === 'PGRST116') {
    throw ApiError.notFound();
  }

  if (error.code === 'P0001') {
    switch (error.message) {
      case 'UNAUTHENTICATED':
        throw ApiError.unauthorized();
      case 'CHALLENGE_NOT_FOUND':
        throw ApiError.notFound('The challenge assignment was not found.');
      case 'DEMON_NOT_FOUND':
        throw ApiError.notFound('The demon was not found.');
      case 'ENCOUNTER_NOT_FOUND':
        throw ApiError.notFound('The encounter was not found.');
      case 'DEFENSE_ASSIGNMENT_NOT_FOUND':
        throw ApiError.notFound('The defense assignment was not found.');
      case 'ACTIVITY_NOT_FOUND':
      case 'ACTIVITY_DEFINITION_NOT_FOUND':
        throw ApiError.notFound('The activity definition was not found.');
      case 'CHALLENGE_NOT_COMPLETED':
        throw ApiError.conflict(
          'The challenge must be completed before its reward can be claimed.',
        );
      case 'CHALLENGE_REWARD_ALREADY_CLAIMED':
        throw ApiError.conflict(
          'The challenge reward has already been claimed.',
        );
      case 'ENCOUNTER_ALREADY_ACTIVE':
        throw ApiError.conflict('This demon already has an active encounter.');
      case 'ENCOUNTER_NOT_ACTIVE':
        throw ApiError.conflict('The encounter is no longer active.');
      case 'DEFENSE_ASSIGNMENT_NOT_ACTIVE':
        throw ApiError.conflict('The defense assignment is no longer active.');
      case 'IDEMPOTENCY_IN_PROGRESS':
        throw ApiError.conflict(
          'A matching request is already being processed.',
        );
      case 'USER_PROGRESS_NOT_FOUND':
        throw ApiError.conflict('User progression has not been initialized.');
      case 'LEVEL_DEFINITIONS_REQUIRED':
      case 'DEMON_DEFENSES_REQUIRED':
      case 'DEMON_DEFEAT_REWARD_REQUIRED':
        throw new ApiError(
          500,
          'CONFIGURATION_ERROR',
          'Active level definitions are required.',
        );
      case 'INVALID_IDEMPOTENCY_KEY':
      case 'INVALID_ACTIVITY_QUANTITY':
      case 'DEFENSE_DOES_NOT_MATCH_ENCOUNTER':
        throw new ApiError(422, 'VALIDATION_ERROR', error.message);
      default:
        break;
    }
  }

  console.error('Database error', {
    code: error.code,
    message: error.message,
    details: error.details,
    hint: error.hint,
  });

  throw new ApiError(500, 'DATABASE_ERROR', fallbackMessage);
}
