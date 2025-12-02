# Stripe Payments Skill

Comprehensive Stripe CLI and API integration for payment processing, webhooks, and revenue management.

## When to Use

Use this skill when:
- Setting up Stripe checkout sessions
- Testing webhooks locally with `stripe listen`
- Managing products and pricing
- Processing refunds
- Auditing revenue and payouts
- Triggering test events

## Prerequisites

Required environment variables:
- `STRIPE_SECRET_KEY` - Stripe API secret key (sk_test_* or sk_live_*)
- `STRIPE_PUBLISHABLE_KEY` - Stripe publishable key (pk_test_* or pk_live_*)
- `STRIPE_WEBHOOK_SECRET` - Webhook signing secret (whsec_*)

## Stripe CLI Commands

### Authentication

```bash
# Login to Stripe
stripe login

# Logout
stripe logout

# Check CLI status
stripe status
```

### Webhook Forwarding (stripe listen)

```bash
# Basic webhook forwarding
stripe listen --forward-to localhost:3000/api/webhooks/stripe

# Filter specific events
stripe listen --events payment_intent.created,charge.succeeded,checkout.session.completed --forward-to localhost:3000/api/webhooks/stripe

# Use latest API version (recommended for typed SDKs)
stripe listen --forward-to localhost:3000/api/webhooks/stripe --latest

# Load config from Stripe Dashboard
stripe listen --load-from-webhooks-api --forward-to localhost:3000/api/webhooks/stripe

# Stripe Connect events (separate handler)
stripe listen --forward-to localhost:3000/api/webhooks/stripe --forward-connect-to localhost:3000/api/webhooks/connect

# Skip HTTPS verification (dev only)
stripe listen --skip-verify --forward-to localhost:3000/api/webhooks/stripe
```

**Important:** The `stripe listen` command outputs a webhook signing secret (whsec_xxx). Store this in your `.env.local` as `STRIPE_WEBHOOK_SECRET`.

### Trigger Test Events

```bash
# Common test events
stripe trigger checkout.session.completed
stripe trigger payment_intent.succeeded
stripe trigger customer.subscription.created
stripe trigger invoice.payment_succeeded
stripe trigger charge.failed
stripe trigger charge.refunded

# Override event properties
stripe trigger customer.created --override customer:name=Bob
stripe trigger price.created --override product:name=foo --override price:unit_amount=4200

# Add metadata
stripe trigger checkout.session.completed --add checkout_session:metadata.userId=123

# Discover available events
stripe trigger --help
stripe trigger checkout --help
stripe trigger payment_intent --help
```

### Products

```bash
# Create product
stripe products create --name "AI Enablement Cohort" --type "service"

# List products
stripe products list

# Retrieve product
stripe products retrieve prod_xxxxx

# Update product
stripe products update prod_xxxxx --name "Updated Name"

# Delete product
stripe products delete prod_xxxxx

# Search products
stripe products search --query "name='Premium'"
```

### Prices

```bash
# Create one-time price (amount in cents: 9900 = $99.00)
stripe prices create --product prod_xxxxx --unit-amount 9900 --currency usd

# Create recurring price
stripe prices create --product prod_xxxxx --unit-amount 2999 --currency usd --recurring-interval month

# List prices
stripe prices list
stripe prices list --product prod_xxxxx

# Retrieve price
stripe prices retrieve price_xxxxx

# Update price metadata
stripe prices update price_xxxxx --metadata tier=premium
```

### Charges

```bash
# List recent charges
stripe charges list
stripe charges list --limit 10
stripe charges list --customer cus_xxxxx

# Retrieve charge
stripe charges retrieve ch_xxxxx

# Update charge
stripe charges update ch_xxxxx --description "Updated description"

# Capture authorized charge
stripe charges capture ch_xxxxx
```

### Refunds

```bash
# Full refund
stripe refunds create --charge ch_xxxxx

# Partial refund (amount in cents)
stripe refunds create --charge ch_xxxxx --amount 1000

# Refund via PaymentIntent
stripe refunds create --payment-intent pi_xxxxx

# List refunds
stripe refunds list
stripe refunds list --charge ch_xxxxx

# Retrieve refund
stripe refunds retrieve re_xxxxx
```

### Balance & Payouts

```bash
# Get account balance
stripe balance retrieve

# List payouts
stripe payouts list
stripe payouts list --limit 10
```

### Customers

```bash
# Create customer
stripe customers create --email customer@example.com --name "John Doe"

# List customers
stripe customers list

# Retrieve customer
stripe customers retrieve cus_xxxxx

# Update customer
stripe customers update cus_xxxxx --metadata subscription_tier=premium
```

