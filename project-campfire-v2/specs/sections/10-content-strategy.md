# 10. Content Strategy for Phase 0

## Executive Summary

Phase 0 (Marketing Landing Page) requires a comprehensive content migration and creation strategy. The v1 project-campfire contains substantial high-quality content that can be reused, but requires adaptation for the new platform architecture and updated positioning.

**Key Finding:** ~70% of content can be migrated from v1 with minor updates. ~30% requires new creation or significant rewrite.

**Recommendation:** Phase 0 can proceed with existing content as the foundation, but requires a focused 3-5 day content sprint to adapt, polish, and create missing pieces.

---

## 10.1 Pages Required for Phase 0

### Marketing/Public Pages (Content Needs)

#### 10.1.1 Homepage (Landing Page)
**Purpose:** Convert visitors to course enrollments or enterprise inquiries

**Content Requirements:**
- Hero headline and value proposition (EXISTS - needs minor update)
- Course catalog preview with 2 featured courses (EXISTS - needs formatting)
- Social proof section (testimonials + company logos) (EXISTS - strong testimonials available)
- Trust indicators (cohort stats, instructor credentials) (PARTIAL - needs data updates)
- CTA buttons (NEEDS COPY - "Join Next Cohort", "Schedule Discovery Call")
- Footer content (NEEDS CREATION)

**Available Content from v1:**
```
Source: /research and data/academy-export/Website Content/website content 2025-11-5.md

Hero:
✅ "Stop tinkering with AI. Start building with it!"
✅ "Build Real AI Skills That Move Your Career Forward."
✅ "2-day intensive cohort with hands-on labs and proven frameworks."

Testimonials:
✅ 9 validated testimonials with names, titles, photos
✅ Segmented by ICP (L&D leaders, TA owners, functional leaders, independents)
✅ High-impact quotes addressing pain points

Founder bios:
✅ Klara Hermesz - Chief Learning Strategist
✅ Adam Kovacs - Chief AI Strategist
✅ Complete background narratives
✅ Professional photos available
```

**Content Gaps:**
- [ ] Updated cohort statistics (total learners trained, NPS score)
- [ ] Company logos for "Instructors built experiences at" section (Meta, Uber, AWS - exists but needs verification)
- [ ] Footer legal links (Privacy Policy, Terms of Service, Cookie Policy)
- [ ] Newsletter signup microcopy

---

#### 10.1.2 Course Catalog Page
**Purpose:** Showcase all offerings with filtering and search

**Content Requirements:**
- Page header and description (NEEDS CREATION)
- Course cards with thumbnails (NEEDS DESIGN)
- Filtering controls copy (NEEDS CREATION)
- Empty state messaging (NEEDS CREATION)

**Available Content from v1:**
```
✅ AI Foundations complete course outline
✅ AI Essentials complete course outline
✅ Pricing tiers ($749, $1,479, Enterprise)
✅ Program inclusions list
✅ Target audience descriptions (AI-Curious, AI-Engaged)
```

**Content Gaps:**
- [ ] Course thumbnail images (2 images needed)
- [ ] Search placeholder text
- [ ] Filter category labels
- [ ] "No results" empty state copy

---

#### 10.1.3 Individual Course Page (Detail View)
**Purpose:** Drive enrollment decision with detailed curriculum

**Content Requirements:**
- Course overview and outcomes (EXISTS)
- Day-by-day session breakdown (EXISTS)
- Instructor bio (EXISTS)
- Upcoming cohorts table (NEEDS DYNAMIC DATA)
- Testimonials specific to course level (EXISTS)
- FAQ section (EXISTS)
- Enrollment CTA (NEEDS COPY)

**Available Content from v1:**
```
AI Foundations:
✅ Complete 2-day curriculum with session titles
✅ Workshop descriptions and outcomes
✅ Target audience profile ("AI-Curious Professional")
✅ "What You'll Walk Away With" section
✅ "Who This Is NOT For" section
✅ Testimonial quotes matched to this level

AI Essentials:
✅ Complete 2-day curriculum with session titles
✅ Advanced workshop descriptions
✅ Target audience profile ("AI-Engaged Professional")
✅ Technical outcomes (prompting mastery, research methodology, etc.)
✅ Testimonial quotes matched to this level

Executive Strategy (future):
⚠️ Outline exists but needs full curriculum development
```

