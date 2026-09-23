'use client';

import LogoutIcon from '@mui/icons-material/Logout';
import PersonIcon from '@mui/icons-material/Person';
import AppBar from '@mui/material/AppBar';
import Avatar from '@mui/material/Avatar';
import Box from '@mui/material/Box';
import Button from '@mui/material/Button';
import Container from '@mui/material/Container';
import Divider from '@mui/material/Divider';
import IconButton from '@mui/material/IconButton';
import ListItemIcon from '@mui/material/ListItemIcon';
import Menu from '@mui/material/Menu';
import MenuItem from '@mui/material/MenuItem';
import Skeleton from '@mui/material/Skeleton';
import Stack from '@mui/material/Stack';
import Toolbar from '@mui/material/Toolbar';
import Typography from '@mui/material/Typography';
import NextLink from 'next/link';
import { useRouter } from 'next/navigation';
import { useState } from 'react';

import { supabaseClient } from '@/app/classes/supabaseClient';
import { useUser } from '@/context/UserContext';

export default function TopNav() {
  const router = useRouter();
  const { user, profile, isLoading } = useUser();
  const [anchorEl, setAnchorEl] = useState<HTMLElement | null>(null);

  const displayName = (profile as { displayName?: string } | null)?.displayName;
  const avatarUrl = (profile as { avatarUrl?: string } | null)?.avatarUrl;
  const username = (profile as { username?: string } | null)?.username;

  const initials = displayName
    ? displayName
        .split(' ')
        .map((n: string) => n[0])
        .join('')
        .toUpperCase()
        .slice(0, 2)
    : (user?.email?.[0] ?? '?').toUpperCase();

  async function handleSignOut() {
    setAnchorEl(null);
    await supabaseClient.auth.signOut();
    router.push('/auth/login');
    router.refresh();
  }

  return (
    <AppBar
      position="sticky"
      color="inherit"
      elevation={0}
      sx={{ borderBottom: '1px solid', borderColor: 'divider' }}
    >
      <Container maxWidth="lg">
        <Toolbar disableGutters sx={{ minHeight: { xs: 56, sm: 64 } }}>
          {/* Brand */}
          <Typography
            component={NextLink}
            href={user ? '/dashboard' : '/'}
            variant="h6"
            fontWeight={700}
            sx={{ textDecoration: 'none', color: 'inherit', flexGrow: 1 }}
          >
            DoIt4Jesus
          </Typography>

          {/* Right side */}
          {isLoading ? (
            <Stack direction="row" spacing={1} alignItems="center">
              <Skeleton variant="rounded" width={72} height={32} />
              <Skeleton variant="circular" width={36} height={36} />
            </Stack>
          ) : user ? (
            <>
              {/* Authenticated */}
              <IconButton
                onClick={(e) => setAnchorEl(e.currentTarget)}
                size="small"
              >
                <Avatar
                  src={avatarUrl ?? undefined}
                  sx={{
                    width: 36,
                    height: 36,
                    bgcolor: 'primary.main',
                    fontSize: 14,
                  }}
                >
                  {initials}
                </Avatar>
              </IconButton>

              <Menu
                anchorEl={anchorEl}
                open={Boolean(anchorEl)}
                onClose={() => setAnchorEl(null)}
                transformOrigin={{ horizontal: 'right', vertical: 'top' }}
                anchorOrigin={{ horizontal: 'right', vertical: 'bottom' }}
                slotProps={{ paper: { sx: { minWidth: 200, mt: 0.5 } } }}
              >
                {/* User info header */}
                <Box px={2} py={1.25}>
                  <Typography variant="body2" fontWeight={600} noWrap>
                    {displayName ?? user.email}
                  </Typography>
                  {username && (
                    <Typography variant="caption" color="text.secondary">
                      @{username}
                    </Typography>
                  )}
                  {!username && (
                    <Typography variant="caption" color="text.secondary" noWrap>
                      {user.email}
                    </Typography>
                  )}
                </Box>
                <Divider />
                <MenuItem
                  component={NextLink}
                  href="/dashboard"
                  onClick={() => setAnchorEl(null)}
                >
                  <ListItemIcon>
                    <PersonIcon fontSize="small" />
                  </ListItemIcon>
                  Dashboard
                </MenuItem>
                <Divider />
                <MenuItem onClick={handleSignOut} sx={{ color: 'error.main' }}>
                  <ListItemIcon>
                    <LogoutIcon fontSize="small" color="error" />
                  </ListItemIcon>
                  Sign Out
                </MenuItem>
              </Menu>
            </>
          ) : (
            <>
              {/* Unauthenticated */}
              <Stack direction="row" spacing={1}>
                <Button
                  component={NextLink}
                  href="/auth/login"
                  variant="outlined"
                  size="small"
                >
                  Sign In
                </Button>
                <Button
                  component={NextLink}
                  href="/auth/signup"
                  variant="contained"
                  size="small"
                >
                  Sign Up
                </Button>
              </Stack>
            </>
          )}
        </Toolbar>
      </Container>
    </AppBar>
  );
}
