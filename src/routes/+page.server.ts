import { supabase } from '$lib/supabase';

export async function load() {
    const { data: layoffs } = await supabase
        .from('fact_layoffs')
        .select('date, employees_laidoff, employees_notified')
        .eq('granularity', 'total')
        .order('date', { ascending: false })
        .limit(12);

    const { data: sectors } = await supabase
        .from('fact_hiring_attrition')
        .select('date, hiring_rate_sa, attrition_rate_sa, dim_sectors(name)')
        .eq('granularity', 'sector')
        .order('date', { ascending: false })
        .limit(50); // Top 50 rows for now

    return {
        layoffs: layoffs || [],
        sectors: sectors || []
    };
}