**Content Gaps:**
- [ ] Video course trailers (optional for Phase 0)
- [ ] Course prerequisite descriptions
- [ ] "What's included" detailed breakdown with icons

---

#### 10.1.4 Pricing Page
**Purpose:** Transparent pricing with B2C/B2B differentiation

**Content Requirements:**
- Pricing tiers comparison table (EXISTS)
- Program inclusions per tier (EXISTS)
- Money-back guarantee policy (EXISTS)
- Enterprise custom pricing section (EXISTS)
- FAQ specific to pricing (PARTIAL)

**Available Content from v1:**
```
B2C Pricing:
✅ AI Foundations: $749/person
✅ AI Essentials: $1,479/person
✅ Complete inclusions list (7 items)
✅ Refund policy: "Full refund up to 7 days before cohort start"

B2B Pricing:
✅ Executive AI Strategy Session: $749-$995/person (6 hrs, 5-20 people)
✅ AI for Productivity Team Offsite: $997-$1,497/person (10 hrs, 8-20 people)
✅ Custom cohorts: $28,500+ (20 seats)
✅ Enterprise deliverables list
```

**Content Gaps:**
- [ ] Pricing FAQ section (8-10 questions)
- [ ] Volume discount structure clarity
- [ ] Payment method details
- [ ] Invoice vs. credit card messaging

---

#### 10.1.5 About Page
**Purpose:** Build credibility and trust through founder story

**Content Requirements:**
- Company mission statement (EXISTS)
- Founder bios with photos (EXISTS)
- Company credentials and achievements (PARTIAL)
- Brand story and differentiation (EXISTS)

**Available Content from v1:**
```
✅ Founder bios (Klara Hermesz, Adam Kovacs)
✅ Professional backgrounds (Meta, Uber, AWS, Perplexity Fellow, Agentic Foundation)
✅ Mission: "Transform professionals from AI-aware to AI-proficient"
✅ Differentiation: "Bridge between AI theory and business application"
✅ Brand attributes: Clarity, Transformation, Trust, Empowerment
```

**Content Gaps:**
- [ ] Company founding story (why we started)
- [ ] Timeline of achievements (optional)
- [ ] Press mentions (if available)
- [ ] Awards or certifications (if available)

---

#### 10.1.6 Contact/Support Page
**Purpose:** Enterprise inquiry capture and general support

**Content Requirements:**
- Contact form with field labels (NEEDS CREATION)
- Enterprise inquiry CTA (NEEDS COPY)
- General support contact methods (NEEDS CREATION)
- Office hours information (NEEDS COPY)
- FAQ link (EXISTS)

**Available Content from v1:**
```
✅ Contact email: hello@aienablement.academy
✅ Enterprise calendar link: https://calendar.app.google/g6eq2EcbpdUJEAAc9
```

**Content Gaps:**
- [ ] Form field labels and placeholders
- [ ] Success/error messages for form submission
- [ ] Expected response time messaging
- [ ] Support hours (if available)

---

### Authenticated Pages (Post-MVP Content)

#### 10.1.7 Login/Register Pages
**Purpose:** User authentication entry points

**Content Requirements:**
- [ ] Login form labels (Email, Password, "Forgot Password?")
- [ ] Register form labels (Name, Email, Password, Confirm Password)
- [ ] Social login button copy ("Continue with Google", "Continue with LinkedIn")
- [ ] Terms acceptance checkbox copy
- [ ] Success/error messages
- [ ] Password requirements messaging

**Content Status:** NEEDS CREATION (Phase 1)

---

#### 10.1.8 Dashboard (Learner Portal)
**Purpose:** Central hub for enrolled learners

**Content Requirements:**
- [ ] Welcome messaging (personalized)
- [ ] Empty state copy (before enrollment)
- [ ] Navigation labels (My Courses, Profile, Settings)
- [ ] Quick action button labels
- [ ] Status badge copy (Upcoming, In Progress, Completed)

**Content Status:** NEEDS CREATION (Phase 1)

---

#### 10.1.9 Course Detail (Enrolled View)
**Purpose:** Access materials, Zoom links, recordings

