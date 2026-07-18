'use client'

import { createContext, useContext, useEffect, useState } from 'react'
import type { User } from '@supabase/supabase-js'

type UserContextValue = {
  user: User | null
  profile:  null
  isLoading: boolean
  refreshProfile: () => Promise<void>
}

const UserContext = createContext<UserContextValue>({
  user: null,
  profile: null,
  isLoading: true,
  refreshProfile: async () => {},
})

export function UserProvider({ children }: { children: React.ReactNode }) {
  const [user, setUser] = useState<User | null>(null)
  const [profile, setProfile] = useState< null>(null)
  const [isLoading, setIsLoading] = useState(true)

  async function fetchProfile() {
    // const { data } = await apiClient.me.get()
    // setProfile(data)
  }

  async function refreshProfile() {
    if (user) await fetchProfile()
  }

  useEffect(() => {
    // const supabase = createClient()

    // // onAuthStateChange fires immediately with INITIAL_SESSION
    // const {
    //   data: { subscription },
    // } = supabase.auth.onAuthStateChange(async (_event, session) => {
    //   const currentUser = session?.user ?? null
    //   setUser(currentUser)

    //   if (currentUser) {
    //     await fetchProfile()
    //   } else {
    //     setProfile(null)
    //   }

    //   setIsLoading(false)
    // })

    // return () => subscription.unsubscribe()
  }, [])

  return (
    <UserContext.Provider value={{ user, profile, isLoading, refreshProfile }}>
      {children}
    </UserContext.Provider>
  )
}

export function useUser() {
  return useContext(UserContext)
}
