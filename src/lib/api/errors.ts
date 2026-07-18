export class ApiError extends Error {
  constructor(
    public readonly status: number,
    public readonly code: string,
    message: string,
    public readonly details?: unknown,
  ) {
    super(message)
    this.name = 'ApiError'
  }

  static badRequest(message: string, details?: unknown) {
    return new ApiError(400, 'BAD_REQUEST', message, details)
  }

  static unauthorized(message = 'Authentication is required.') {
    return new ApiError(401, 'UNAUTHORIZED', message)
  }

  static forbidden(message = 'You are not allowed to perform this action.') {
    return new ApiError(403, 'FORBIDDEN', message)
  }

  static notFound(message = 'The requested resource was not found.') {
    return new ApiError(404, 'NOT_FOUND', message)
  }

  static conflict(message: string, details?: unknown) {
    return new ApiError(409, 'CONFLICT', message, details)
  }
}