**Content Requirements:**
- [ ] Pre-cohort checklist instructions
- [ ] Zoom access instructions
- [ ] Materials download section copy
- [ ] Office hours booking instructions
- [ ] Certificate display messaging

**Content Status:** NEEDS CREATION (Phase 1-2)

---

#### 10.1.10 Profile Settings
**Purpose:** User account management

**Content Requirements:**
- [ ] Section headers (Personal Info, Notification Preferences, Account Settings)
- [ ] Field labels and help text
- [ ] Privacy and data usage messaging
- [ ] Account deletion confirmation copy

**Content Status:** NEEDS CREATION (Phase 1)

---

## 10.2 Content Migration Plan

### 10.2.1 Direct Migration (Minimal Changes)
**Content that can be copied directly from v1 to v2:**

| Content Type | Source | Destination | Notes |
|-------------|--------|-------------|-------|
| Hero headline | website content 2025-11-5.md | Homepage hero | Copy as-is |
| Founder bios | website content 2025-11-5.md | About page | Copy as-is |
| Testimonials | Cohort 1 Testimonials from transcript.md | Homepage + Course pages | Copy as-is |
| Course outlines | website content 2025-11-5.md | Course detail pages | Copy as-is |
| Pricing tiers | Pricing.md | Pricing page | Update dates only |
| FAQ content | FAQ: The AI Enablement Academy.md | FAQ page | Copy as-is |
| Brand colors | Brand & Visual Guidelines.md | Design system | Copy as-is |

**Effort:** ~1 day (copy-paste, verify formatting)

---

### 10.2.2 Adaptation Required (Moderate Changes)
**Content that needs structural updates for new platform:**

| Content Type | Source | Changes Needed | Effort |
|-------------|--------|----------------|--------|
| Course inclusions | Multiple sources | Consolidate into unified list | 2 hours |
| Instructor credentials | website content 2025-11-5.md | Add structured data for schema.org | 1 hour |
| Testimonials | transcript.md | Create shortened versions for cards | 2 hours |
| Navigation labels | None | Create based on new IA | 1 hour |
| CTA buttons | Multiple sources | Standardize language | 1 hour |

**Effort:** ~1 day

---

### 10.2.3 New Content Creation (Major Work)
**Content that must be created from scratch:**

| Content Type | Purpose | Estimated Words | Effort |
|-------------|---------|-----------------|--------|
| SEO meta descriptions | Search visibility | 150-300 per page (6 pages) | 3 hours |
| Open Graph tags | Social sharing | 100 per page (6 pages) | 2 hours |
| Error messages | UX feedback | 50 messages x 20 words | 2 hours |
| Empty states | UX guidance | 10 states x 50 words | 1 hour |
| Form validation | User guidance | 30 messages x 20 words | 1 hour |
| Email templates | Brevo automation | 10 templates x 200 words | 4 hours |
| Privacy Policy | Legal compliance | 2,000 words | 4 hours (use generator + review) |
| Terms of Service | Legal compliance | 3,000 words | 4 hours (use generator + review) |
| Cookie Policy | GDPR compliance | 1,000 words | 2 hours |

**Effort:** ~3 days

---

## 10.3 Copywriting Needs

### 10.3.1 Headlines and Taglines

**Primary Tagline (EXISTS):**
```
"Stop tinkering with AI. Start building with it!"
```
**Status:** ✅ APPROVED - Already validated with Cohort 1

**Supporting Headlines (NEED REVIEW):**
```
Homepage:
- "Build Real AI Skills That Move Your Career Forward" ✅
- "2-day intensive cohort with hands-on labs and proven frameworks" ✅

Course Pages:
- Foundations: "For the AI-Curious Professional" ✅
- Essentials: "For the AI-Engaged Professional" ✅
```

**New Headlines NEEDED:**
- [ ] Contact page headline
- [ ] About page headline
- [ ] 404 error page headline

---

### 10.3.2 CTA Buttons

**Existing CTAs (GOOD):**
```
✅ "Join Next Cohort"
✅ "Schedule Time With Us"
✅ "Contact Us"
✅ "Register for AI Foundations"
✅ "Register for AI Essentials"
```

**New CTAs NEEDED:**
```
[ ] "Explore Courses"
[ ] "View Pricing"
[ ] "Download Course Outline" (lead magnet)
[ ] "Book Discovery Call"
[ ] "Get Started"
[ ] "Learn More"
```