### Logs & Debugging

```bash
# Stream API logs in real-time
stripe logs tail
stripe logs tail --filter "status:failed"

# Resend previous events
stripe events resend evt_xxxxx
```

## Common Webhook Events

| Event | Description |
|-------|-------------|
| `checkout.session.completed` | Customer completed checkout |
| `payment_intent.succeeded` | Payment was successful |
| `payment_intent.payment_failed` | Payment failed |
| `customer.subscription.created` | New subscription started |
| `customer.subscription.updated` | Subscription changed |
| `customer.subscription.deleted` | Subscription canceled |
| `invoice.paid` | Invoice was paid |
| `invoice.payment_failed` | Invoice payment failed |
| `charge.succeeded` | Charge was successful |
| `charge.failed` | Charge failed |
| `charge.refunded` | Charge was refunded |
| `customer.created` | New customer created |

## API Code Patterns

### Lazy Initialization (Required for SSR/Build)

```typescript
// CORRECT - Lazy initialization
function getStripeClient(): Stripe {
  const apiKey = process.env.STRIPE_SECRET_KEY
  if (!apiKey) {
    throw new Error('STRIPE_SECRET_KEY not configured')
  }
  return new Stripe(apiKey, { apiVersion: '2025-11-17.clover' })
}

// WRONG - Breaks SSR builds
const stripe = new Stripe(process.env.STRIPE_SECRET_KEY || '')
```

### Webhook Handler

```typescript
export async function POST(request: NextRequest) {
  const body = await request.text()
  const signature = request.headers.get('stripe-signature')!

  const stripe = getStripeClient()
  const webhookSecret = process.env.STRIPE_WEBHOOK_SECRET!

  // Verify webhook signature
  const event = stripe.webhooks.constructEvent(body, signature, webhookSecret)

  switch (event.type) {
    case 'checkout.session.completed':
      await handleCheckoutComplete(event.data.object)
      break
    case 'invoice.payment_failed':
      await handlePaymentFailed(event.data.object)
      break
  }

  return NextResponse.json({ received: true })
}
```

### Checkout Session Creation

```typescript
const session = await stripe.checkout.sessions.create({
  mode: 'payment',
  payment_method_types: ['card'],
  line_items: [{ price: 'price_xxx', quantity: 1 }],
  success_url: `${origin}/success?session_id={CHECKOUT_SESSION_ID}`,
  cancel_url: `${origin}/cancel`,
  customer_email: user.email,
  metadata: { userId: user.id, productId }
})
```

## Best Practices

### 1. Webhook Signature Verification
- Always verify signatures using `stripe.webhooks.constructEvent()`
- Never skip verification in production
- Use raw request body (not parsed JSON)

### 2. Quick Response
- Return 2xx status within 5 seconds
- Process complex logic asynchronously
- Queue heavy operations for background jobs

### 3. Test Mode vs Live Mode
- Test keys: `sk_test_*`, `pk_test_*`
- Live keys: `sk_live_*`, `pk_live_*`
- Webhook secrets differ between modes

### 4. Amount Handling
- All amounts in smallest currency unit
- USD: 9900 = $99.00
- EUR: 9900 = €99.00

## Integration Points

- **Payload CMS**: Store enrollment/subscription records
- **Brevo**: Send payment receipts, dunning emails
- **NocoDB**: Log transactions for reporting
- **Cortex**: Document payment workflows

## Testing Workflow

```bash
# Terminal 1: Start webhook listener
stripe listen --forward-to localhost:3000/api/webhooks/stripe --latest

# Terminal 2: Start your app
pnpm dev

# Terminal 3: Trigger test events
stripe trigger checkout.session.completed
stripe trigger payment_intent.succeeded
stripe trigger charge.failed
```

## Troubleshooting

### Build Fails with "apiKey not provided"
- Use lazy initialization pattern
- Never initialize Stripe at module scope with empty fallback

### Webhook Signature Invalid
- Ensure raw body is used (not parsed JSON)
- Check webhook secret matches the endpoint
- Verify you're using the secret from `stripe listen`

### Events Not Received
- Check `stripe listen` is running
- Verify endpoint URL is correct
- Check app console for errors

## Sources
- [Stripe CLI Documentation](https://docs.stripe.com/stripe-cli)
- [Stripe Webhooks Guide](https://docs.stripe.com/webhooks)
- [Stripe API Reference](https://docs.stripe.com/api)
