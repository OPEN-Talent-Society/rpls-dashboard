# Stripe Webhook Testing

Test Stripe webhooks locally for payment integration development.

## Instructions

1. Start the webhook forwarding:
```bash
pnpm dlx stripe listen --forward-to localhost:3000/api/webhooks/stripe
```

2. Note the webhook signing secret (whsec_xxx) and update .env.local if needed

3. Trigger test events:
```bash
# Successful checkout
pnpm dlx stripe trigger checkout.session.completed

# Subscription created
pnpm dlx stripe trigger customer.subscription.created

# Payment failed
pnpm dlx stripe trigger invoice.payment_failed
```

4. Check the console output for webhook handling results

5. Verify the integration by:
   - Checking database for new records
   - Confirming email notifications sent
   - Reviewing application logs