---

### 10.3.3 Email Templates (Brevo Integration)

**Phase 0:** Contact form confirmations only

| Template | Trigger | Variables | Status |
|----------|---------|-----------|--------|
| Contact form confirmation | Enterprise inquiry submitted | {name}, {company}, {message} | NEEDS CREATION |
| Newsletter welcome | Newsletter signup | {email} | NEEDS CREATION |

**Phase 1:** Full enrollment sequence (10 templates - see PRD Section 6.2)

---

### 10.3.4 Error Messages

**System Errors:**
```
NEEDS CREATION (Examples):
- "Oops! Something went wrong. Please try again."
- "This page couldn't be found. Let's get you back on track."
- "Your session has expired. Please sign in again."
```

**Form Validation:**
```
NEEDS CREATION (Examples):
- "Please enter a valid email address."
- "Password must be at least 8 characters."
- "This field is required."
```

---

### 10.3.5 Empty States

**Dashboard Empty States:**
```
NEEDS CREATION (Phase 1):
- "You haven't enrolled in any courses yet. Browse our catalog to get started!"
- "No upcoming sessions. Check back soon for new cohorts."
- "You don't have any messages yet."
```

---

## 10.4 SEO Requirements

### 10.4.1 Meta Titles and Descriptions

**Homepage:**
```
Title (NEEDS CREATION):
"AI Enablement Academy | Transform from AI-Aware to AI-Proficient"

Description (NEEDS CREATION):
"Join our 2-day intensive cohorts to build real AI skills. Hands-on training with proven frameworks. Trusted by professionals at Meta, Uber, and AWS. Enroll today!"
```

**Course Pages:**
```
AI Foundations Title (NEEDS CREATION):
"AI Foundations Course | 2-Day Intensive for AI-Curious Professionals"

AI Foundations Description (NEEDS CREATION):
"Master AI fundamentals in 2 days. Learn the PIC prompting framework, build your first CustomGPT, and transform from AI-curious to AI-capable. $749. Next cohort: [Date]."

AI Essentials Title (NEEDS CREATION):
"AI Essentials Course | Advanced AI Training for Engaged Professionals"

AI Essentials Description (NEEDS CREATION):
"Advance from AI user to architect. Master advanced prompting, deep research, and knowledge management. Build production-ready AI tools. $1,479. Next cohort: [Date]."
```

**Pricing Page:**
```
Title (NEEDS CREATION):
"Pricing | AI Enablement Academy Courses & Enterprise Programs"

Description (NEEDS CREATION):
"Transparent pricing for B2C and B2B AI training. Individual courses from $749. Custom enterprise programs from $28,500. Full refund up to 7 days before start."
```

**About Page:**
```
Title (NEEDS CREATION):
"About Us | AI Enablement Academy Founders & Mission"

Description (NEEDS CREATION):
"Meet the founders who built learning programs at Meta, Uber, and AWS. Our mission: transform professionals from AI-aware to AI-proficient through science-backed training."
```

---

### 10.4.2 Open Graph Tags (Social Sharing)

**Homepage OG Tags (NEEDS CREATION):**
```html
<meta property="og:title" content="AI Enablement Academy | Transform Your AI Skills">
<meta property="og:description" content="2-day intensive cohorts to build real AI skills. Hands-on labs, proven frameworks, expert instructors.">
<meta property="og:image" content="https://aienablement.academy/og-image-home.jpg">
<meta property="og:url" content="https://aienablement.academy">
<meta property="og:type" content="website">
```

**OG Images NEEDED:**
- [ ] Homepage OG image (1200x630px)
- [ ] Course page OG images (2 images, 1200x630px)
- [ ] Pricing page OG image (1200x630px)
- [ ] About page OG image (1200x630px)

---

### 10.4.3 Structured Data (JSON-LD)

**Organization Schema (NEEDS CREATION):**
```json
{
  "@context": "https://schema.org",
  "@type": "EducationalOrganization",
  "name": "AI Enablement Academy",
  "url": "https://aienablement.academy",
  "logo": "https://aienablement.academy/logo.png",
  "description": "Transform professionals from AI-aware to AI-proficient through structured, science-backed learning experiences.",
  "founder": [
    {
      "@type": "Person",
      "name": "Klara Hermesz",
      "jobTitle": "Chief Learning Strategist"
    },
    {
      "@type": "Person",
      "name": "Adam Kovacs",
      "jobTitle": "Chief AI Strategist"
    }
  ]
}
```

