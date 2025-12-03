# SDK Integrations

## Overview

This document provides complete integration patterns for all third-party SDKs used in the AI Enablement Academy v2 platform. Each integration includes installation, configuration, TypeScript examples, and error handling patterns.

---

## 1. Stripe SDK (@stripe/stripe-node)

### Installation

```bash
pnpm add stripe
```

### Configuration

**Version**: Latest (2024-11-20.acacia API)

```typescript
// lib/stripe/config.ts
import Stripe from 'stripe';

if (!process.env.STRIPE_SECRET_KEY) {
  throw new Error('STRIPE_SECRET_KEY is not defined');
}

export const stripe = new Stripe(process.env.STRIPE_SECRET_KEY, {
  apiVersion: '2024-11-20.acacia',
  typescript: true,
  appInfo: {
    name: 'AI Enablement Academy',
    version: '2.0.0',
  },
});

export const STRIPE_CONFIG = {
  publishableKey: process.env.NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY!,
  webhookSecret: process.env.STRIPE_WEBHOOK_SECRET!,
  currency: 'usd' as const,
} as const;
```

### Checkout Session Creation

```typescript
// lib/stripe/checkout.ts
import { stripe } from './config';
import type { CourseVariant } from '@/types/course';

interface CreateCheckoutSessionParams {
  userId: string;
  email: string;
  courseId: string;
  variantId: string;
  variant: CourseVariant;
  successUrl: string;
  cancelUrl: string;
}

export async function createCheckoutSession({
  userId,
  email,
  courseId,
  variantId,
  variant,
  successUrl,
  cancelUrl,
}: CreateCheckoutSessionParams): Promise<Stripe.Checkout.Session> {
  try {
    const session = await stripe.checkout.sessions.create({
      mode: 'payment',
      customer_email: email,
      line_items: [
        {
          price_data: {
            currency: 'usd',
            product_data: {
              name: variant.title,
              description: variant.description,
              metadata: {
                courseId,
                variantId,
              },
            },
            unit_amount: variant.price * 100, // Convert to cents
          },
          quantity: 1,
        },
      ],
      metadata: {
        userId,
        courseId,
        variantId,
        variantType: variant.type,
      },
      success_url: successUrl,
      cancel_url: cancelUrl,
      expires_at: Math.floor(Date.now() / 1000) + 3600, // 1 hour
    });

    return session;
  } catch (error) {
    if (error instanceof Stripe.errors.StripeError) {
      throw new Error(`Stripe checkout error: ${error.message}`);
    }
    throw error;
  }
}
```

### Webhook Signature Verification

```typescript
// app/api/webhooks/stripe/route.ts
import { headers } from 'next/headers';
import { stripe, STRIPE_CONFIG } from '@/lib/stripe/config';
import { handleCheckoutCompleted } from '@/lib/stripe/webhook-handlers';

export async function POST(req: Request) {
  const body = await req.text();
  const signature = headers().get('stripe-signature');

  if (!signature) {
    return new Response('No signature provided', { status: 400 });
  }

  let event: Stripe.Event;

  try {
    event = stripe.webhooks.constructEvent(
      body,
      signature,
      STRIPE_CONFIG.webhookSecret
    );
  } catch (error) {
    console.error('Webhook signature verification failed:', error);
    return new Response(
      `Webhook Error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      { status: 400 }
    );
  }

  try {
    switch (event.type) {
      case 'checkout.session.completed':
        await handleCheckoutCompleted(event.data.object as Stripe.Checkout.Session);
        break;
      case 'charge.refunded':
        await handleChargeRefunded(event.data.object as Stripe.Charge);
        break;
      default:
        console.log(`Unhandled event type: ${event.type}`);
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 });
  } catch (error) {
    console.error('Webhook handler error:', error);
    return new Response(
      `Webhook handler error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      { status: 500 }
    );
  }
}
```

### Manual Invoice Creation (B2B)

```typescript
// lib/stripe/invoices.ts
import { stripe } from './config';

interface CreateInvoiceParams {
  customerId: string;
  items: Array<{
    description: string;
    amount: number;
    quantity: number;
  }>;
  dueDate?: Date;
  metadata?: Record<string, string>;
}

export async function createManualInvoice({
  customerId,
  items,
  dueDate,
  metadata = {},
}: CreateInvoiceParams): Promise<Stripe.Invoice> {
  try {
    // Create invoice items
    for (const item of items) {
      await stripe.invoiceItems.create({
        customer: customerId,
        amount: item.amount * 100, // Convert to cents
        currency: 'usd',
        description: item.description,
        quantity: item.quantity,
      });
    }

    // Create and finalize invoice
    const invoice = await stripe.invoices.create({
      customer: customerId,
      auto_advance: true, // Auto-finalize
      collection_method: 'send_invoice',
      days_until_due: dueDate
        ? Math.ceil((dueDate.getTime() - Date.now()) / (1000 * 60 * 60 * 24))
        : 30,
      metadata,
    });

    // Finalize and send
    const finalizedInvoice = await stripe.invoices.finalizeInvoice(invoice.id);
    await stripe.invoices.sendInvoice(invoice.id);

    return finalizedInvoice;
  } catch (error) {
    if (error instanceof Stripe.errors.StripeError) {
      throw new Error(`Invoice creation failed: ${error.message}`);
    }
    throw error;
  }
}
```

### Refund Processing

```typescript
// lib/stripe/refunds.ts
import { stripe } from './config';

interface ProcessRefundParams {
  chargeId: string;
  amount?: number; // Optional partial refund amount in cents
  reason?: 'duplicate' | 'fraudulent' | 'requested_by_customer';
  metadata?: Record<string, string>;
}

export async function processRefund({
  chargeId,
  amount,
  reason = 'requested_by_customer',
  metadata = {},
}: ProcessRefundParams): Promise<Stripe.Refund> {
  try {
    const refund = await stripe.refunds.create({
      charge: chargeId,
      amount, // Omit for full refund
      reason,
      metadata,
    });

    return refund;
  } catch (error) {
    if (error instanceof Stripe.errors.StripeError) {
      if (error.code === 'charge_already_refunded') {
        throw new Error('This charge has already been refunded');
      }
      throw new Error(`Refund failed: ${error.message}`);
    }
    throw error;
  }
}
```

### Error Handling Patterns

```typescript
// lib/stripe/errors.ts
import Stripe from 'stripe';

export function handleStripeError(error: unknown): never {
  if (error instanceof Stripe.errors.StripeCardError) {
    // Card was declined
    throw new Error(`Payment failed: ${error.message}`);
  } else if (error instanceof Stripe.errors.StripeRateLimitError) {
    // Too many requests
    throw new Error('Too many requests. Please try again later.');
  } else if (error instanceof Stripe.errors.StripeInvalidRequestError) {
    // Invalid parameters
    throw new Error(`Invalid request: ${error.message}`);
  } else if (error instanceof Stripe.errors.StripeAPIError) {
    // Stripe API error
    throw new Error('Payment service error. Please try again.');
  } else if (error instanceof Stripe.errors.StripeConnectionError) {
    // Network communication error
    throw new Error('Network error. Please check your connection.');
  } else if (error instanceof Stripe.errors.StripeAuthenticationError) {
    // Authentication error
    throw new Error('Payment authentication failed.');
  } else {
    throw error;
  }
}
```

---

## 2. Brevo SDK (@getbrevo/brevo)

### Installation

```bash
pnpm add @getbrevo/brevo
```

### API Client Initialization

```typescript
// lib/brevo/config.ts
import * as brevo from '@getbrevo/brevo';

if (!process.env.BREVO_API_KEY) {
  throw new Error('BREVO_API_KEY is not defined');
}

const apiInstance = new brevo.TransactionalEmailsApi();
const contactsInstance = new brevo.ContactsApi();

apiInstance.setApiKey(
  brevo.TransactionalEmailsApiApiKeys.apiKey,
  process.env.BREVO_API_KEY
);

contactsInstance.setApiKey(
  brevo.ContactsApiApiKeys.apiKey,
  process.env.BREVO_API_KEY
);

export { apiInstance as emailApi, contactsInstance as contactsApi };
```

### Template IDs Enum

```typescript
// lib/brevo/templates.ts
export enum EmailTemplate {
  WELCOME = 1,
  ENROLLMENT_CONFIRMATION = 2,
  REMINDER_7D = 3,
  REMINDER_2D = 4,
  REMINDER_1D = 5,
  SESSION_STARTING = 6,
  OFFICE_HOURS_CONFIRMATION = 7,
  CERTIFICATE_READY = 8,
  FEEDBACK_REQUEST = 9,
  PASSWORD_RESET = 10,
  PAYMENT_RECEIPT = 11,
  REFUND_CONFIRMATION = 12,
}

export enum ContactList {
  NEWSLETTER = 2,
  ACTIVE_LEARNERS = 3,
  ALUMNI = 4,
  COHORT_WAITLIST = 5,
  SELF_PACED_LEARNERS = 6,
}
```

### Send Transactional Email

```typescript
// lib/brevo/email.ts
import * as brevo from '@getbrevo/brevo';
import { emailApi } from './config';
import { EmailTemplate } from './templates';

interface SendEmailParams {
  to: string;
  templateId: EmailTemplate;
  params?: Record<string, string | number>;
  tags?: string[];
}

export async function sendTransactionalEmail({
  to,
  templateId,
  params = {},
  tags = [],
}: SendEmailParams): Promise<void> {
  const sendSmtpEmail = new brevo.SendSmtpEmail();

  sendSmtpEmail.to = [{ email: to }];
  sendSmtpEmail.templateId = templateId;
  sendSmtpEmail.params = params;
  sendSmtpEmail.tags = tags;

  try {
    await emailApi.sendTransacEmail(sendSmtpEmail);
  } catch (error) {
    console.error('Brevo email send error:', error);
    throw new Error(`Failed to send email: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

// Example usage
export async function sendWelcomeEmail(email: string, name: string): Promise<void> {
  await sendTransactionalEmail({
    to: email,
    templateId: EmailTemplate.WELCOME,
    params: {
      NAME: name,
      DASHBOARD_URL: 'https://learn.aienablement.academy/dashboard',
    },
    tags: ['welcome', 'onboarding'],
  });
}

export async function sendEnrollmentConfirmation(
  email: string,
  name: string,
  courseName: string,
  startDate: string,
  cohortId: string
): Promise<void> {
  await sendTransactionalEmail({
    to: email,
    templateId: EmailTemplate.ENROLLMENT_CONFIRMATION,
    params: {
      NAME: name,
      COURSE_NAME: courseName,
      START_DATE: startDate,
      COHORT_ID: cohortId,
      CALENDAR_URL: `https://learn.aienablement.academy/cohorts/${cohortId}/calendar`,
    },
    tags: ['enrollment', 'cohort'],
  });
}
```

### Contact Management

```typescript
// lib/brevo/contacts.ts
import * as brevo from '@getbrevo/brevo';
import { contactsApi } from './config';
import { ContactList } from './templates';

interface CreateContactParams {
  email: string;
  attributes?: {
    FIRSTNAME?: string;
    LASTNAME?: string;
    COMPANY?: string;
    ROLE?: string;
    ENROLLMENT_DATE?: string;
  };
  listIds?: ContactList[];
  updateEnabled?: boolean;
}

export async function createOrUpdateContact({
  email,
  attributes = {},
  listIds = [],
  updateEnabled = true,
}: CreateContactParams): Promise<void> {
  const createContact = new brevo.CreateContact();

  createContact.email = email;
  createContact.attributes = attributes;
  createContact.listIds = listIds;
  createContact.updateEnabled = updateEnabled;

  try {
    await contactsApi.createContact(createContact);
  } catch (error) {
    if (error instanceof Error && error.message.includes('already exists')) {
      // Contact exists, update instead if updateEnabled is false
      if (!updateEnabled) {
        throw new Error('Contact already exists');
      }
    } else {
      console.error('Brevo contact creation error:', error);
      throw new Error(`Failed to create contact: ${error instanceof Error ? error.message : 'Unknown error'}`);
    }
  }
}

export async function addContactToList(email: string, listId: ContactList): Promise<void> {
  const contactEmails = new brevo.AddContactToList();
  contactEmails.emails = [email];

  try {
    await contactsApi.addContactToList(listId, contactEmails);
  } catch (error) {
    console.error('Brevo add to list error:', error);
    throw new Error(`Failed to add contact to list: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}

export async function removeContactFromList(email: string, listId: ContactList): Promise<void> {
  const contactEmails = new brevo.RemoveContactFromList();
  contactEmails.emails = [email];

  try {
    await contactsApi.removeContactFromList(listId, contactEmails);
  } catch (error) {
    console.error('Brevo remove from list error:', error);
    throw new Error(`Failed to remove contact from list: ${error instanceof Error ? error.message : 'Unknown error'}`);
  }
}
```

### Convex Internal Action Pattern

```typescript
// convex/emails.ts
import { internal } from './_generated/api';
import { internalAction } from './_generated/server';
import { sendTransactionalEmail } from '@/lib/brevo/email';
import { EmailTemplate } from '@/lib/brevo/templates';

export const sendEnrollmentEmail = internalAction({
  args: {
    email: v.string(),
    name: v.string(),
    courseName: v.string(),
    startDate: v.string(),
    cohortId: v.string(),
  },
  handler: async (ctx, args) => {
    try {
      await sendTransactionalEmail({
        to: args.email,
        templateId: EmailTemplate.ENROLLMENT_CONFIRMATION,
        params: {
          NAME: args.name,
          COURSE_NAME: args.courseName,
          START_DATE: args.startDate,
          COHORT_ID: args.cohortId,
        },
        tags: ['enrollment', 'cohort'],
      });
    } catch (error) {
      console.error('Failed to send enrollment email:', error);
      // Don't throw - email failures shouldn't break enrollment
    }
  },
});

// Scheduled email reminders
export const sendCohortReminders = internalAction({
  handler: async (ctx) => {
    // Get cohorts starting in 7 days, 2 days, 1 day
    const cohorts = await ctx.runQuery(internal.cohorts.getUpcomingCohorts);

    for (const cohort of cohorts) {
      const daysUntilStart = Math.ceil(
        (new Date(cohort.startDate).getTime() - Date.now()) / (1000 * 60 * 60 * 24)
      );

      let templateId: EmailTemplate;
      if (daysUntilStart === 7) templateId = EmailTemplate.REMINDER_7D;
      else if (daysUntilStart === 2) templateId = EmailTemplate.REMINDER_2D;
      else if (daysUntilStart === 1) templateId = EmailTemplate.REMINDER_1D;
      else continue;

      // Send to all enrolled students
      for (const enrollment of cohort.enrollments) {
        await sendTransactionalEmail({
          to: enrollment.email,
          templateId,
          params: {
            NAME: enrollment.name,
            COURSE_NAME: cohort.courseName,
            START_DATE: cohort.startDate,
            COHORT_URL: `https://learn.aienablement.academy/cohorts/${cohort._id}`,
          },
          tags: ['reminder', `${daysUntilStart}d`],
        });
      }
    }
  },
});
```

---

## 3. PostHog JS (posthog-js)

### Installation

```bash
pnpm add posthog-js
```

### Self-Hosted Configuration

```typescript
// lib/posthog/config.ts
export const POSTHOG_CONFIG = {
  apiKey: process.env.NEXT_PUBLIC_POSTHOG_KEY!,
  apiHost: 'https://analytics.aienablement.academy',
  options: {
    api_host: 'https://analytics.aienablement.academy',
    ui_host: 'https://analytics.aienablement.academy',
    disable_session_recording: false,
    session_recording: {
      recordCrossOriginIframes: true,
    },
    autocapture: false, // Manual event tracking only
    capture_pageview: false, // Manual pageview tracking
    capture_pageleave: true,
    persistence: 'localStorage+cookie',
    cross_subdomain_cookie: true,
  },
} as const;
```

### Next.js Provider Setup

```typescript
// components/providers/posthog-provider.tsx
'use client';

