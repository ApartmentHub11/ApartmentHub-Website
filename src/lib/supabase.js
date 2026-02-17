import { createClient } from '@supabase/supabase-js';

const SUPABASE_URL = process.env.NEXT_PUBLIC_SUPABASE_URL;
const SUPABASE_PUBLISHABLE_KEY = process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;

if (!SUPABASE_URL || !SUPABASE_PUBLISHABLE_KEY) {
    console.warn('Supabase credentials not configured. Calculator will use fallback logic.');
}

let supabase = null;

if (typeof window !== 'undefined' && SUPABASE_URL && SUPABASE_PUBLISHABLE_KEY) {
    supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
        auth: {
            storage: localStorage,
            persistSession: true,
            autoRefreshToken: true,
        }
    });
} else if (SUPABASE_URL && SUPABASE_PUBLISHABLE_KEY) {
    // Server-side: create without localStorage
    supabase = createClient(SUPABASE_URL, SUPABASE_PUBLISHABLE_KEY, {
        auth: {
            persistSession: false,
            autoRefreshToken: false,
            detectSessionInUrl: false,
        },
    });
}

export { supabase };