**Course Schema (NEEDS CREATION for 2 courses):**
```json
{
  "@context": "https://schema.org",
  "@type": "Course",
  "name": "AI Foundations",
  "description": "2-day intensive cohort for AI-curious professionals",
  "provider": {
    "@type": "Organization",
    "name": "AI Enablement Academy"
  },
  "offers": {
    "@type": "Offer",
    "price": "749",
    "priceCurrency": "USD"
  }
}
```

---

## 10.5 Content Reuse vs. Rewrite Analysis

### 10.5.1 High-Quality Content (Reuse As-Is)

**Source:** `/research and data/academy-export/Website Content/`

| Content | Quality | Action |
|---------|---------|--------|
| Testimonials | ⭐⭐⭐⭐⭐ Excellent | Copy directly |
| Course outlines | ⭐⭐⭐⭐⭐ Excellent | Copy directly |
| Founder bios | ⭐⭐⭐⭐ Very Good | Copy directly |
| Value proposition | ⭐⭐⭐⭐⭐ Excellent | Copy directly |
| FAQ content | ⭐⭐⭐⭐ Very Good | Copy directly |
| Pricing tiers | ⭐⭐⭐⭐ Very Good | Update dates only |

**Reasoning:** This content was validated through Cohort 1 delivery and refined based on learner feedback. No rewrite needed.

---

### 10.5.2 Content Needing Updates

**Source:** Various v1 files

| Content | Issue | Action |
|---------|-------|--------|
| Cohort dates | Outdated | Replace with dynamic data |
| Company logos | Missing verification | Confirm permission to use |
| Instructor stats | Missing data | Add accurate metrics |
| Navigation labels | New IA | Create for v2 structure |

**Reasoning:** Content is structurally sound but needs data updates for v2 launch.

---

### 10.5.3 Net-New Content Required

**No v1 equivalent exists:**

| Content | Reason | Priority |
|---------|--------|----------|
| Legal pages (Privacy, Terms, Cookies) | Compliance requirement | P0 - Blocking |
| SEO meta descriptions | New platform requirement | P0 - Blocking |
| Error messages | New platform requirement | P0 - Blocking |
| Empty states | New platform requirement | P1 - High |
| Email templates (10 total) | Brevo integration requirement | P1 - High (Phase 1) |
| Form validation messages | New platform requirement | P1 - High |

**Reasoning:** These are technical requirements for Phase 0-1 launch that didn't exist in v1.

---

## 10.6 Content Workflow & Ownership

### 10.6.1 Content Sprint Plan (Phase 0)

**Week 1: Migration & Adaptation (2 days)**
- Day 1: Copy high-quality content from v1 to v2 structure
- Day 2: Adapt content for new IA and platform

**Week 2: New Content Creation (3 days)**
- Day 1: SEO metadata (titles, descriptions, OG tags)
- Day 2: System copy (errors, empty states, form validation)
- Day 3: Legal pages (use generators + review)

**Total Effort:** 5 days (1 content strategist + 1 copywriter)

---

### 10.6.2 Content Approval Workflow

```
Draft → Review (Founders) → Revisions → Final Approval → CMS Upload → QA
```

**Stakeholders:**
- **Content Owner:** Klara Hermesz (brand voice, pedagogical accuracy)
- **Business Owner:** Adam Kovacs (strategic positioning, B2B messaging)
- **Technical Owner:** Developer (CMS integration, dynamic data)
- **Legal Review:** External counsel (Privacy Policy, Terms only)

---

### 10.6.3 Content Management System

**Phase 0:** Static content in Next.js components (no CMS)

**Phase 1:** Consider CMS for dynamic content (courses, cohorts, testimonials)

**Recommendation:** Defer CMS decision until Phase 1. Use Convex database + Next.js components for now.

---

## 10.7 Brand Voice & Tone Guidelines

**Source:** `/research and data/academy-export/Glossary/Brand & Visual Guidelines.md`

### 10.7.1 Core Voice Attributes