import { useEffect } from 'react';
import { usePathname, useSearchParams } from 'next/navigation';
import posthog from 'posthog-js';
import { PostHogProvider as PHProvider } from 'posthog-js/react';
import { POSTHOG_CONFIG } from '@/lib/posthog/config';

if (typeof window !== 'undefined') {
  posthog.init(POSTHOG_CONFIG.apiKey, POSTHOG_CONFIG.options);
}

export function PostHogProvider({ children }: { children: React.ReactNode }) {
  const pathname = usePathname();
  const searchParams = useSearchParams();

  useEffect(() => {
    if (pathname) {
      let url = window.origin + pathname;
      if (searchParams && searchParams.toString()) {
        url = url + '?' + searchParams.toString();
      }
      posthog.capture('$pageview', {
        $current_url: url,
      });
    }
  }, [pathname, searchParams]);

  return <PHProvider client={posthog}>{children}</PHProvider>;
}
```

### Analytics Hook with Predefined Events

```typescript
// hooks/use-analytics.ts
import { usePostHog } from 'posthog-js/react';
import { useUser } from '@clerk/nextjs';

export function useAnalytics() {
  const posthog = usePostHog();
  const { user } = useUser();

  // Identify user
  const identifyUser = (userId: string, traits?: Record<string, any>) => {
    posthog.identify(userId, {
      email: user?.emailAddresses[0]?.emailAddress,
      name: user?.fullName,
      ...traits,
    });
  };

  // Course events
  const trackCourseViewed = (courseId: string, courseName: string) => {
    posthog.capture('course_viewed', {
      course_id: courseId,
      course_name: courseName,
    });
  };

  // Checkout events
  const trackCheckoutStarted = (
    courseId: string,
    variantId: string,
    price: number
  ) => {
    posthog.capture('checkout_started', {
      course_id: courseId,
      variant_id: variantId,
      price,
      currency: 'usd',
    });
  };

  const trackCheckoutCompleted = (
    courseId: string,
    variantId: string,
    price: number,
    transactionId: string
  ) => {
    posthog.capture('checkout_completed', {
      course_id: courseId,
      variant_id: variantId,
      price,
      currency: 'usd',
      transaction_id: transactionId,
    });
  };

  // Survey events
  const trackSurveyCompleted = (
    surveyId: string,
    surveyName: string,
    responses: Record<string, any>
  ) => {
    posthog.capture('survey_completed', {
      survey_id: surveyId,
      survey_name: surveyName,
      responses,
    });
  };

  // Content events
  const trackRecordingViewed = (
    recordingId: string,
    sessionName: string,
    duration: number
  ) => {
    posthog.capture('recording_viewed', {
      recording_id: recordingId,
      session_name: sessionName,
      duration,
    });
  };

  const trackKitDownloaded = (kitId: string, kitName: string) => {
    posthog.capture('kit_downloaded', {
      kit_id: kitId,
      kit_name: kitName,
    });
  };

  // Engagement events
  const trackOfficeHoursBooked = (
    bookingId: string,
    date: string,
    duration: number
  ) => {
    posthog.capture('office_hours_booked', {
      booking_id: bookingId,
      date,
      duration,
    });
  };

  const trackChatbotMessage = (message: string, responseTime: number) => {
    posthog.capture('chatbot_message', {
      message_length: message.length,
      response_time: responseTime,
    });
  };

  const trackCertificateShared = (
    certificateId: string,
    platform: 'linkedin' | 'twitter' | 'email'
  ) => {
    posthog.capture('certificate_shared', {
      certificate_id: certificateId,
      platform,
    });
  };

  // Feature flags
  const getFeatureFlag = (flagKey: string) => {
    return posthog.getFeatureFlag(flagKey);
  };

  const isFeatureEnabled = (flagKey: string) => {
    return posthog.isFeatureEnabled(flagKey);
  };

  return {
    identifyUser,
    trackCourseViewed,
    trackCheckoutStarted,
    trackCheckoutCompleted,
    trackSurveyCompleted,
    trackRecordingViewed,
    trackKitDownloaded,
    trackOfficeHoursBooked,
    trackChatbotMessage,
    trackCertificateShared,
    getFeatureFlag,
    isFeatureEnabled,
  };
}
```

### Reverse Proxy Configuration (Ad-Blocker Bypass)

```typescript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  async rewrites() {
    return [
      {
        source: '/ingest/:path*',
        destination: 'https://analytics.aienablement.academy/:path*',
      },
    ];
  },
};

module.exports = nextConfig;
```

```typescript
// Update PostHog config to use proxy
// lib/posthog/config.ts (updated)
export const POSTHOG_CONFIG = {
  apiKey: process.env.NEXT_PUBLIC_POSTHOG_KEY!,
  apiHost: '/ingest', // Use reverse proxy
  options: {
    api_host: '/ingest',
    ui_host: 'https://analytics.aienablement.academy',
    // ... rest of config
  },
} as const;
```

---

## 4. Formbricks JS (@formbricks/js)

### Installation

```bash
pnpm add @formbricks/js
```

### Environment Configuration

```typescript
// lib/formbricks/config.ts
export const FORMBRICKS_CONFIG = {
  environmentId: process.env.NEXT_PUBLIC_FORMBRICKS_ENVIRONMENT_ID!,
  apiHost: process.env.NEXT_PUBLIC_FORMBRICKS_API_HOST || 'https://app.formbricks.com',
} as const;

if (!FORMBRICKS_CONFIG.environmentId) {
  throw new Error('NEXT_PUBLIC_FORMBRICKS_ENVIRONMENT_ID is not defined');
}
```

### Next.js Initialization

```typescript
// components/providers/formbricks-provider.tsx
'use client';

import { useEffect } from 'react';
import formbricks from '@formbricks/js';
import { useUser } from '@clerk/nextjs';
import { FORMBRICKS_CONFIG } from '@/lib/formbricks/config';

export function FormbricksProvider({ children }: { children: React.ReactNode }) {
  const { user, isLoaded } = useUser();

  useEffect(() => {
    if (typeof window !== 'undefined') {
      formbricks.init({
        environmentId: FORMBRICKS_CONFIG.environmentId,
        apiHost: FORMBRICKS_CONFIG.apiHost,
        debug: process.env.NODE_ENV === 'development',
      });
    }
  }, []);

  useEffect(() => {
    if (isLoaded && user) {
      formbricks.setUserId(user.id);
      formbricks.setAttributes({
        email: user.emailAddresses[0]?.emailAddress,
        name: user.fullName || '',
      });
    }
  }, [user, isLoaded]);

  return <>{children}</>;
}
```

### Survey Trigger Patterns

```typescript
// lib/formbricks/surveys.ts
import formbricks from '@formbricks/js';

// Inline survey (embedded in page)
export function showInlineSurvey(surveyId: string, containerId: string) {
  formbricks.track('survey_viewed', {
    survey_id: surveyId,
  });

  formbricks.renderSurvey(surveyId, containerId);
}

// Popup survey (modal overlay)
export function showPopupSurvey(surveyId: string) {
  formbricks.track('survey_triggered', {
    survey_id: surveyId,
  });

  // Survey shows automatically based on Formbricks targeting rules
}

// Track custom events for survey targeting
export function trackEnrollmentComplete(courseId: string, variantType: string) {
  formbricks.track('enrollment_complete', {
    course_id: courseId,
    variant_type: variantType,
  });
}

export function trackSessionComplete(sessionId: string, sessionNumber: number) {
  formbricks.track('session_complete', {
    session_id: sessionId,
    session_number: sessionNumber,
  });
}

// Set user attributes for targeting
export function updateUserAttributes(attributes: {
  enrollmentDate?: string;
  cohortId?: string;
  courseProgress?: number;
  lastActiveDate?: string;
}) {
  formbricks.setAttributes(attributes);
}
```

### Integration with Enrollment Flow

```typescript
// components/enrollment/intake-survey.tsx
'use client';

import { useEffect } from 'react';
import formbricks from '@formbricks/js';
import { trackEnrollmentComplete } from '@/lib/formbricks/surveys';

interface IntakeSurveyProps {
  courseId: string;
  variantType: string;
  onComplete?: () => void;
}

export function IntakeSurvey({ courseId, variantType, onComplete }: IntakeSurveyProps) {
  useEffect(() => {
    // Track enrollment to trigger intake survey
    trackEnrollmentComplete(courseId, variantType);

    // Listen for survey completion
    const handleSurveyComplete = (event: CustomEvent) => {
      if (event.detail.surveyId === 'intake_survey') {
        onComplete?.();
      }
    };

    window.addEventListener('formbricksSurveyCompleted', handleSurveyComplete as EventListener);

    return () => {
      window.removeEventListener('formbricksSurveyCompleted', handleSurveyComplete as EventListener);
    };
  }, [courseId, variantType, onComplete]);

  return (
    <div className="max-w-2xl mx-auto py-8">
      <h2 className="text-2xl font-bold mb-4">Before We Start</h2>
      <p className="text-gray-600 mb-6">
        Help us tailor your learning experience by answering a few quick questions.
      </p>
      <div id="intake-survey-container" className="min-h-[400px]" />
    </div>
  );
}
```

### Webhook Handling

```typescript
// app/api/webhooks/formbricks/route.ts
import { headers } from 'next/headers';
import crypto from 'crypto';

const WEBHOOK_SECRET = process.env.FORMBRICKS_WEBHOOK_SECRET!;

