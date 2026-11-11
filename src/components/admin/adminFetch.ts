export type AdminApiResponse<T> = {
  data?: T;
  meta?: { hasMore?: boolean };
  error?: { message?: string };
};

/** An admin API failure that keeps the HTTP status so callers can react to it (e.g. 409). */
export class AdminFetchError extends Error {
  constructor(
    readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = 'AdminFetchError';
  }
}

/** Calls an authenticated admin API route and throws an AdminFetchError for non-2xx responses. */
export async function adminFetch<T>(
  token: string,
  url: string,
  init: RequestInit = {},
) {
  const response = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      ...(init.body ? { 'Content-Type': 'application/json' } : {}),
      ...init.headers,
    },
  });
  const body = (await response.json()) as AdminApiResponse<T>;
  if (!response.ok)
    throw new AdminFetchError(
      response.status,
      body.error?.message ?? 'The request could not be completed.',
    );
  return body;
}
