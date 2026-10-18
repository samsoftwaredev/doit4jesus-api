import { act } from 'react';
import { type Root, createRoot } from 'react-dom/client';

import LoginPage from '../src/app/auth/login/page';
import { supabaseClient } from '../src/app/classes/supabaseClient';

const routerPush = jest.fn();
const routerRefresh = jest.fn();

jest.mock('next/navigation', () => ({
  useRouter: () => ({ push: routerPush, refresh: routerRefresh }),
}));

jest.mock('../src/app/classes/supabaseClient', () => ({
  supabaseClient: {
    auth: {
      signInWithOAuth: jest.fn(),
      signInWithPassword: jest.fn(),
    },
  },
}));

const signInWithOAuth = jest.mocked(supabaseClient.auth.signInWithOAuth);
const reactTestGlobal = globalThis as typeof globalThis & {
  IS_REACT_ACT_ENVIRONMENT: boolean;
};

describe('LoginPage', () => {
  let container: HTMLDivElement;
  let root: Root;

  beforeEach(() => {
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = true;
    jest.clearAllMocks();
    signInWithOAuth.mockResolvedValue({
      data: { provider: 'google' },
      error: null,
    });
    container = document.createElement('div');
    document.body.appendChild(container);
    root = createRoot(container);
  });

  afterEach(async () => {
    await act(async () => root.unmount());
    container.remove();
    reactTestGlobal.IS_REACT_ACT_ENVIRONMENT = false;
  });

  it('starts Google OAuth with the application callback URL', async () => {
    await act(async () => root.render(<LoginPage />));
    const googleButton = Array.from(container.querySelectorAll('button')).find(
      (button) => button.textContent?.includes('Continue with Google'),
    );

    expect(googleButton).toBeDefined();
    await act(async () => googleButton?.click());

    expect(signInWithOAuth).toHaveBeenCalledWith({
      provider: 'google',
      options: {
        redirectTo: 'http://localhost/auth/callback?next=/dashboard',
      },
    });
  });

  it('shows a Google OAuth error without navigating', async () => {
    signInWithOAuth.mockResolvedValue({
      data: { provider: 'google' },
      error: new Error('Google sign-in failed'),
    } as never);
    await act(async () => root.render(<LoginPage />));
    const googleButton = Array.from(container.querySelectorAll('button')).find(
      (button) => button.textContent?.includes('Continue with Google'),
    );

    await act(async () => googleButton?.click());

    expect(container.textContent).toContain('Google sign-in failed');
    expect(routerPush).not.toHaveBeenCalled();
    expect(routerRefresh).not.toHaveBeenCalled();
  });
});