interface FormbricksWebhookPayload {
  event: 'response.created' | 'response.updated' | 'response.finished';
  data: {
    id: string;
    surveyId: string;
    personId: string;
    response: Record<string, any>;
    createdAt: string;
    updatedAt: string;
    finished: boolean;
  };
}

export async function POST(req: Request) {
  const body = await req.text();
  const signature = headers().get('x-formbricks-signature');

  if (!signature) {
    return new Response('No signature provided', { status: 400 });
  }

  // Verify webhook signature
  const expectedSignature = crypto
    .createHmac('sha256', WEBHOOK_SECRET)
    .update(body)
    .digest('hex');

  if (signature !== expectedSignature) {
    return new Response('Invalid signature', { status: 401 });
  }

  const payload: FormbricksWebhookPayload = JSON.parse(body);

  try {
    if (payload.event === 'response.finished') {
      // Store survey response in Convex
      await fetch(`${process.env.CONVEX_SITE_URL}/api/storeSurveyResponse`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          surveyId: payload.data.surveyId,
          userId: payload.data.personId,
          responses: payload.data.response,
          completedAt: payload.data.updatedAt,
        }),
      });
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 });
  } catch (error) {
    console.error('Formbricks webhook error:', error);
    return new Response(
      `Webhook error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      { status: 500 }
    );
  }
}
```

---

## 5. Cal.com Integration

### Embed Component Setup

```typescript
// components/office-hours/cal-embed.tsx
'use client';

import { useEffect } from 'react';
import { useUser } from '@clerk/nextjs';
import Cal, { getCalApi } from '@calcom/embed-react';

interface CalEmbedProps {
  calLink: string; // e.g., "team/ai-enablement-academy/office-hours"
  onBookingComplete?: (bookingUid: string) => void;
}

export function CalEmbed({ calLink, onBookingComplete }: CalEmbedProps) {
  const { user } = useUser();

  useEffect(() => {
    (async function () {
      const cal = await getCalApi();

      // Pre-fill user data
      if (user) {
        cal('ui', {
          styles: { branding: { brandColor: '#000000' } },
          hideEventTypeDetails: false,
          layout: 'month_view',
        });

        cal('on', {
          action: 'bookingSuccessful',
          callback: (e) => {
            onBookingComplete?.(e.detail.data.uid);
          },
        });
      }
    })();
  }, [user, onBookingComplete]);

  return (
    <Cal
      calLink={calLink}
      style={{ width: '100%', height: '100%', overflow: 'scroll' }}
      config={{
        name: user?.fullName || '',
        email: user?.emailAddresses[0]?.emailAddress || '',
        theme: 'light',
      }}
    />
  );
}
```

### Webhook Handling

```typescript
// app/api/webhooks/cal/route.ts
import { headers } from 'next/headers';
import crypto from 'crypto';
import { internal } from '@/convex/_generated/api';
import { fetchMutation } from 'convex/nextjs';

const WEBHOOK_SECRET = process.env.CAL_WEBHOOK_SECRET!;

interface CalWebhookPayload {
  triggerEvent: 'BOOKING_CREATED' | 'BOOKING_CANCELLED' | 'MEETING_ENDED' | 'BOOKING_RESCHEDULED';
  payload: {
    uid: string;
    title: string;
    startTime: string;
    endTime: string;
    attendees: Array<{
      email: string;
      name: string;
      timeZone: string;
    }>;
    organizer: {
      email: string;
      name: string;
      timeZone: string;
    };
    metadata: Record<string, any>;
  };
}

function verifyWebhookSignature(body: string, signature: string | null): boolean {
  if (!signature) return false;

  const expectedSignature = crypto
    .createHmac('sha256', WEBHOOK_SECRET)
    .update(body)
    .digest('hex');

  return crypto.timingSafeEqual(
    Buffer.from(signature),
    Buffer.from(expectedSignature)
  );
}

export async function POST(req: Request) {
  const body = await req.text();
  const signature = headers().get('x-cal-signature-256');

  if (!verifyWebhookSignature(body, signature)) {
    return new Response('Invalid signature', { status: 401 });
  }

  const payload: CalWebhookPayload = JSON.parse(body);

  try {
    switch (payload.triggerEvent) {
      case 'BOOKING_CREATED':
        await fetchMutation(internal.bookings.createBooking, {
          uid: payload.payload.uid,
          title: payload.payload.title,
          startTime: payload.payload.startTime,
          endTime: payload.payload.endTime,
          attendeeEmail: payload.payload.attendees[0]?.email,
          attendeeName: payload.payload.attendees[0]?.name,
          metadata: payload.payload.metadata,
        });
        break;

      case 'BOOKING_CANCELLED':
        await fetchMutation(internal.bookings.cancelBooking, {
          uid: payload.payload.uid,
        });
        break;

      case 'MEETING_ENDED':
        await fetchMutation(internal.bookings.markBookingCompleted, {
          uid: payload.payload.uid,
        });
        break;

      case 'BOOKING_RESCHEDULED':
        await fetchMutation(internal.bookings.rescheduleBooking, {
          uid: payload.payload.uid,
          newStartTime: payload.payload.startTime,
          newEndTime: payload.payload.endTime,
        });
        break;
    }

    return new Response(JSON.stringify({ received: true }), { status: 200 });
  } catch (error) {
    console.error('Cal.com webhook error:', error);
    return new Response(
      `Webhook error: ${error instanceof Error ? error.message : 'Unknown error'}`,
      { status: 500 }
    );
  }
}
```

### Booking Record Creation in Convex

```typescript
// convex/bookings.ts
import { v } from 'convex/values';
import { internalMutation } from './_generated/server';

export const createBooking = internalMutation({
  args: {
    uid: v.string(),
    title: v.string(),
    startTime: v.string(),
    endTime: v.string(),
    attendeeEmail: v.string(),
    attendeeName: v.string(),
    metadata: v.optional(v.any()),
  },
  handler: async (ctx, args) => {
    // Find user by email
    const user = await ctx.db
      .query('users')
      .withIndex('by_email', (q) => q.eq('email', args.attendeeEmail))
      .first();

    if (!user) {
      throw new Error('User not found');
    }

    // Create booking record
    const bookingId = await ctx.db.insert('bookings', {
      calUid: args.uid,
      userId: user._id,
      title: args.title,
      startTime: new Date(args.startTime).getTime(),
      endTime: new Date(args.endTime).getTime(),
      status: 'confirmed',
      metadata: args.metadata || {},
      createdAt: Date.now(),
    });

    return bookingId;
  },
});

export const cancelBooking = internalMutation({
  args: { uid: v.string() },
  handler: async (ctx, args) => {
    const booking = await ctx.db
      .query('bookings')
      .withIndex('by_cal_uid', (q) => q.eq('calUid', args.uid))
      .first();

    if (!booking) {
      throw new Error('Booking not found');
    }

    await ctx.db.patch(booking._id, {
      status: 'cancelled',
      cancelledAt: Date.now(),
    });
  },
});

export const markBookingCompleted = internalMutation({
  args: { uid: v.string() },
  handler: async (ctx, args) => {
    const booking = await ctx.db
      .query('bookings')
      .withIndex('by_cal_uid', (q) => q.eq('calUid', args.uid))
      .first();

    if (!booking) {
      throw new Error('Booking not found');
    }

    await ctx.db.patch(booking._id, {
      status: 'completed',
      completedAt: Date.now(),
    });
  },
});
```

---

## 6. OpenRouter SDK (@openrouter/sdk)

### Installation

```bash
pnpm add openai # OpenRouter uses OpenAI SDK format
```

### Client Initialization

```typescript
// lib/openrouter/config.ts
import OpenAI from 'openai';

if (!process.env.OPENROUTER_API_KEY) {
  throw new Error('OPENROUTER_API_KEY is not defined');
}

export const openrouter = new OpenAI({
  apiKey: process.env.OPENROUTER_API_KEY,
  baseURL: 'https://openrouter.ai/api/v1',
  defaultHeaders: {
    'HTTP-Referer': process.env.NEXT_PUBLIC_SITE_URL || 'https://learn.aienablement.academy',
    'X-Title': 'AI Enablement Academy',
  },
});

export const AI_MODELS = {
  PRIMARY: 'openai/gpt-4o-mini',
  FALLBACK: 'anthropic/claude-3-haiku',
  ADVANCED: 'anthropic/claude-3.5-sonnet',
} as const;
```

### Chat Completions with Streaming

```typescript
// lib/openrouter/chat.ts
import { openrouter, AI_MODELS } from './config';
import type { ChatCompletionMessageParam } from 'openai/resources/chat/completions';

interface ChatOptions {
  messages: ChatCompletionMessageParam[];
  model?: string;
  temperature?: number;
  maxTokens?: number;
  stream?: boolean;
}

export async function createChatCompletion({
  messages,
  model = AI_MODELS.PRIMARY,
  temperature = 0.7,
  maxTokens = 2048,
  stream = false,
}: ChatOptions) {
  try {
    const completion = await openrouter.chat.completions.create({
      model,
      messages,
      temperature,
      max_tokens: maxTokens,
      stream,
    });

    return completion;
  } catch (error) {
    // Fallback to Claude Haiku on error
    console.warn(`Primary model ${model} failed, falling back to ${AI_MODELS.FALLBACK}`);

    try {
      const fallbackCompletion = await openrouter.chat.completions.create({
        model: AI_MODELS.FALLBACK,
        messages,
        temperature,
        max_tokens: maxTokens,
        stream,
      });

      return fallbackCompletion;
    } catch (fallbackError) {
      console.error('Fallback model also failed:', fallbackError);
      throw new Error('AI service temporarily unavailable');
    }
  }
}
```

### System Prompt Configuration

```typescript
// lib/openrouter/prompts.ts
export const SYSTEM_PROMPTS = {
  LEARNING_ASSISTANT: `You are an AI learning assistant for the AI Enablement Academy. Your role is to:
- Help students understand AI concepts and best practices
- Answer questions about course content and assignments
- Provide practical examples and real-world applications
- Encourage critical thinking and hands-on experimentation
- Direct students to relevant course materials when appropriate

Keep responses concise, actionable, and encouraging. If you don't know something, admit it and suggest where to find the answer.`,

  CODE_REVIEWER: `You are an expert code reviewer specializing in AI/ML implementations. When reviewing code:
- Check for best practices and common pitfalls
- Suggest performance improvements
- Identify security concerns
- Provide specific, actionable feedback
- Reference relevant documentation when helpful

Format feedback as: Issue → Why it matters → How to fix`,

  CAREER_ADVISOR: `You are a career advisor specializing in AI/ML careers. Help students:
- Identify relevant job opportunities and career paths
- Build portfolios and showcase projects
- Prepare for technical interviews
- Navigate the AI job market
- Develop in-demand skills

Be realistic about market conditions while remaining encouraging and supportive.`,
} as const;
```

### Edge Runtime API Route for Streaming

```typescript
// app/api/chat/route.ts
import { openrouter, AI_MODELS } from '@/lib/openrouter/config';
import { SYSTEM_PROMPTS } from '@/lib/openrouter/prompts';
import { auth } from '@clerk/nextjs';

export const runtime = 'edge';

export async function POST(req: Request) {
  const { userId } = auth();

  if (!userId) {
    return new Response('Unauthorized', { status: 401 });
  }

  const { messages, assistantType = 'LEARNING_ASSISTANT' } = await req.json();

  const systemPrompt = SYSTEM_PROMPTS[assistantType as keyof typeof SYSTEM_PROMPTS];

  try {
    const response = await openrouter.chat.completions.create({
      model: AI_MODELS.PRIMARY,
      messages: [
        { role: 'system', content: systemPrompt },
        ...messages,
      ],
      stream: true,
      temperature: 0.7,
      max_tokens: 2048,
    });

    // Create ReadableStream for streaming response
    const stream = new ReadableStream({
      async start(controller) {
        const encoder = new TextEncoder();

        try {
          for await (const chunk of response) {
            const text = chunk.choices[0]?.delta?.content || '';
            if (text) {
              controller.enqueue(encoder.encode(text));
            }
          }
        } catch (error) {
          console.error('Stream error:', error);
          controller.error(error);
        } finally {
          controller.close();
        }
      },
    });

    return new Response(stream, {
      headers: {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
      },
    });
  } catch (error) {
    console.error('Chat API error:', error);
    return new Response(
      JSON.stringify({ error: 'AI service temporarily unavailable' }),
      { status: 500, headers: { 'Content-Type': 'application/json' } }
    );
  }
}
```

### Token Counting and Usage Tracking

```typescript
// lib/openrouter/tokens.ts
import { encoding_for_model } from 'tiktoken';

const encoder = encoding_for_model('gpt-4');

export function countTokens(text: string): number {
  const tokens = encoder.encode(text);
  return tokens.length;
}

export function estimateCost(
  promptTokens: number,
  completionTokens: number,
  model: string
): number {
  // Pricing per 1M tokens (as of 2024)
  const pricing: Record<string, { input: number; output: number }> = {
    'openai/gpt-4o-mini': { input: 0.15, output: 0.60 },
    'anthropic/claude-3-haiku': { input: 0.25, output: 1.25 },
    'anthropic/claude-3.5-sonnet': { input: 3.00, output: 15.00 },
  };

  const modelPricing = pricing[model] || pricing['openai/gpt-4o-mini'];

  const inputCost = (promptTokens / 1_000_000) * modelPricing.input;
  const outputCost = (completionTokens / 1_000_000) * modelPricing.output;

  return inputCost + outputCost;
}

// Track usage in Convex
export async function trackTokenUsage(
  userId: string,
  model: string,
  promptTokens: number,
  completionTokens: number
) {
  const cost = estimateCost(promptTokens, completionTokens, model);

  await fetch(`${process.env.CONVEX_SITE_URL}/api/trackTokenUsage`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      userId,
      model,
      promptTokens,
      completionTokens,
      cost,
      timestamp: Date.now(),
    }),
  });
}
```

---

## 7. Convex

### Real-Time Subscriptions with useQuery

```typescript
// convex/courses.ts
import { query } from './_generated/server';
import { v } from 'convex/values';

