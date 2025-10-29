import { NextAuthOptions, getServerSession } from 'next-auth';
import CredentialsProvider from 'next-auth/providers/credentials';
import { createClient } from '@supabase/supabase-js';

// Evitar inicializar el cliente en ámbito de módulo. Crear bajo demanda.
function getSupabaseAnon() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL;
  const anon = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY;
  if (!url || !anon) {
    throw new Error('Faltan NEXT_PUBLIC_SUPABASE_URL o NEXT_PUBLIC_SUPABASE_ANON_KEY');
  }
  return createClient(url, anon, {
    auth: {
      autoRefreshToken: false,
      persistSession: false,
      detectSessionInUrl: false,
    },
  });
}

export const authOptions: NextAuthOptions = {
  providers: [
    CredentialsProvider({
      name: 'Credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          throw new Error('Email y contraseña son requeridos');
        }

        const supabase = getSupabaseAnon();
        const { data: { user }, error } = await supabase.auth.signInWithPassword({
          email: credentials.email,
          password: credentials.password,
        });

        if (error || !user) {
          const msg = (error?.message || '').toLowerCase();
          if (msg.includes('confirm')) {
            throw new Error('Email no confirmado. Revisa tu correo para activar tu cuenta.');
          }
          throw new Error('Credenciales inválidas');
        }
        if (!user.email) {
          throw new Error('El usuario no tiene un email válido');
        }

        return {
          id: user.id,
          email: user.email,
          name: user.user_metadata?.full_name || user.email.split('@')[0],
        };
      },
    }),
  ],
  session: { strategy: 'jwt' },
  callbacks: {
    async jwt({ token, user, account }) {
      if (account?.access_token) {
        token.accessToken = account.access_token;
      }
      if (user) {
        token.id = (user as any).id;
        token.role = (user as any).role;
      }
      return token;
    },
    async session({ session, token }) {
      if (session?.user) {
        session.user.id = token.sub || '';
        (session.user as any).role = token.role as string;
        (session as any).accessToken = token.accessToken as string;
      }
      return session;
    },
  },
  pages: {
    signIn: '/auth/login',
    error: '/auth/error',
    newUser: '/auth/register',
  },
  debug: process.env.NODE_ENV === 'development',
  secret: process.env.NEXTAUTH_SECRET,
};

export async function auth() {
  return getServerSession(authOptions);
}