**Primary Attributes (Always Present):**
- ✅ **Clarity:** Simple language, avoid jargon
- ✅ **Transformation:** Focus on outcomes, not features
- ✅ **Trust:** Authoritative, evidence-based, professional
- ✅ **Empowerment:** Enable action, not just awareness

**Secondary Attributes (Context-Dependent):**
- ✅ **Innovation:** Forward-thinking but grounded
- ✅ **Accessibility:** Inclusive, not elitist
- ✅ **Results-Oriented:** Business outcomes matter

---

### 10.7.2 Tone by Context

**Marketing Pages (Homepage, Pricing):**
- Confident, inspiring, action-oriented
- "Stop tinkering. Start building."

**Educational Pages (Course Outlines):**
- Clear, structured, outcome-focused
- "You'll walk away with..."

**Support Pages (FAQ, Contact):**
- Helpful, patient, reassuring
- "We're here to help."

**Transactional Pages (Checkout, Confirmation):**
- Clear, trustworthy, celebratory
- "Welcome to the cohort!"

---

## 10.8 Visual Content Requirements

### 10.8.1 Photography Needs

**Existing Assets (Confirmed Available):**
- ✅ Founder photos (Klara Hermesz, Adam Kovacs)
- ✅ Testimonial photos (9 learners with headshots)
- ✅ Hero instructor image
- ✅ Peer avatar images (3 learners)

**New Photography NEEDED:**
- [ ] Course thumbnail images (2 images for Foundations/Essentials)
- [ ] Open Graph social sharing images (5 images at 1200x630px)
- [ ] Cohort environment photos (if available, optional)
- [ ] Instructor teaching photos (if available, optional)

**Budget Estimate:** $500-1,000 (if using stock photos) or $0 (if using existing Cohort 1 photos)

---

### 10.8.2 Iconography

**Source:** Brand guidelines specify prism icon system

**Icons NEEDED:**
- [ ] Navigation icons (Home, Courses, Pricing, About, Contact)
- [ ] Feature icons (Live Cohort, Office Hours, Materials, Certificate)
- [ ] Social media icons (LinkedIn, Twitter/X, YouTube)
- [ ] Status icons (Upcoming, In Progress, Completed)

**Design System:** Use shadcn/ui icon library (Lucide) + custom prism icon

---

### 10.8.3 Brand Graphics

