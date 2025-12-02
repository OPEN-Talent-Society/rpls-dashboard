# Check Stripe Balance

Retrieve current Stripe account balance and pending payouts.

## Instructions

Run the Stripe CLI to check the balance:

```bash
pnpm dlx stripe balance retrieve
```

This shows:
- Available balance (ready to payout)
- Pending balance (processing)
- Currency breakdown

For more details on recent payouts:
```bash
pnpm dlx stripe payouts list --limit 10
```

For recent charges:
```bash
pnpm dlx stripe charges list --limit 10
```