export const getCourse = query({
  args: { courseId: v.id('courses') },
  handler: async (ctx, args) => {
    const course = await ctx.db.get(args.courseId);
    if (!course) throw new Error('Course not found');
    return course;
  },
});

export const listCourses = query({
  args: { status: v.optional(v.string()) },
  handler: async (ctx, args) => {
    let coursesQuery = ctx.db.query('courses');

    if (args.status) {
      coursesQuery = coursesQuery.filter((q) => q.eq(q.field('status'), args.status));
    }

    return await coursesQuery.collect();
  },
});

// Client usage
// components/courses/course-list.tsx
'use client';

import { useQuery } from 'convex/react';
import { api } from '@/convex/_generated/api';

export function CourseList() {
  const courses = useQuery(api.courses.listCourses, { status: 'published' });

  if (courses === undefined) return <div>Loading...</div>;

  return (
    <div>
      {courses.map((course) => (
        <CourseCard key={course._id} course={course} />
      ))}
    </div>
  );
}
```

### Optimistic Updates with useMutation

```typescript
// convex/enrollments.ts
import { mutation } from './_generated/server';
import { v } from 'convex/values';

export const enrollInCourse = mutation({
  args: {
    courseId: v.id('courses'),
    variantId: v.string(),
    userId: v.string(),
  },
  handler: async (ctx, args) => {
    // Check if already enrolled
    const existingEnrollment = await ctx.db
      .query('enrollments')
      .withIndex('by_user_course', (q) =>
        q.eq('userId', args.userId).eq('courseId', args.courseId)
      )
      .first();

    if (existingEnrollment) {
      throw new Error('Already enrolled in this course');
    }

    // Create enrollment
    const enrollmentId = await ctx.db.insert('enrollments', {
      userId: args.userId,
      courseId: args.courseId,
      variantId: args.variantId,
      status: 'active',
      progress: 0,
      enrolledAt: Date.now(),
    });

    return enrollmentId;
  },
});

// Client usage with optimistic updates
// components/courses/enroll-button.tsx
'use client';

import { useMutation } from 'convex/react';
import { api } from '@/convex/_generated/api';
import { useOptimisticMutation } from '@/hooks/use-optimistic-mutation';

export function EnrollButton({ courseId, variantId }: Props) {
  const enroll = useMutation(api.enrollments.enrollInCourse);

  const handleEnroll = useOptimisticMutation({
    mutation: enroll,
    args: { courseId, variantId, userId },
    optimisticUpdate: (store) => {
      // Optimistically update UI before server response
      store.setQueryData(['enrollments', userId], (old) => [
        ...old,
        { courseId, variantId, status: 'active' },
      ]);
    },
  });

  return <button onClick={handleEnroll}>Enroll Now</button>;
}
```

### HTTP Actions for Webhooks

```typescript
// convex/http.ts
import { httpRouter } from 'convex/server';
import { httpAction } from './_generated/server';
import { internal } from './_generated/api';

const http = httpRouter();

// Stripe webhook handler
http.route({
  path: '/webhooks/stripe',
  method: 'POST',
  handler: httpAction(async (ctx, request) => {
    const signature = request.headers.get('stripe-signature');
    if (!signature) {
      return new Response('No signature', { status: 400 });
    }

    const body = await request.text();

    // Verify and process webhook in internal action
    await ctx.runAction(internal.stripe.processWebhook, {
      body,
      signature,
    });

    return new Response(JSON.stringify({ received: true }), {
      status: 200,
      headers: { 'Content-Type': 'application/json' },
    });
  }),
});

export default http;
```

### Scheduled Jobs (Crons)

```typescript
// convex/crons.ts
import { cronJobs } from 'convex/server';
import { internal } from './_generated/api';

const crons = cronJobs();

// Send cohort reminders daily at 9 AM UTC
crons.daily(
  'send cohort reminders',
  { hourUTC: 9, minuteUTC: 0 },
  internal.emails.sendCohortReminders
);

// Clean up expired sessions every hour
crons.hourly(
  'cleanup expired sessions',
  { minuteUTC: 0 },
  internal.sessions.cleanupExpired
);

// Generate weekly analytics report every Monday at 8 AM UTC
crons.weekly(
  'weekly analytics report',
  { dayOfWeek: 'monday', hourUTC: 8, minuteUTC: 0 },
  internal.analytics.generateWeeklyReport
);

// Archive completed cohorts monthly
crons.monthly(
  'archive completed cohorts',
  { day: 1, hourUTC: 2, minuteUTC: 0 },
  internal.cohorts.archiveCompleted
);

export default crons;
```

### File Storage Patterns

```typescript
// convex/files.ts
import { mutation, query } from './_generated/server';
import { v } from 'convex/values';

export const generateUploadUrl = mutation({
  handler: async (ctx) => {
    return await ctx.storage.generateUploadUrl();
  },
});

export const saveFile = mutation({
  args: {
    storageId: v.string(),
    fileName: v.string(),
    fileType: v.string(),
    fileSize: v.number(),
    userId: v.string(),
  },
  handler: async (ctx, args) => {
    const fileId = await ctx.db.insert('files', {
      storageId: args.storageId,
      fileName: args.fileName,
      fileType: args.fileType,
      fileSize: args.fileSize,
      uploadedBy: args.userId,
      uploadedAt: Date.now(),
    });

    return fileId;
  },
});

export const getFileUrl = query({
  args: { storageId: v.string() },
  handler: async (ctx, args) => {
    return await ctx.storage.getUrl(args.storageId);
  },
});

// Client usage
// components/upload/file-uploader.tsx
'use client';

import { useMutation } from 'convex/react';
import { api } from '@/convex/_generated/api';

export function FileUploader() {
  const generateUploadUrl = useMutation(api.files.generateUploadUrl);
  const saveFile = useMutation(api.files.saveFile);

  const handleUpload = async (file: File) => {
    // Get upload URL
    const uploadUrl = await generateUploadUrl();

    // Upload file to Convex storage
    const response = await fetch(uploadUrl, {
      method: 'POST',
      body: file,
    });

    const { storageId } = await response.json();

    // Save file metadata
    await saveFile({
      storageId,
      fileName: file.name,
      fileType: file.type,
      fileSize: file.size,
      userId,
    });
  };

  return <input type="file" onChange={(e) => handleUpload(e.target.files[0])} />;
}
```

### Auth Integration

```typescript
// convex/auth.ts
import { query } from './_generated/server';
import { v } from 'convex/values';

export const getCurrentUser = query({
  args: {},
  handler: async (ctx) => {
    const identity = await ctx.auth.getUserIdentity();
    if (!identity) return null;

    // Find or create user
    const user = await ctx.db
      .query('users')
      .withIndex('by_clerk_id', (q) => q.eq('clerkId', identity.subject))
      .first();

    if (!user) {
      // Create user on first login
      const userId = await ctx.db.insert('users', {
        clerkId: identity.subject,
        email: identity.email!,
        name: identity.name || '',
        createdAt: Date.now(),
      });

      return await ctx.db.get(userId);
    }

    return user;
  },
});

// Require authentication wrapper
export const requireAuth = async (ctx: any) => {
  const identity = await ctx.auth.getUserIdentity();
  if (!identity) {
    throw new Error('Unauthorized');
  }
  return identity;
};
```

---

## 8. Vercel SDK

### Deployment Configuration

```typescript
// vercel.json
{
  "buildCommand": "pnpm build",
  "devCommand": "pnpm dev",
  "installCommand": "pnpm install",
  "framework": "nextjs",
  "regions": ["iad1"],
  "functions": {
    "app/api/**/*.ts": {
      "maxDuration": 30
    },
    "app/api/chat/route.ts": {
      "runtime": "edge"
    }
  },
  "headers": [
    {
      "source": "/(.*)",
      "headers": [
        {
          "key": "X-Frame-Options",
          "value": "DENY"
        },
        {
          "key": "X-Content-Type-Options",
          "value": "nosniff"
        },
        {
          "key": "Referrer-Policy",
          "value": "strict-origin-when-cross-origin"
        }
      ]
    }
  ],
  "redirects": [
    {
      "source": "/docs",
      "destination": "https://cortex.aienablement.academy",
      "permanent": true
    }
  ],
  "rewrites": [
    {
      "source": "/ingest/:path*",
      "destination": "https://analytics.aienablement.academy/:path*"
    }
  ]
}
```

### Environment Variables Management

```typescript
// .env.local (development)
# Clerk
NEXT_PUBLIC_CLERK_PUBLISHABLE_KEY=pk_test_...
CLERK_SECRET_KEY=sk_test_...
NEXT_PUBLIC_CLERK_SIGN_IN_URL=/sign-in
NEXT_PUBLIC_CLERK_SIGN_UP_URL=/sign-up
NEXT_PUBLIC_CLERK_AFTER_SIGN_IN_URL=/dashboard
NEXT_PUBLIC_CLERK_AFTER_SIGN_UP_URL=/onboarding

# Convex
NEXT_PUBLIC_CONVEX_URL=https://...convex.cloud
CONVEX_DEPLOY_KEY=...

# Stripe
NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY=pk_test_...
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...

# Brevo
BREVO_API_KEY=...

# PostHog
NEXT_PUBLIC_POSTHOG_KEY=phc_...

# Formbricks
NEXT_PUBLIC_FORMBRICKS_ENVIRONMENT_ID=...

# OpenRouter
OPENROUTER_API_KEY=sk-or-...

# Cal.com
CAL_WEBHOOK_SECRET=...

# Site
NEXT_PUBLIC_SITE_URL=http://localhost:3000
```

### next.config.js Setup

```typescript
// next.config.js
/** @type {import('next').NextConfig} */
const nextConfig = {
  reactStrictMode: true,
  swcMinify: true,

  // Image optimization
  images: {
    remotePatterns: [
      {
        protocol: 'https',
        hostname: 'img.clerk.com',
      },
      {
        protocol: 'https',
        hostname: '*.convex.cloud',
      },
    ],
  },

  // Reverse proxy for PostHog (bypass ad blockers)
  async rewrites() {
    return [
      {
        source: '/ingest/:path*',
        destination: 'https://analytics.aienablement.academy/:path*',
      },
    ];
  },

  // Security headers
  async headers() {
    return [
      {
        source: '/(.*)',
        headers: [
          {
            key: 'X-Frame-Options',
            value: 'DENY',
          },
          {
            key: 'X-Content-Type-Options',
            value: 'nosniff',
          },
          {
            key: 'Referrer-Policy',
            value: 'strict-origin-when-cross-origin',
          },
          {
            key: 'Permissions-Policy',
            value: 'camera=(), microphone=(), geolocation=()',
          },
        ],
      },
    ];
  },

  // Redirects
  async redirects() {
    return [
      {
        source: '/docs',
        destination: 'https://cortex.aienablement.academy',
        permanent: true,
      },
      {
        source: '/learn',
        destination: '/dashboard',
        permanent: false,
      },
    ];
  },

  // Environment variables validation
  env: {
    NEXT_PUBLIC_SITE_URL: process.env.NEXT_PUBLIC_SITE_URL || 'http://localhost:3000',
  },

  // TypeScript and ESLint
  typescript: {
    ignoreBuildErrors: false,
  },
  eslint: {
    ignoreDuringBuilds: false,
  },
};

