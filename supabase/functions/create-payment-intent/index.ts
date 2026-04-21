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
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
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
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const { amount_myr, project_id } = await req.json();

    if (!amount_myr || amount_myr <= 0) {
      return new Response(JSON.stringify({ error: 'Invalid amount' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // Convert RM to cents
    const amountCents = Math.round(amount_myr * 100);

    // Create PaymentIntent — NOT confirmed yet.
    // Stripe Payment Sheet will handle card collection + confirmation.
    // Explicitly restrict to card-only so Stripe Link (redirect flow) is
    // never offered — Link requires an external browser round-trip that
    // breaks the in-app deep-link return.
    const paymentIntent = await stripe.paymentIntents.create({
      amount: amountCents,
      currency: 'myr',
      payment_method_types: ['card'],
      description: `Escrow for project ${project_id}`,
      metadata: {
        project_id: project_id ?? '',
        client_id: user.id,
      },
    });

    return new Response(
      JSON.stringify({
        payment_intent_id: paymentIntent.id,
        client_secret: paymentIntent.client_secret,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (err) {
    console.error('create-payment-intent error:', err);
    const message = err instanceof Stripe.errors.StripeError
        ? err.message
        : 'Payment processing failed. Please try again.';
    return new Response(JSON.stringify({ error: message }), {
      status: 400,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
