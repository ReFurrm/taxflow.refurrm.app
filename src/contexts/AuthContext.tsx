import React, { createContext, useContext, useState, useEffect } from 'react';
import { supabase } from '@/lib/supabase';
import { User } from '@supabase/supabase-js';

interface AuthContextType {
  user: User | null;
  loading: boolean;
  isEmailVerified: boolean;
  signUp: (email: string, password: string, metadata?: any) => Promise<any>;
  signIn: (email: string, password: string) => Promise<any>;
  signOut: () => Promise<void>;
  resetPassword: (email: string) => Promise<any>;
  updateProfile: (updates: any) => Promise<any>;
}


const AuthContext = createContext<AuthContextType | undefined>(undefined);

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) throw new Error('useAuth must be used within AuthProvider');
  return context;
};

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<User | null>(null);
  const [loading, setLoading] = useState(true);
  const [isEmailVerified, setIsEmailVerified] = useState(false);
  const devAdminEmail = 'admin@sample.com';

  useEffect(() => {
    supabase.auth.getSession().then(({ data: { session } }) => {
      setUser(session?.user ?? null);
      const verified = session?.user?.email_confirmed_at ? true : false;
      setIsEmailVerified(import.meta.env.DEV && session?.user?.email === devAdminEmail ? true : verified);
      setLoading(false);
    });

    const { data: { subscription } } = supabase.auth.onAuthStateChange((_event, session) => {
      setUser(session?.user ?? null);
      const verified = session?.user?.email_confirmed_at ? true : false;
      setIsEmailVerified(import.meta.env.DEV && session?.user?.email === devAdminEmail ? true : verified);
    });

    return () => subscription.unsubscribe();
  }, []);


  const signUp = async (email: string, password: string, metadata?: any) => {
    return await supabase.auth.signUp({ email, password, options: { data: metadata } });
  };

  const signIn = async (email: string, password: string) => {
    const result = await supabase.auth.signInWithPassword({ email, password });
    
    // Log security event
    if (result.data.session) {
      try {
        await supabase.functions.invoke('log-security-event', {
          body: {
            eventType: 'login',
            sessionId: result.data.session.access_token.substring(0, 20),
            ipAddress: 'client-side',
            deviceInfo: navigator.platform,
            userAgent: navigator.userAgent
          }
        });
      } catch (error) {
        console.error('Failed to log security event:', error);
      }
    }
    
    return result;
  };


  const signOut = async () => {
    // Log logout event
    try {
      await supabase.functions.invoke('log-security-event', {
        body: {
          eventType: 'logout',
          sessionId: '',
          ipAddress: 'client-side',
          deviceInfo: navigator.platform,
          userAgent: navigator.userAgent
        }
      });
    } catch (error) {
      console.error('Failed to log security event:', error);
    }
    
    await supabase.auth.signOut();
  };


  const resetPassword = async (email: string) => {
    return await supabase.auth.resetPasswordForEmail(email);
  };

  const updateProfile = async (updates: any) => {
    return await supabase.auth.updateUser({ data: updates });
  };

  return (
    <AuthContext.Provider value={{ user, loading, isEmailVerified, signUp, signIn, signOut, resetPassword, updateProfile }}>
      {children}
    </AuthContext.Provider>
  );
};