module.exports = nextConfig;
```

### Build and Deploy Scripts

```json
// package.json
{
  "scripts": {
    "dev": "next dev",
    "build": "pnpm convex:deploy && next build",
    "start": "next start",
    "lint": "next lint",
    "type-check": "tsc --noEmit",
    "convex:dev": "convex dev",
    "convex:deploy": "convex deploy --cmd 'pnpm build'",
    "vercel:dev": "vercel dev",
    "vercel:deploy": "vercel --prod"
  }
}
```

### SDK Usage (Programmatic Management)

```typescript
// lib/vercel.ts
import { Vercel } from "@vercel/sdk";

const vercel = new Vercel({
  bearerToken: process.env.VERCEL_TOKEN,
});

export const PROJECT_ID = process.env.VERCEL_PROJECT_ID!;
export const TEAM_ID = process.env.VERCEL_TEAM_ID;
```

### Deployment Management

```typescript
// lib/vercel-deployments.ts
export async function getDeployments(limit = 10) {
  const response = await vercel.deployments.listDeployments({
    projectId: PROJECT_ID,
    teamId: TEAM_ID,
    limit,
  });
  return response.deployments;
}

export async function getDeploymentById(deploymentId: string) {
  return await vercel.deployments.getDeployment({
    idOrUrl: deploymentId,
    teamId: TEAM_ID,
  });
}

export async function cancelDeployment(deploymentId: string) {
  await vercel.deployments.cancelDeployment({
    id: deploymentId,
    teamId: TEAM_ID,
  });
  return { success: true };
}
```

### Domain Management

```typescript
// lib/vercel-domains.ts
export async function addDomain(domain: string) {
  await vercel.domains.createDomain({ name: domain, teamId: TEAM_ID });
  await vercel.projects.addProjectDomain({
    idOrName: PROJECT_ID,
    teamId: TEAM_ID,
    requestBody: { name: domain },
  });
}

export async function getDomains() {
  const response = await vercel.domains.listDomains({ teamId: TEAM_ID });
  return response.domains;
}

export async function verifyDomain(domain: string) {
  return await vercel.domains.verifyDomain({ domain, teamId: TEAM_ID });
}
```

### Error Handling

```typescript
export function handleVercelError(error: any) {
  if (error.statusCode === 401) return { message: "Invalid Vercel token", statusCode: 401 };
  if (error.statusCode === 403) return { message: "Insufficient permissions", statusCode: 403 };
  if (error.statusCode === 429) return { message: "Rate limit exceeded", statusCode: 429 };
  return { message: error.message || "Vercel API error", statusCode: error.statusCode || 500 };
}
```

---

## Summary

This specification provides complete, production-ready SDK integration patterns for:

1. **Stripe** - Payments, invoicing, refunds, webhook handling
2. **Brevo** - Transactional emails, contact management, templates
3. **PostHog** - Analytics, feature flags, self-hosted configuration
4. **Formbricks** - Surveys, user feedback, enrollment flow integration
5. **Cal.com** - Office hours booking, webhook handling
6. **OpenRouter** - AI chatbot, streaming responses, token tracking
7. **Convex** - Real-time database, auth, file storage, webhooks, crons
8. **Vercel** - Deployment, environment variables, security headers

All examples include:
- Complete TypeScript types
- Error handling patterns
- Security best practices
- Real-world usage examples
- Performance optimizations
## 9. BlockNote Editor (@blocknote/react, @blocknote/mantine)

### Installation

```bash
pnpm add @blocknote/core @blocknote/react @blocknote/mantine @convex-dev/prosemirror-sync
pnpm add -D @mantine/core @mantine/hooks
```

### Configuration

```typescript
// lib/blocknote/config.ts
import { BlockNoteSchema, defaultBlockSpecs, defaultInlineContentSpecs, defaultStyleSpecs } from '@blocknote/core';
import { calloutBlock } from './blocks/callout';
import { codeBlock } from './blocks/code-block';
import { videoEmbedBlock } from './blocks/video-embed';

// Custom schema with additional blocks
export const schema = BlockNoteSchema.create({
  blockSpecs: {
    ...defaultBlockSpecs,
    callout: calloutBlock,
    codeBlock: codeBlock,
    videoEmbed: videoEmbedBlock,
  },
  inlineContentSpecs: defaultInlineContentSpecs,
  styleSpecs: defaultStyleSpecs,
});

export type CustomSchema = typeof schema;

// Theme configuration
export const BLOCKNOTE_THEME = {
  colors: {
    editor: {
      text: 'hsl(var(--foreground))',
      background: 'hsl(var(--background))',
    },
    menu: {
      text: 'hsl(var(--foreground))',
      background: 'hsl(var(--popover))',
    },
    tooltip: {
      text: 'hsl(var(--popover-foreground))',
      background: 'hsl(var(--popover))',
    },
    hovered: {
      text: 'hsl(var(--accent-foreground))',
      background: 'hsl(var(--accent))',
    },
    selected: {
      text: 'hsl(var(--primary-foreground))',
      background: 'hsl(var(--primary))',
    },
    disabled: {
      text: 'hsl(var(--muted-foreground))',
      background: 'hsl(var(--muted))',
    },
    shadow: 'hsl(var(--shadow))',
    border: 'hsl(var(--border))',
    sideMenu: 'hsl(var(--muted-foreground))',
    highlights: {
      gray: { text: '#9b9a97', background: '#ebeced' },
      brown: { text: '#64473a', background: '#e9e5e3' },
      red: { text: '#e03e3e', background: '#fbe4e4' },
      orange: { text: '#d9730d', background: '#f6e9d9' },
      yellow: { text: '#dfab01', background: '#fbf3db' },
      green: { text: '#4d6461', background: '#ddedea' },
      blue: { text: '#0b6e99', background: '#ddebf1' },
      purple: { text: '#6940a5', background: '#e8deee' },
      pink: { text: '#ad1a72', background: '#f5e0e9' },
    },
  },
  borderRadius: 4,
  fontFamily: 'var(--font-sans)',
} as const;
```

### Custom Block Types

```typescript
// lib/blocknote/blocks/callout.ts
import { defaultProps } from '@blocknote/core';
import { createReactBlockSpec } from '@blocknote/react';
import { AlertCircle, AlertTriangle, Info, Lightbulb } from 'lucide-react';

export const calloutBlock = createReactBlockSpec(
  {
    type: 'callout',
    propSchema: {
      ...defaultProps,
      variant: {
        default: 'info',
        values: ['info', 'warning', 'danger', 'tip'] as const,
      },
    },
    content: 'inline',
  },
  {
    render: (props) => {
      const icons = {
        info: Info,
        warning: AlertTriangle,
        danger: AlertCircle,
        tip: Lightbulb,
      };

      const Icon = icons[props.block.props.variant];

      return (
        <div
          className={cn(
            'flex gap-3 rounded-lg border p-4',
            {
              'border-blue-200 bg-blue-50': props.block.props.variant === 'info',
              'border-yellow-200 bg-yellow-50': props.block.props.variant === 'warning',
              'border-red-200 bg-red-50': props.block.props.variant === 'danger',
              'border-green-200 bg-green-50': props.block.props.variant === 'tip',
            }
          )}
        >
          <Icon className="h-5 w-5 flex-shrink-0 mt-0.5" />
          <div className="flex-1">
            <props.contentRef />
          </div>
        </div>
      );
    },
  }
);

// lib/blocknote/blocks/code-block.ts
import { defaultProps } from '@blocknote/core';
import { createReactBlockSpec } from '@blocknote/react';
import { Highlight, themes } from 'prism-react-renderer';

export const codeBlock = createReactBlockSpec(
  {
    type: 'codeBlock',
    propSchema: {
      ...defaultProps,
      language: {
        default: 'typescript',
        values: ['typescript', 'javascript', 'python', 'bash', 'json', 'sql'] as const,
      },
    },
    content: 'inline',
  },
  {
    render: (props) => {
      const code = props.block.content.map((c) => c.text).join('');

      return (
        <div className="rounded-lg border bg-zinc-950 p-4">
          <div className="mb-2 flex items-center justify-between">
            <span className="text-xs text-zinc-400">{props.block.props.language}</span>
            <button
              onClick={() => navigator.clipboard.writeText(code)}
              className="text-xs text-zinc-400 hover:text-zinc-200"
            >
              Copy
            </button>
          </div>
          <Highlight theme={themes.nightOwl} code={code} language={props.block.props.language}>
            {({ tokens, getLineProps, getTokenProps }) => (
              <pre className="overflow-x-auto">
                {tokens.map((line, i) => (
                  <div key={i} {...getLineProps({ line })}>
                    {line.map((token, key) => (
                      <span key={key} {...getTokenProps({ token })} />
                    ))}
                  </div>
                ))}
              </pre>
            )}
          </Highlight>
        </div>
      );
    },
  }
);

// lib/blocknote/blocks/video-embed.ts
import { defaultProps } from '@blocknote/core';
import { createReactBlockSpec } from '@blocknote/react';

export const videoEmbedBlock = createReactBlockSpec(
  {
    type: 'videoEmbed',
    propSchema: {
      ...defaultProps,
      url: { default: '' },
      caption: { default: '' },
    },
    content: 'none',
  },
  {
    render: (props) => {
      const embedUrl = getEmbedUrl(props.block.props.url);

      return (
        <div className="space-y-2">
          <div className="relative aspect-video overflow-hidden rounded-lg border">
            {embedUrl ? (
              <iframe
                src={embedUrl}
                className="h-full w-full"
                allow="accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture"
                allowFullScreen
              />
            ) : (
              <div className="flex h-full items-center justify-center bg-muted">
                <p className="text-sm text-muted-foreground">Invalid video URL</p>
              </div>
            )}
          </div>
          {props.block.props.caption && (
            <p className="text-center text-sm text-muted-foreground">
              {props.block.props.caption}
            </p>
          )}
        </div>
      );
    },
  }
);

function getEmbedUrl(url: string): string | null {
  // YouTube
  const youtubeMatch = url.match(/(?:youtube\.com\/watch\?v=|youtu\.be\/)([^&\s]+)/);
  if (youtubeMatch) return `https://www.youtube.com/embed/${youtubeMatch[1]}`;

  // Vimeo
  const vimeoMatch = url.match(/vimeo\.com\/(\d+)/);
  if (vimeoMatch) return `https://player.vimeo.com/video/${vimeoMatch[1]}`;

  // Loom
  const loomMatch = url.match(/loom\.com\/share\/([a-zA-Z0-9]+)/);
  if (loomMatch) return `https://www.loom.com/embed/${loomMatch[1]}`;

  return null;
}
```

### Convex Real-Time Sync Integration

```typescript
// components/editor/blocknote-editor.tsx
'use client';

import { useCreateBlockNote } from '@blocknote/react';
import { BlockNoteView } from '@blocknote/mantine';
import '@blocknote/mantine/style.css';
import '@blocknote/core/fonts/inter.css';
import { useBlockNoteSync } from '@/hooks/use-blocknote-sync';
import { schema, BLOCKNOTE_THEME } from '@/lib/blocknote/config';
import { slashMenuItems } from '@/lib/blocknote/slash-menu';
import { uploadToConvex } from '@/lib/convex-storage';

interface BlockNoteEditorProps {
  documentId: string;
  editable?: boolean;
  className?: string;
}