**Existing Assets (Confirmed Available):**
- ✅ Prism logo (triangle with spectrum rays)
- ✅ Color palette (Deep Blue #1565C0, Light Blue #42A5F5, etc.)
- ✅ Typography system (DM Sans, IBM Plex Sans)
- ✅ Company logos (Meta, Uber, AWS - if permission secured)

**New Graphics NEEDED:**
- [ ] 404 error page illustration
- [ ] Empty state illustrations (3-5 states)
- [ ] Loading animations (optional)
- [ ] Success/confirmation animations (optional)

---

## 10.9 Accessibility & Inclusive Language

### 10.9.1 WCAG 2.1 AA Compliance

**Content Requirements:**
- [ ] Alt text for all images (descriptive, <125 characters)
- [ ] Link text that makes sense out of context (no "click here")
- [ ] Headings in logical hierarchy (H1 → H2 → H3)
- [ ] Plain language (Flesch-Kincaid Grade Level 8-10)
- [ ] Contrast ratio 4.5:1 minimum for body text

---

### 10.9.2 Inclusive Language Guidelines

**Avoid:**
- ❌ Gendered pronouns when role-agnostic
- ❌ Ableist metaphors ("blind spot", "turn a deaf ear")
- ❌ Cultural assumptions (Western-centric examples)
- ❌ Jargon without explanation

**Use:**
- ✅ "They/their" for singular unknown gender
- ✅ "Overlook" instead of "blind spot"
- ✅ Global examples and diverse names
- ✅ Plain language or define technical terms

---

## 10.10 Content Maintenance Plan

### 10.10.1 Regular Updates Required

**Monthly:**
- [ ] Cohort dates and availability
- [ ] Testimonials rotation (if new feedback available)

**Quarterly:**
- [ ] Instructor stats (total learners trained, NPS score)
- [ ] Course outlines (if curriculum changes)
- [ ] Pricing (if strategy changes)

**Annually:**
- [ ] Legal pages (Privacy Policy, Terms of Service)
- [ ] About page (company achievements)

---

### 10.10.2 Content Audit Schedule

**Every 6 months:**
- Review all marketing copy for accuracy
- Update testimonials with recent cohort feedback
- Refresh SEO metadata based on search performance
- Audit forms and error messages for usability

---

## 10.11 Content Localization (Future)

**Phase 0:** English only (US market)

**Future Phases (Phase 3+):**
- Consider localization for international expansion
- Priority markets: Canada, UK, Australia (English-speaking first)
- Future markets: EMEA (Spanish, German, French), APAC (Mandarin, Japanese)

**Content to Localize:**
- Marketing pages (homepage, course pages, pricing)
- Email templates
- UI labels and error messages
- Legal pages (country-specific compliance)

**Content NOT to Localize:**
- Testimonials (keep in original language with translations)
- Founder bios (English primary, translated secondary)

---

## 10.12 Recommendation: Phase 0 Content Readiness

### ✅ GO Decision: Phase 0 Can Proceed

**Rationale:**
1. **70% content exists** and is high-quality (testimonials, course outlines, value prop)
2. **30% net-new content** is standard platform requirement (SEO, errors, legal)
3. **5-day content sprint** is feasible to fill gaps
4. **No content blockers** prevent development from starting

**Action Plan:**
1. **Immediately:** Assign content strategist to migrate v1 content (2 days)
2. **Week 1:** Copywriter creates net-new system copy (3 days)
3. **Week 2:** Legal counsel reviews generated legal pages (1 day)
4. **Week 2:** Final QA and CMS upload (1 day)

**Risk Mitigation:**
- Use content placeholders in development ("Lorem ipsum" replaced with real copy by Week 2)
- Prioritize P0 content (homepage, course pages, SEO) over P1 (email templates, error messages)
- Defer P2 content (video trailers, case studies) to Phase 1

---

## 10.13 Content Strategy Summary

| Content Category | v1 Reuse | New Creation | Total Effort |
|-----------------|----------|--------------|--------------|
| Marketing pages | 70% | 30% | 2 days |
| SEO metadata | 0% | 100% | 1 day |
| System copy | 0% | 100% | 1 day |
| Legal pages | 0% | 100% | 1 day |
| **TOTAL** | **~50%** | **~50%** | **5 days** |

**Budget:**
- Content strategist: $1,500 (2 days @ $750/day)
- Copywriter: $2,250 (3 days @ $750/day)
- Legal review: $500 (1 hour @ $500/hour, legal page generators)
- Total: **$4,250**

**Timeline:** 2 weeks (parallel with development)

**Risk Level:** 🟢 LOW - Content is not a blocker for Phase 0 launch.

---

## 10.14 Content Deliverables Checklist

### Phase 0 (Marketing Landing Page)
- [ ] Homepage copy (hero, testimonials, CTAs)
- [ ] Course catalog page copy
- [ ] 2x course detail pages (Foundations, Essentials)
- [ ] Pricing page copy
- [ ] About page copy
- [ ] Contact page copy
- [ ] FAQ page copy
- [ ] SEO metadata (6 pages x titles + descriptions)
- [ ] Open Graph tags (6 pages x images + tags)
- [ ] Structured data (organization + 2 courses)
- [ ] Error messages (30 messages)
- [ ] Empty states (10 states)
- [ ] Form validation messages (20 messages)
- [ ] Privacy Policy (2,000 words)
- [ ] Terms of Service (3,000 words)
- [ ] Cookie Policy (1,000 words)

### Phase 1 (Live Cohort MVP)
- [ ] Email templates (10 templates - see PRD Section 6.2)
- [ ] Dashboard empty states
- [ ] Learner portal navigation labels
- [ ] Success/confirmation messages
- [ ] Onboarding instructions

### Phase 2+ (Post-Cohort Engagement)
- [ ] Office hours booking copy
- [ ] Certificate display messaging
- [ ] Community forum guidelines
- [ ] Knowledge chatbot initial prompts

---

**Document Version:** 1.0
**Last Updated:** 2025-12-03
**Status:** ✅ APPROVED FOR PHASE 0 EXECUTION
**Next Review:** After Phase 0 launch (content performance analysis)
