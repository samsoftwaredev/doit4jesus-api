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
      case 'FORBIDDEN':
        throw ApiError.forbidden();
      case 'CHURCH_NOT_FOUND':
        throw ApiError.notFound('The church was not found.');
      case 'CHURCH_NOT_LINKED':
        throw ApiError.notFound(
          'The church is not linked to the current user.',
        );
      case 'CHURCH_CHANGE_REQUEST_NOT_FOUND':
        throw ApiError.notFound('The church change request was not found.');
      case 'CHURCH_CHANGE_REQUEST_NOT_PENDING':
        throw ApiError.conflict(
          'The church change request has already been reviewed.',
        );
      case 'PRAYER_INTENTION_NOT_FOUND':
        throw ApiError.notFound('The prayer intention was not found.');
      case 'PRAYER_INTENTION_NOT_AVAILABLE':
        throw ApiError.notFound('The prayer intention is not available.');
      case 'PRAYER_INTENTION_NOT_PENDING':
        throw ApiError.conflict(
          'The prayer intention has already been reviewed.',
        );
      case 'FRIEND_USERNAME_NOT_FOUND':
      case 'FRIEND_REQUEST_NOT_FOUND':
      case 'FRIENDSHIP_NOT_FOUND':
      case 'FRIEND_LEADERBOARD_PERIOD_NOT_FOUND':
        throw ApiError.notFound();
      case 'FRIEND_REQUEST_ALREADY_PENDING':
      case 'FRIENDSHIP_ALREADY_EXISTS':
      case 'FRIEND_REQUEST_NOT_PENDING':
        throw ApiError.conflict(error.message);
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
      case 'USER_PROFILE_NOT_FOUND':
        throw ApiError.notFound('The current user profile was not found.');
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
      case 'INVALID_SELECTED_YEAR':
      case 'INVALID_SELECTED_MONTH':
      case 'USER_TIMEZONE_INVALID':
      case 'INVALID_CHURCH_CHANGE_DECISION':
      case 'INVALID_CHURCH_SERVICE_TIMES':
      case 'INVALID_PRAYER_INTENTION_DECISION':
      case 'INVALID_FRIEND_USERNAME':
      case 'INVALID_USER_SEARCH_QUERY':
      case 'CANNOT_FRIEND_SELF':
      case 'INVALID_FRIEND_REQUEST_DECISION':
      case 'INVALID_FRIEND_REQUEST_DIRECTION':
      case 'INVALID_FRIEND_REQUEST_STATUS':
      case 'INVALID_FRIEND_LEADERBOARD_PERIOD_TYPE':
      case 'INVALID_LOCATION_SEARCH_QUERY':
      case 'INVALID_USERNAME_CANDIDATES':
      case 'INVALID_PROFILE_SETUP':
      case 'PROFILE_COUNTRY_NOT_FOUND':
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
