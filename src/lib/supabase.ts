import { createClient, type SupabaseClient } from '@supabase/supabase-js';
import { env } from '$env/dynamic/public';

const url = env.PUBLIC_SUPABASE_URL;
const anon = env.PUBLIC_SUPABASE_ANON_KEY;

export const hasSupabaseEnv = Boolean(url && anon);

if (!hasSupabaseEnv) {
	console.warn('Supabase env vars missing: set PUBLIC_SUPABASE_URL and PUBLIC_SUPABASE_ANON_KEY');
}

const fallbackClient = () =>
	({
		from: () => ({
			select: async () => ({ data: null, error: new Error('Supabase not configured') }),
			order: () => ({ select: async () => ({ data: null, error: new Error('Supabase not configured') }) })
		})
	} as unknown as SupabaseClient);

export const supabase = hasSupabaseEnv ? createClient(url, anon) : fallbackClient();
