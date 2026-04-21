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

    const { freelancer_id, gross_amount_myr, payment_intent_id, milestone_id } = await req.json();

    // Get the freelancer's Stripe connected account ID
    const { data: freelancerProfile } = await supabase
      .from('profiles')
      .select('stripe_account_id, display_name')
      .eq('uid', freelancer_id)
      .single();

    if (!freelancerProfile?.stripe_account_id) {
      return new Response(
        JSON.stringify({ error: 'Freelancer has not set up their payout account yet.' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    // Net = 90% of gross (platform keeps 10%)
    const netAmountCents = Math.round(gross_amount_myr * 0.9 * 100);

    // Transfer from platform account to freelancer's connected account
    const transfer = await stripe.transfers.create({
      amount: netAmountCents,
      currency: 'myr',
      destination: freelancerProfile.stripe_account_id,
      source_transaction: payment_intent_id,
      description: `Milestone payout for ${milestone_id}`,
      metadata: {
        freelancer_id,
        milestone_id,
        gross_amount_myr: gross_amount_myr.toString(),
      },
    });

    return new Response(
      JSON.stringify({
        transfer_id: transfer.id,
        net_amount_myr: (netAmountCents / 100).toFixed(2),
      }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('transfer-milestone-payout error:', err);
    const message = err instanceof Stripe.errors.StripeError
      ? err.message
      : 'Payout transfer failed.';
    return new Response(JSON.stringify({ error: message }), {
      status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