export function BlockNoteEditor({ documentId, editable = true, className }: BlockNoteEditorProps) {
  const editor = useCreateBlockNote({
    schema,
    uploadFile: uploadToConvex,
  });

  // Real-time sync with Convex
  const { isLoading, error } = useBlockNoteSync({
    editor,
    documentId,
  });

  if (isLoading) {
    return (
      <div className="flex h-[400px] items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    );
  }

  if (error) {
    return (
      <div className="flex h-[400px] items-center justify-center">
        <p className="text-destructive">Failed to load editor: {error.message}</p>
      </div>
    );
  }

  return (
    <BlockNoteView
      editor={editor}
      editable={editable}
      theme={BLOCKNOTE_THEME}
      slashMenu={slashMenuItems}
      className={className}
    />
  );
}
```

### Real-Time Sync Hook

```typescript
// hooks/use-blocknote-sync.ts
import { useEffect, useState } from 'react';
import { BlockNoteEditor } from '@blocknote/core';
import { useQuery, useMutation } from 'convex/react';
import { api } from '@/convex/_generated/api';
import { Id } from '@/convex/_generated/dataModel';
import type { CustomSchema } from '@/lib/blocknote/config';

interface UseBlockNoteSyncOptions {
  editor: BlockNoteEditor<CustomSchema> | null;
  documentId: string;
}

export function useBlockNoteSync({ editor, documentId }: UseBlockNoteSyncOptions) {
  const [isLoading, setIsLoading] = useState(true);
  const [error, setError] = useState<Error | null>(null);

  // Get document from Convex
  const document = useQuery(api.documents.getDocument, {
    documentId: documentId as Id<'documents'>,
  });

  // Save changes to Convex
  const updateDocument = useMutation(api.documents.updateDocument);

  // Load initial content
  useEffect(() => {
    if (!editor || !document) return;

    try {
      const blocks = document.content || [];
      editor.replaceBlocks(editor.document, blocks);
      setIsLoading(false);
    } catch (err) {
      setError(err instanceof Error ? err : new Error('Failed to load document'));
      setIsLoading(false);
    }
  }, [editor, document]);

  // Auto-save on changes (debounced)
  useEffect(() => {
    if (!editor || isLoading) return;

    let timeoutId: NodeJS.Timeout;

    const handleChange = () => {
      clearTimeout(timeoutId);
      timeoutId = setTimeout(async () => {
        try {
          const blocks = editor.document;
          await updateDocument({
            documentId: documentId as Id<'documents'>,
            content: blocks,
          });
        } catch (err) {
          console.error('Failed to save document:', err);
        }
      }, 1000); // Debounce 1 second
    };

    editor.onChange(handleChange);

    return () => {
      clearTimeout(timeoutId);
    };
  }, [editor, documentId, updateDocument, isLoading]);

  return { isLoading, error };
}
```

### Image Upload to Convex Storage

```typescript
// lib/convex-storage.ts
import { api } from '@/convex/_generated/api';
import { fetchMutation } from 'convex/nextjs';

export async function uploadToConvex(file: File): Promise<string> {
  try {
    // Generate upload URL
    const uploadUrl = await fetchMutation(api.storage.generateUploadUrl);

    // Upload file
    const response = await fetch(uploadUrl, {
      method: 'POST',
      headers: { 'Content-Type': file.type },
      body: file,
    });

    if (!response.ok) {
      throw new Error('Upload failed');
    }

    const { storageId } = await response.json();

    // Save file metadata
    await fetchMutation(api.storage.saveFile, {
      storageId,
      fileName: file.name,
      fileType: file.type,
      fileSize: file.size,
    });

    // Return URL for BlockNote
    const fileUrl = await fetchMutation(api.storage.getFileUrl, { storageId });
    return fileUrl;
  } catch (error) {
    console.error('File upload error:', error);
    throw new Error('Failed to upload file');
  }
}
```

### Slash Menu Configuration

```typescript
// lib/blocknote/slash-menu.ts
import {
  BlockTypeSelectItem,
  getDefaultSlashMenuItems,
} from '@blocknote/core';

export const slashMenuItems = [
  ...getDefaultSlashMenuItems(),
  {
    name: 'Callout',
    execute: (editor) => {
      editor.insertBlocks(
        [
          {
            type: 'callout',
            props: { variant: 'info' },
            content: [{ type: 'text', text: 'Enter your callout text...' }],
          },
        ],
        editor.getTextCursorPosition().block,
        'after'
      );
    },
    aliases: ['callout', 'note', 'info'],
    group: 'Basic blocks',
  },
  {
    name: 'Code Block',
    execute: (editor) => {
      editor.insertBlocks(
        [
          {
            type: 'codeBlock',
            props: { language: 'typescript' },
            content: [{ type: 'text', text: '// Your code here' }],
          },
        ],
        editor.getTextCursorPosition().block,
        'after'
      );
    },
    aliases: ['code', 'snippet'],
    group: 'Basic blocks',
  },
  {
    name: 'Video Embed',
    execute: (editor) => {
      const url = prompt('Enter video URL (YouTube, Vimeo, or Loom):');
      if (url) {
        editor.insertBlocks(
          [
            {
              type: 'videoEmbed',
              props: { url },
            },
          ],
          editor.getTextCursorPosition().block,
          'after'
        );
      }
    },
    aliases: ['video', 'youtube', 'vimeo', 'loom'],
    group: 'Media',
  },
] as BlockTypeSelectItem[];
```

### Markdown Import/Export

```typescript
// lib/blocknote/markdown.ts
import { BlockNoteEditor } from '@blocknote/core';
import type { CustomSchema } from './config';

export async function importMarkdown(
  editor: BlockNoteEditor<CustomSchema>,
  markdown: string
): Promise<void> {
  const blocks = await editor.tryParseMarkdownToBlocks(markdown);
  editor.replaceBlocks(editor.document, blocks);
}

export async function exportMarkdown(
  editor: BlockNoteEditor<CustomSchema>
): Promise<string> {
  return await editor.blocksToMarkdownLossy(editor.document);
}

// Usage in component
export function MarkdownTools({ editor }: { editor: BlockNoteEditor<CustomSchema> }) {
  const handleImport = async () => {
    const markdown = prompt('Paste markdown content:');
    if (markdown) {
      await importMarkdown(editor, markdown);
    }
  };

  const handleExport = async () => {
    const markdown = await exportMarkdown(editor);
    navigator.clipboard.writeText(markdown);
    alert('Markdown copied to clipboard!');
  };

  return (
    <div className="flex gap-2">
      <button onClick={handleImport} className="text-sm">Import Markdown</button>
      <button onClick={handleExport} className="text-sm">Export Markdown</button>
    </div>
  );
}
```

### Error Handling

```typescript
// lib/blocknote/errors.ts
export class BlockNoteError extends Error {
  constructor(
    message: string,
    public code: 'LOAD_FAILED' | 'SAVE_FAILED' | 'SYNC_FAILED' | 'UPLOAD_FAILED'
  ) {
    super(message);
    this.name = 'BlockNoteError';
  }
}

export function handleEditorError(error: unknown): never {
  if (error instanceof BlockNoteError) {
    switch (error.code) {
      case 'LOAD_FAILED':
        throw new Error('Failed to load document. Please refresh the page.');
      case 'SAVE_FAILED':
        throw new Error('Failed to save changes. Your work may not be saved.');
      case 'SYNC_FAILED':
        throw new Error('Real-time sync interrupted. Reconnecting...');
      case 'UPLOAD_FAILED':
        throw new Error('File upload failed. Please try again.');
    }
  }
  throw error;
}
```

### Usage Examples

```typescript
// Blog Post Editor
// app/(dashboard)/blog/[postId]/edit/page.tsx
export default function EditBlogPost({ params }: { params: { postId: string } }) {
  return (
    <div className="container max-w-4xl py-8">
      <BlockNoteEditor documentId={params.postId} />
    </div>
  );
}

// Lesson Content Editor
// app/(admin)/lessons/[lessonId]/content/page.tsx
export default function EditLessonContent({ params }: { params: { lessonId: string } }) {
  const [isPublished, setIsPublished] = useState(false);

  return (
    <div className="container max-w-5xl py-8">
      <div className="mb-4 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Edit Lesson Content</h1>
        <button
          onClick={() => setIsPublished(!isPublished)}
          className="btn btn-primary"
        >
          {isPublished ? 'Unpublish' : 'Publish'}
        </button>
      </div>
      <BlockNoteEditor documentId={params.lessonId} editable={!isPublished} />
    </div>
  );
}

// Resource Documentation Editor
// app/(admin)/resources/[resourceId]/page.tsx
export default function EditResource({ params }: { params: { resourceId: string } }) {
  return (
    <div className="grid grid-cols-[1fr_300px] gap-8">
      <BlockNoteEditor documentId={params.resourceId} />
      <aside className="space-y-4">
        <ResourceMetadata resourceId={params.resourceId} />
        <ResourceTags resourceId={params.resourceId} />
      </aside>
    </div>
  );
}
```

---

## 10. Puck Page Builder (@measured/puck)

### Installation

```bash
pnpm add @measured/puck
```

### Configuration

```typescript
// lib/puck/config.ts
import { Config } from '@measured/puck';
import { HeroBlock } from './blocks/hero';
import { CTABlock } from './blocks/cta';
import { FeaturesBlock } from './blocks/features';
import { TestimonialsBlock } from './blocks/testimonials';
import { PricingTableBlock } from './blocks/pricing-table';
import { FAQBlock } from './blocks/faq';

export type PuckConfig = Config<{
  Hero: typeof HeroBlock;
  CTA: typeof CTABlock;
  Features: typeof FeaturesBlock;
  Testimonials: typeof TestimonialsBlock;
  PricingTable: typeof PricingTableBlock;
  FAQ: typeof FAQBlock;
}>;

export const config: PuckConfig = {
  components: {
    Hero: HeroBlock,
    CTA: CTABlock,
    Features: FeaturesBlock,
    Testimonials: TestimonialsBlock,
    PricingTable: PricingTableBlock,
    FAQ: FAQBlock,
  },
  root: {
    fields: {
      title: { type: 'text', label: 'Page Title' },
      description: { type: 'textarea', label: 'Page Description' },
    },
  },
};
```

### Custom Component Definitions

```typescript
// lib/puck/blocks/hero.tsx
import { ComponentConfig } from '@measured/puck';

export const HeroBlock: ComponentConfig = {
  fields: {
    title: {
      type: 'text',
      label: 'Title',
    },
    subtitle: {
      type: 'textarea',
      label: 'Subtitle',
    },
    ctaText: {
      type: 'text',
      label: 'CTA Button Text',
    },
    ctaUrl: {
      type: 'text',
      label: 'CTA Button URL',
    },
    backgroundImage: {
      type: 'text',
      label: 'Background Image URL',
    },
    variant: {
      type: 'select',
      label: 'Variant',
      options: [
        { label: 'Centered', value: 'centered' },
        { label: 'Left Aligned', value: 'left' },
        { label: 'Split', value: 'split' },
      ],
    },
  },
  defaultProps: {
    title: 'Transform Your Team with AI',
    subtitle: 'Join 1000+ companies building AI-ready teams through our intensive 2-day cohorts.',
    ctaText: 'View Upcoming Cohorts',
    ctaUrl: '/cohorts',
    variant: 'centered',
  },
  render: ({ title, subtitle, ctaText, ctaUrl, backgroundImage, variant }) => {
    return (
      <section
        className="relative py-24 lg:py-32"
        style={{
          backgroundImage: backgroundImage ? `url(${backgroundImage})` : undefined,
          backgroundSize: 'cover',
          backgroundPosition: 'center',
        }}
      >
        {backgroundImage && <div className="absolute inset-0 bg-black/50" />}
        <div
          className={cn('container relative z-10', {
            'text-center': variant === 'centered',
            'text-left': variant === 'left',
            'grid grid-cols-2 gap-12': variant === 'split',
          })}
        >
          <div>
            <h1 className="text-4xl font-bold tracking-tight text-white lg:text-6xl">
              {title}
            </h1>
            <p className="mt-6 text-xl text-gray-200">{subtitle}</p>
            <a
              href={ctaUrl}
              className="mt-8 inline-flex items-center rounded-lg bg-white px-6 py-3 text-base font-semibold text-gray-900 hover:bg-gray-100"
            >
              {ctaText}
            </a>
          </div>
          {variant === 'split' && (
            <div className="flex items-center justify-center">
              <div className="rounded-lg bg-white p-8 shadow-xl">
                {/* Placeholder for image/video */}
              </div>
            </div>
          )}
        </div>
      </section>
    );
  },
};

// lib/puck/blocks/cta.tsx
export const CTABlock: ComponentConfig = {
  fields: {
    title: { type: 'text', label: 'Title' },
    description: { type: 'textarea', label: 'Description' },
    primaryButtonText: { type: 'text', label: 'Primary Button Text' },
    primaryButtonUrl: { type: 'text', label: 'Primary Button URL' },
    secondaryButtonText: { type: 'text', label: 'Secondary Button Text' },
    secondaryButtonUrl: { type: 'text', label: 'Secondary Button URL' },
    backgroundColor: { type: 'text', label: 'Background Color' },
  },
  defaultProps: {
    title: 'Ready to Transform Your Team?',
    description: 'Join our next 2-day intensive cohort and build AI-ready skills.',
    primaryButtonText: 'Enroll Now',
    primaryButtonUrl: '/enroll',
    secondaryButtonText: 'Learn More',
    secondaryButtonUrl: '/about',
    backgroundColor: '#000000',
  },
  render: ({ title, description, primaryButtonText, primaryButtonUrl, secondaryButtonText, secondaryButtonUrl, backgroundColor }) => {
    return (
      <section className="py-16" style={{ backgroundColor }}>
        <div className="container text-center">
          <h2 className="text-3xl font-bold text-white">{title}</h2>
          <p className="mt-4 text-lg text-gray-300">{description}</p>
          <div className="mt-8 flex justify-center gap-4">
            <a href={primaryButtonUrl} className="btn btn-primary">
              {primaryButtonText}
            </a>
            <a href={secondaryButtonUrl} className="btn btn-secondary">
              {secondaryButtonText}
            </a>
          </div>
        </div>
      </section>
    );
  },
};

// lib/puck/blocks/features.tsx
export const FeaturesBlock: ComponentConfig = {
  fields: {
    title: { type: 'text', label: 'Section Title' },
    features: {
      type: 'array',
      label: 'Features',
      arrayFields: {
        icon: { type: 'text', label: 'Icon (Lucide name)' },
        title: { type: 'text', label: 'Feature Title' },
        description: { type: 'textarea', label: 'Feature Description' },
      },
    },
  },
  defaultProps: {
    title: 'Why Choose Us',
    features: [
      {
        icon: 'Zap',
        title: 'Hands-On Learning',
        description: '2-day intensive cohorts with real-world projects.',
      },
      {
        icon: 'Users',
        title: 'Expert Instructors',
        description: 'Learn from AI practitioners with industry experience.',
      },
      {
        icon: 'Award',
        title: 'Certification',
        description: 'Earn certificates recognized by leading companies.',
      },
    ],
  },
  render: ({ title, features }) => {
    return (
      <section className="py-16">
        <div className="container">
          <h2 className="text-center text-3xl font-bold">{title}</h2>
          <div className="mt-12 grid gap-8 md:grid-cols-3">
            {features.map((feature, idx) => (
              <div key={idx} className="text-center">
                <div className="mx-auto mb-4 flex h-12 w-12 items-center justify-center rounded-full bg-primary/10">
                  {/* Icon placeholder */}
                </div>
                <h3 className="text-xl font-semibold">{feature.title}</h3>
                <p className="mt-2 text-muted-foreground">{feature.description}</p>
              </div>
            ))}
          </div>
        </div>
      </section>
    );
  },
};

// lib/puck/blocks/pricing-table.tsx
export const PricingTableBlock: ComponentConfig = {
  fields: {
    title: { type: 'text', label: 'Section Title' },
    subtitle: { type: 'textarea', label: 'Subtitle' },
    plans: {
      type: 'array',
      label: 'Pricing Plans',
      arrayFields: {
        name: { type: 'text', label: 'Plan Name' },
        price: { type: 'text', label: 'Price' },
        description: { type: 'textarea', label: 'Description' },
        features: { type: 'textarea', label: 'Features (one per line)' },
        ctaText: { type: 'text', label: 'CTA Button Text' },
        ctaUrl: { type: 'text', label: 'CTA Button URL' },
        highlighted: { type: 'radio', label: 'Highlighted', options: [
          { label: 'Yes', value: true },
          { label: 'No', value: false },
        ]},
      },
    },
  },
  defaultProps: {
    title: 'Choose Your Path',
    subtitle: 'Flexible learning options for individuals and teams',
    plans: [
      {
        name: 'Self-Paced',
        price: '$499',
        description: 'Learn at your own pace with lifetime access',
        features: 'All course materials\nLifetime access\nCommunity support\nCertificate',
        ctaText: 'Get Started',
        ctaUrl: '/enroll/self-paced',
        highlighted: false,
      },
      {
        name: '2-Day Cohort',
        price: '$1,499',
        description: 'Intensive live training with expert instructors',
        features: 'Live instruction\nHands-on projects\nOffice hours\nNetworking\nCertificate',
        ctaText: 'Join Cohort',
        ctaUrl: '/enroll/cohort',
        highlighted: true,
      },
      {
        name: 'Enterprise',
        price: 'Custom',
        description: 'Tailored training for your entire organization',
        features: 'Custom curriculum\nOn-site training\nDedicated support\nUsage analytics\nCertificates',
        ctaText: 'Contact Sales',
        ctaUrl: '/contact',
        highlighted: false,
      },
    ],
  },
  render: ({ title, subtitle, plans }) => {
    return (
      <section className="py-16 bg-muted/50">
        <div className="container">
          <div className="text-center">
            <h2 className="text-3xl font-bold">{title}</h2>
            <p className="mt-4 text-lg text-muted-foreground">{subtitle}</p>
          </div>
          <div className="mt-12 grid gap-8 md:grid-cols-3">
            {plans.map((plan, idx) => (
              <div
                key={idx}
                className={cn(
                  'rounded-lg border p-8',
                  plan.highlighted && 'border-primary shadow-lg'
                )}
              >
                <h3 className="text-2xl font-bold">{plan.name}</h3>
                <p className="mt-2 text-4xl font-bold">{plan.price}</p>
                <p className="mt-4 text-muted-foreground">{plan.description}</p>
                <ul className="mt-6 space-y-2">
                  {plan.features.split('\n').map((feature, i) => (
                    <li key={i} className="flex items-center gap-2">
                      <span className="text-primary">✓</span>
                      {feature}
                    </li>
                  ))}
                </ul>
                <a href={plan.ctaUrl} className="mt-8 btn btn-primary w-full">
                  {plan.ctaText}
                </a>
              </div>
            ))}
          </div>
        </div>
      </section>
    );
  },
};
```

### Puck Editor Component

```typescript
// components/puck/puck-editor.tsx
'use client';

import { Puck } from '@measured/puck';
import '@measured/puck/dist/index.css';
import { config } from '@/lib/puck/config';
import { useMutation, useQuery } from 'convex/react';
import { api } from '@/convex/_generated/api';
import { Id } from '@/convex/_generated/dataModel';
import { useState } from 'react';

interface PuckEditorProps {
  pageId: string;
}

export function PuckEditor({ pageId }: PuckEditorProps) {
  const [isSaving, setIsSaving] = useState(false);

  // Load page data from Convex
  const page = useQuery(api.pages.getPage, {
    pageId: pageId as Id<'pages'>,
  });

  // Save page data to Convex
  const savePage = useMutation(api.pages.updatePage);

  const handleSave = async (data: any) => {
    setIsSaving(true);
    try {
      await savePage({
        pageId: pageId as Id<'pages'>,
        content: data,
      });
    } catch (error) {
      console.error('Failed to save page:', error);
      alert('Failed to save page. Please try again.');
    } finally {
      setIsSaving(false);
    }
  };

  if (!page) {
    return (
      <div className="flex h-screen items-center justify-center">
        <div className="animate-spin rounded-full h-8 w-8 border-b-2 border-primary" />
      </div>
    );
  }

  return (
    <Puck
      config={config}
      data={page.content || { content: [], root: {} }}
      onPublish={handleSave}
      headerTitle={page.title}
      headerPath={`/preview/${pageId}`}
    />
  );
}
```

### Convex Data Binding

```typescript
// convex/pages.ts
import { v } from 'convex/values';
import { mutation, query } from './_generated/server';

export const getPage = query({
  args: { pageId: v.id('pages') },
  handler: async (ctx, args) => {
    const page = await ctx.db.get(args.pageId);
    if (!page) throw new Error('Page not found');
    return page;
  },
});

export const updatePage = mutation({
  args: {
    pageId: v.id('pages'),
    content: v.any(),
  },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.pageId, {
      content: args.content,
      updatedAt: Date.now(),
    });
  },
});

