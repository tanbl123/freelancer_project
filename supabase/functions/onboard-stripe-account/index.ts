import Stripe from 'https://esm.sh/stripe@14?target=deno';
import { serve } from 'https://deno.land/std@0.168.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const stripe = new Stripe(Deno.env.get('STRIPE_SECRET_KEY')!, {
  apiVersion: '2023-10-16',
  httpClient: Stripe.createFetchHttpClient(),
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
      { global: { headers: { Authorization: authHeader } } },
    );

    const { data: { user }, error: authError } = await supabase.auth.getUser();
    if (authError || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), {
        status: 401, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Check if freelancer already has a Stripe account
    const { data: profile } = await supabase
      .from('profiles')
      .select('stripe_account_id, display_name, email')
      .eq('uid', user.id)
      .single();

    let accountId = profile?.stripe_account_id;

    if (!accountId) {
      // Create a new Stripe Express account
      const account = await stripe.accounts.create({
        type: 'express',
        email: profile?.email ?? user.email,
        capabilities: {
          transfers: { requested: true },
        },
        metadata: { user_id: user.id },
      });
      accountId = account.id;

      // Save the Stripe account ID to the profile
      await supabase
        .from('profiles')
        .update({ stripe_account_id: accountId })
        .eq('uid', user.id);
    }

    // Create an onboarding link
    const accountLink = await stripe.accountLinks.create({
      account: accountId,
      refresh_url: 'https://prztvccblematqiitrao.supabase.co/functions/v1/onboard-stripe-account',
      return_url: 'https://prztvccblematqiitrao.supabase.co/functions/v1/onboard-stripe-account',
      type: 'account_onboarding',
    });

    return new Response(
      JSON.stringify({
        onboarding_url: accountLink.url,
        account_id: accountId,
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('onboard-stripe-account error:', err);
    return new Response(JSON.stringify({ error: err.message ?? 'Failed to create account.' }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