export const createPage = mutation({
  args: {
    title: v.string(),
    slug: v.string(),
    template: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const pageId = await ctx.db.insert('pages', {
      title: args.title,
      slug: args.slug,
      content: getTemplateContent(args.template),
      status: 'draft',
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    return pageId;
  },
});

function getTemplateContent(template?: string) {
  // Template presets
  const templates = {
    landing: {
      content: [
        { type: 'Hero', props: {} },
        { type: 'Features', props: {} },
        { type: 'PricingTable', props: {} },
        { type: 'CTA', props: {} },
      ],
      root: {},
    },
    course: {
      content: [
        { type: 'Hero', props: {} },
        { type: 'Features', props: {} },
        { type: 'Testimonials', props: {} },
        { type: 'FAQ', props: {} },
        { type: 'CTA', props: {} },
      ],
      root: {},
    },
    default: {
      content: [],
      root: {},
    },
  };

  return templates[template as keyof typeof templates] || templates.default;
}
```

### Responsive Preview

```typescript
// components/puck/preview-toolbar.tsx
'use client';

import { Monitor, Smartphone, Tablet } from 'lucide-react';
import { useState } from 'react';

type ViewportSize = 'mobile' | 'tablet' | 'desktop';

export function PreviewToolbar({ children }: { children: React.ReactNode }) {
  const [viewport, setViewport] = useState<ViewportSize>('desktop');

  const viewportSizes = {
    mobile: 'w-[375px]',
    tablet: 'w-[768px]',
    desktop: 'w-full',
  };

  return (
    <div className="h-screen flex flex-col">
      <div className="border-b p-4 flex items-center justify-center gap-4">
        <button
          onClick={() => setViewport('mobile')}
          className={cn('p-2', viewport === 'mobile' && 'bg-muted')}
        >
          <Smartphone className="h-4 w-4" />
        </button>
        <button
          onClick={() => setViewport('tablet')}
          className={cn('p-2', viewport === 'tablet' && 'bg-muted')}
        >
          <Tablet className="h-4 w-4" />
        </button>
        <button
          onClick={() => setViewport('desktop')}
          className={cn('p-2', viewport === 'desktop' && 'bg-muted')}
        >
          <Monitor className="h-4 w-4" />
        </button>
      </div>
      <div className="flex-1 overflow-auto bg-muted p-8">
        <div className={cn('mx-auto bg-white', viewportSizes[viewport])}>
          {children}
        </div>
      </div>
    </div>
  );
}
```

### Undo/Redo with History

```typescript
// hooks/use-puck-history.ts
import { useState, useCallback } from 'react';

interface HistoryState<T> {
  past: T[];
  present: T;
  future: T[];
}

export function usePuckHistory<T>(initialState: T) {
  const [history, setHistory] = useState<HistoryState<T>>({
    past: [],
    present: initialState,
    future: [],
  });

  const set = useCallback((newState: T) => {
    setHistory((prev) => ({
      past: [...prev.past, prev.present],
      present: newState,
      future: [],
    }));
  }, []);

  const undo = useCallback(() => {
    setHistory((prev) => {
      if (prev.past.length === 0) return prev;

      const previous = prev.past[prev.past.length - 1];
      const newPast = prev.past.slice(0, prev.past.length - 1);

      return {
        past: newPast,
        present: previous,
        future: [prev.present, ...prev.future],
      };
    });
  }, []);

  const redo = useCallback(() => {
    setHistory((prev) => {
      if (prev.future.length === 0) return prev;

      const next = prev.future[0];
      const newFuture = prev.future.slice(1);

      return {
        past: [...prev.past, prev.present],
        present: next,
        future: newFuture,
      };
    });
  }, []);

  return {
    state: history.present,
    set,
    undo,
    redo,
    canUndo: history.past.length > 0,
    canRedo: history.future.length > 0,
  };
}
```

### Error Handling

```typescript
// lib/puck/errors.ts
export class PuckError extends Error {
  constructor(
    message: string,
    public code: 'LOAD_FAILED' | 'SAVE_FAILED' | 'COMPONENT_ERROR' | 'VALIDATION_FAILED'
  ) {
    super(message);
    this.name = 'PuckError';
  }
}

export function handlePuckError(error: unknown): never {
  if (error instanceof PuckError) {
    switch (error.code) {
      case 'LOAD_FAILED':
        throw new Error('Failed to load page. Please refresh.');
      case 'SAVE_FAILED':
        throw new Error('Failed to save page. Your changes may not be saved.');
      case 'COMPONENT_ERROR':
        throw new Error('Component failed to render. Please check configuration.');
      case 'VALIDATION_FAILED':
        throw new Error('Invalid page configuration. Please review your changes.');
    }
  }
  throw error;
}
```

### Usage Examples

```typescript
// Landing Page Editor
// app/(admin)/pages/[pageId]/edit/page.tsx
export default function EditLandingPage({ params }: { params: { pageId: string } }) {
  return <PuckEditor pageId={params.pageId} />;
}

// Course Landing Page
// app/(admin)/courses/[courseId]/landing/page.tsx
export default function EditCourseLanding({ params }: { params: { courseId: string } }) {
  return (
    <div>
      <h1 className="mb-4 text-2xl font-bold">Edit Course Landing Page</h1>
      <PuckEditor pageId={`course-${params.courseId}`} />
    </div>
  );
}

// Marketing Pages
// app/(admin)/marketing/page.tsx
export default function MarketingPages() {
  const pages = useQuery(api.pages.listPages, { type: 'marketing' });

  return (
    <div className="container py-8">
      <div className="flex items-center justify-between mb-8">
        <h1 className="text-3xl font-bold">Marketing Pages</h1>
        <CreatePageDialog />
      </div>
      <div className="grid gap-4 md:grid-cols-3">
        {pages?.map((page) => (
          <PageCard key={page._id} page={page} />
        ))}
      </div>
    </div>
  );
}
```

---

## 11. Convex ProseMirror Sync (@convex-dev/prosemirror-sync)

### Installation

```bash
pnpm add @convex-dev/prosemirror-sync prosemirror-state prosemirror-view prosemirror-model
```

### Convex Component Setup

```typescript
// convex.config.ts
import { defineApp } from 'convex/server';
import prosemirror from '@convex-dev/prosemirror-sync/convex.config';

const app = defineApp();
app.use(prosemirror);

export default app;
```

### Document Creation and Sync

```typescript
// convex/documents.ts
import { v } from 'convex/values';
import { mutation, query } from './_generated/server';
import { components } from './_generated/api';

// Create new collaborative document
export const createDocument = mutation({
  args: {
    title: v.string(),
    type: v.union(v.literal('blog'), v.literal('lesson'), v.literal('resource')),
    ownerId: v.string(),
  },
  handler: async (ctx, args) => {
    // Create document record
    const documentId = await ctx.db.insert('documents', {
      title: args.title,
      type: args.type,
      ownerId: args.ownerId,
      createdAt: Date.now(),
      updatedAt: Date.now(),
    });

    // Initialize ProseMirror sync document
    await ctx.runMutation(components.prosemirror.init, {
      documentId: documentId as any,
      initialContent: {
        type: 'doc',
        content: [
          {
            type: 'paragraph',
            content: [{ type: 'text', text: 'Start writing...' }],
          },
        ],
      },
    });

    return documentId;
  },
});

// Get document with sync state
export const getDocument = query({
  args: { documentId: v.id('documents') },
  handler: async (ctx, args) => {
    const document = await ctx.db.get(args.documentId);
    if (!document) throw new Error('Document not found');

    // Get ProseMirror state
    const syncState = await ctx.runQuery(components.prosemirror.getState, {
      documentId: args.documentId as any,
    });

    return {
      ...document,
      content: syncState.doc,
      version: syncState.version,
    };
  },
});

// Update document metadata
export const updateDocument = mutation({
  args: {
    documentId: v.id('documents'),
    title: v.optional(v.string()),
    status: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { documentId, ...updates } = args;
    await ctx.db.patch(documentId, {
      ...updates,
      updatedAt: Date.now(),
    });
  },
});
```

### Multi-User Collaboration

```typescript
// hooks/use-prosemirror-sync.ts
'use client';

import { useEffect, useRef, useState } from 'react';
import { EditorState } from 'prosemirror-state';
import { EditorView } from 'prosemirror-view';
import { Schema, DOMParser } from 'prosemirror-model';
import { schema } from 'prosemirror-schema-basic';
import { addListNodes } from 'prosemirror-schema-list';
import { exampleSetup } from 'prosemirror-example-setup';
import { collab, receiveTransaction, sendableSteps } from 'prosemirror-collab';
import { useMutation, useQuery } from 'convex/react';
import { api } from '@/convex/_generated/api';
import { Id } from '@/convex/_generated/dataModel';

interface UseProseMirrorSyncOptions {
  documentId: string;
  editable?: boolean;
}

export function useProseMirrorSync({
  documentId,
  editable = true,
}: UseProseMirrorSyncOptions) {
  const editorRef = useRef<HTMLDivElement>(null);
  const viewRef = useRef<EditorView | null>(null);
  const [isConnected, setIsConnected] = useState(false);

  // Get document state
  const document = useQuery(api.documents.getDocument, {
    documentId: documentId as Id<'documents'>,
  });

  // Send updates to Convex
  const sendSteps = useMutation(api.prosemirror.sendSteps);

  // Receive updates from Convex
  const getSteps = useQuery(api.prosemirror.getSteps, {
    documentId: documentId as Id<'documents'>,
    version: document?.version || 0,
  });

  // Initialize ProseMirror editor
  useEffect(() => {
    if (!editorRef.current || !document) return;

    const mySchema = new Schema({
      nodes: addListNodes(schema.spec.nodes, 'paragraph block*', 'block'),
      marks: schema.spec.marks,
    });

    const state = EditorState.create({
      doc: mySchema.nodeFromJSON(document.content),
      plugins: [
        ...exampleSetup({ schema: mySchema }),
        collab({ version: document.version }),
      ],
    });

    const view = new EditorView(editorRef.current, {
      state,
      editable: () => editable,
      dispatchTransaction(transaction) {
        const newState = view.state.apply(transaction);
        view.updateState(newState);

        // Send local changes to Convex
        const steps = sendableSteps(newState);
        if (steps) {
          sendSteps({
            documentId: documentId as Id<'documents'>,
            version: steps.version,
            steps: steps.steps.map((s) => s.toJSON()),
            clientID: steps.clientID,
          }).catch(console.error);
        }
      },
    });

    viewRef.current = view;
    setIsConnected(true);

    return () => {
      view.destroy();
      viewRef.current = null;
      setIsConnected(false);
    };
  }, [document, documentId, editable, sendSteps]);

  // Apply remote changes
  useEffect(() => {
    if (!viewRef.current || !getSteps?.steps) return;

    const view = viewRef.current;
    const steps = getSteps.steps.map((s: any) => Step.fromJSON(view.state.schema, s));

    const tr = receiveTransaction(
      view.state,
      steps,
      steps.map(() => getSteps.clientID)
    );

    view.dispatch(tr);
  }, [getSteps]);

  return {
    editorRef,
    isConnected,
    view: viewRef.current,
  };
}
```

### Cursor Presence Indicators

```typescript
// lib/prosemirror/presence.ts
import { Plugin, PluginKey } from 'prosemirror-state';
import { Decoration, DecorationSet } from 'prosemirror-view';
import { useQuery } from 'convex/react';
import { api } from '@/convex/_generated/api';

interface UserPresence {
  userId: string;
  userName: string;
  color: string;
  position: number;
}

const presencePluginKey = new PluginKey('presence');

export function createPresencePlugin(documentId: string) {
  return new Plugin({
    key: presencePluginKey,
    state: {
      init() {
        return DecorationSet.empty;
      },
      apply(tr, set) {
        // Get presence data from transaction metadata
        const presence = tr.getMeta(presencePluginKey);
        if (!presence) return set;

        // Create cursor decorations for other users
        const decorations = presence.users.map((user: UserPresence) => {
          const widget = document.createElement('span');
          widget.className = 'cursor-presence';
          widget.style.borderLeft = `2px solid ${user.color}`;
          widget.setAttribute('data-user', user.userName);

          return Decoration.widget(user.position, widget, {
            side: 1,
          });
        });

        return DecorationSet.create(tr.doc, decorations);
      },
    },
    props: {
      decorations(state) {
        return this.getState(state);
      },
    },
  });
}

// Hook to track user presence
export function usePresence(documentId: string) {
  const presence = useQuery(api.prosemirror.getPresence, {
    documentId: documentId as Id<'documents'>,
  });

  return presence?.users || [];
}

// Presence indicator component
export function PresenceIndicators({ documentId }: { documentId: string }) {
  const users = usePresence(documentId);

  return (
    <div className="flex items-center gap-2">
      {users.slice(0, 3).map((user) => (
        <div
          key={user.userId}
          className="h-8 w-8 rounded-full flex items-center justify-center text-xs font-semibold text-white"
          style={{ backgroundColor: user.color }}
          title={user.userName}
        >
          {user.userName.charAt(0).toUpperCase()}
        </div>
      ))}
      {users.length > 3 && (
        <div className="h-8 w-8 rounded-full bg-muted flex items-center justify-center text-xs font-semibold">
          +{users.length - 3}
        </div>
      )}
    </div>
  );
}
```

### Version History

```typescript
// convex/versions.ts
import { v } from 'convex/values';
import { mutation, query } from './_generated/server';

// Create version snapshot
export const createVersion = mutation({
  args: {
    documentId: v.id('documents'),
    label: v.string(),
    userId: v.string(),
  },
  handler: async (ctx, args) => {
    // Get current document state
    const document = await ctx.db.get(args.documentId);
    if (!document) throw new Error('Document not found');

    // Create version snapshot
    const versionId = await ctx.db.insert('versions', {
      documentId: args.documentId,
      label: args.label,
      content: document.content,
      createdBy: args.userId,
      createdAt: Date.now(),
    });

    return versionId;
  },
});

// List document versions
export const listVersions = query({
  args: { documentId: v.id('documents') },
  handler: async (ctx, args) => {
    return await ctx.db
      .query('versions')
      .withIndex('by_document', (q) => q.eq('documentId', args.documentId))
      .order('desc')
      .collect();
  },
});

// Restore version
export const restoreVersion = mutation({
  args: {
    versionId: v.id('versions'),
  },
  handler: async (ctx, args) => {
    const version = await ctx.db.get(args.versionId);
    if (!version) throw new Error('Version not found');

    // Update document with version content
    await ctx.db.patch(version.documentId, {
      content: version.content,
      updatedAt: Date.now(),
    });

    return version.documentId;
  },
});
```

### Conflict Resolution

```typescript
// lib/prosemirror/conflicts.ts
import { Step } from 'prosemirror-transform';
import { EditorState, Transaction } from 'prosemirror-state';

export function resolveConflicts(
  state: EditorState,
  localSteps: Step[],
  remoteSteps: Step[]
): Transaction {
  let tr = state.tr;

  // Try to apply remote steps first
  for (const step of remoteSteps) {
    const result = step.apply(tr.doc);
    if (result.failed) {
      console.warn('Remote step failed:', result.failed);
      continue;
    }
    tr.step(step);
  }

  // Rebase local steps on top of remote changes
  for (const step of localSteps) {
    const mapped = step.map(tr.mapping);
    if (!mapped) {
      console.warn('Local step could not be mapped');
      continue;
    }

    const result = mapped.apply(tr.doc);
    if (result.failed) {
      console.warn('Local step failed after mapping:', result.failed);
      continue;
    }
    tr.step(mapped);
  }

  return tr;
}
```

### Error Handling

```typescript
// lib/prosemirror/errors.ts
export class ProseMirrorSyncError extends Error {
  constructor(
    message: string,
    public code: 'SYNC_FAILED' | 'CONFLICT' | 'DISCONNECTED' | 'VERSION_MISMATCH'
  ) {
    super(message);
    this.name = 'ProseMirrorSyncError';
  }
}

export function handleSyncError(error: unknown): never {
  if (error instanceof ProseMirrorSyncError) {
    switch (error.code) {
      case 'SYNC_FAILED':
        throw new Error('Failed to sync changes. Please check your connection.');
      case 'CONFLICT':
        throw new Error('Conflicting changes detected. Attempting to resolve...');
      case 'DISCONNECTED':
        throw new Error('Connection lost. Reconnecting...');
      case 'VERSION_MISMATCH':
        throw new Error('Document version mismatch. Please refresh.');
    }
  }
  throw error;
}
```

### Usage Examples

```typescript
// Collaborative Blog Editor
// app/(dashboard)/blog/[postId]/edit/page.tsx
export default function EditBlogPost({ params }: { params: { postId: string } }) {
  const { editorRef, isConnected } = useProseMirrorSync({
    documentId: params.postId,
    editable: true,
  });

  return (
    <div className="container max-w-4xl py-8">
      <div className="mb-4 flex items-center justify-between">
        <h1 className="text-2xl font-bold">Edit Blog Post</h1>
        <div className="flex items-center gap-4">
          <div className={cn('h-2 w-2 rounded-full', isConnected ? 'bg-green-500' : 'bg-red-500')} />
          <PresenceIndicators documentId={params.postId} />
        </div>
      </div>
      <div ref={editorRef} className="prose max-w-none" />
    </div>
  );
}

// Lesson Content with Version History
// app/(admin)/lessons/[lessonId]/content/page.tsx
export default function EditLessonContent({ params }: { params: { lessonId: string } }) {
  const { editorRef, isConnected } = useProseMirrorSync({
    documentId: params.lessonId,
  });

  const versions = useQuery(api.versions.listVersions, {
    documentId: params.lessonId as Id<'documents'>,
  });

  return (
    <div className="grid grid-cols-[1fr_300px] gap-8">
      <div>
        <div ref={editorRef} className="prose max-w-none" />
      </div>
      <aside className="space-y-4">
        <VersionHistory documentId={params.lessonId} versions={versions} />
      </aside>
    </div>
  );
}

// Real-Time Collaboration Component
// components/editor/collaborative-editor.tsx
export function CollaborativeEditor({ documentId }: { documentId: string }) {
  const { editorRef, isConnected } = useProseMirrorSync({ documentId });

  return (
    <div className="border rounded-lg">
      <div className="border-b p-4 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <div className={cn('h-2 w-2 rounded-full', isConnected ? 'bg-green-500' : 'bg-red-500')} />
          <span className="text-sm">{isConnected ? 'Connected' : 'Disconnected'}</span>
        </div>
        <PresenceIndicators documentId={documentId} />
      </div>
      <div ref={editorRef} className="p-4 min-h-[400px]" />
    </div>
  );
}
```

---
