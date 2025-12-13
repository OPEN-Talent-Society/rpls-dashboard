#!/bin/bash
# Index client documents to Qdrant collections
# Indexes: SOW/contracts, transcripts, communications, contacts, research
# Created: 2025-12-10

set -e

PROJECT_DIR="/Users/adamkovacs/Documents/codebuild"
source "$PROJECT_DIR/.env" 2>/dev/null || true

if [ -f "$PROJECT_DIR/.env" ]; then
    set -a; source "$PROJECT_DIR/.env"; set +a
fi

[ -z "$QDRANT_API_KEY" ] && { echo "QDRANT_API_KEY not set"; exit 1; }
[ -z "$GEMINI_API_KEY" ] && { echo "GEMINI_API_KEY not set"; exit 1; }

QDRANT_URL="${QDRANT_URL:-https://qdrant.harbor.fyi}"

echo "📁 Client Document Indexer"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔌 Qdrant: $QDRANT_URL"

# Get Gemini embedding
get_embedding() {
    local text="$1"
    local escaped_text=$(echo "$text" | jq -Rs '.')

    curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key=${GEMINI_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"models/gemini-embedding-001\",
            \"content\": {\"parts\": [{\"text\": $escaped_text}]},
            \"outputDimensionality\": 768
        }" | jq -c '.embedding.values // empty'
}

# Upsert to Qdrant
upsert_to_qdrant() {
    local collection="$1"
    local id="$2"
    local vector="$3"
    local payload="$4"

    local numeric_id=$(echo -n "$id" | md5sum | cut -c1-16)
    numeric_id=$((16#$numeric_id % 2147483647))

    curl -s -X PUT "${QDRANT_URL}/collections/${collection}/points" \
        -H "api-key: ${QDRANT_API_KEY}" \
        -H "Content-Type: application/json" \
        -d "{
            \"points\": [{
                \"id\": $numeric_id,
                \"vector\": $vector,
                \"payload\": $payload
            }]
        }" > /dev/null
}

# Ensure collections exist (768-dim for Gemini)
ensure_collection() {
    local collection="$1"

    # Check if collection exists
    EXISTS=$(curl -s "${QDRANT_URL}/collections/${collection}" \
        -H "api-key: ${QDRANT_API_KEY}" | jq -r '.result.status // "not_found"')

    if [ "$EXISTS" = "not_found" ] || [ "$EXISTS" = "null" ]; then
        echo "  📦 Creating collection: $collection"
        curl -s -X PUT "${QDRANT_URL}/collections/${collection}" \
            -H "api-key: ${QDRANT_API_KEY}" \
            -H "Content-Type: application/json" \
            -d '{
                "vectors": {
                    "size": 768,
                    "distance": "Cosine"
                }
            }' > /dev/null
    fi
}

TOTAL_INDEXED=0
NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# ============================================
# 1. INDEX TALABAT COMPANY RESEARCH
# ============================================
echo ""
echo "🏢 Indexing Talabat Company Research → research collection"

ensure_collection "research"

TALABAT_RESEARCH="Talabat Company Research - December 2025

COMPANY OVERVIEW:
- Name: Talabat (طلبات)
- Industry: On-demand delivery platform (food, grocery, Q-commerce)
- Parent: Delivery Hero SE (German multinational)
- Markets: 8 MENA countries (UAE, Kuwait, Bahrain, Oman, Qatar, Jordan, Iraq, Egypt)
- Employees: ~7,000 globally
- Website: talabat.com

RECENT MILESTONES:
- December 2024: IPO on Dubai Financial Market (DFM)
- Largest global tech IPO of 2024
- Market valuation post-IPO: ~\$10B+
- FY2024 Revenue: \$2.8 billion (est.)

BUSINESS MODEL:
- Food delivery from restaurants
- Grocery delivery (Talabat Mart)
- Quick commerce (q-commerce)
- Cloud kitchens
- Advertising platform for restaurants

TECHNOLOGY STACK:
- Using Google Gemini Enterprise for AI
- Sana AI as learning platform
- Smart Recruiters for ATS
- Exploring Worklytics for AI adoption measurement

AI ADOPTION INITIATIVES:
- Enterprise AI rollout across organization
- AI Champions program being developed
- Focus on shifting from 'learning about AI' to 'learning with AI'
- L&D team driving AI enablement
- Working with AI Enablement Academy for training

KEY CONTACTS:
- Eman El Koshairy: Senior Manager L&D (AI enablement champion)
- Location: Dubai, UAE (City Walk Mall headquarters)

COMPETITIVE LANDSCAPE:
- Competitors: Careem (Uber), noon, Amazon.ae, Deliveroo
- Market position: #1 in most MENA markets
- Differentiation: Local market expertise, q-commerce investment"

EMBEDDING=$(get_embedding "$TALABAT_RESEARCH")

if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
    PAYLOAD=$(jq -n \
        --arg type "company-research" \
        --arg source "web-research" \
        --arg content "$TALABAT_RESEARCH" \
        --arg indexed_at "$NOW" \
        --arg company "Talabat" \
        --arg industry "On-demand delivery" \
        --arg region "MENA" \
        --arg relationship "client" \
        '{
            type: $type,
            source: $source,
            content: $content,
            indexed_at: $indexed_at,
            version: 1,
            company: {
                name: $company,
                industry: $industry,
                region: $region,
                relationship: $relationship
            }
        }')

    upsert_to_qdrant "research" "talabat-company-research-2025" "$EMBEDDING" "$PAYLOAD"
    TOTAL_INDEXED=$((TOTAL_INDEXED + 1))
    echo "  ✅ Talabat research indexed"
fi

# ============================================
# 2. INDEX SOW/CONTRACT
# ============================================
echo ""
echo "📋 Indexing Talabat SOW → clients collection"

ensure_collection "clients"

SOW_CONTENT="TALABAT AI ENABLEMENT ACADEMY SOW - AEA-TLBT-2025-001

PARTIES:
- Provider: AI Enablement Academy LLC (Washington, USA)
- Client: Delivery Hero Talabat DB LLC (Dubai, UAE)

ENGAGEMENT SUMMARY:
- 2-day virtual AI Essentials cohort
- 20 Talent Acquisition / People Organization staff
- Pre-cohort customization + 3 weeks post-cohort support
- Goal: Establish safe, repeatable AI workflows for recruiting (sourcing, screening, outreach)
- Success Criteria: Participants demonstrate ability to execute documented AI-supported workflow

CURRICULUM:
Pre-Cohort: Intake & Audit
- Function-specific intake assessment
- Workflow audit for high-impact intervention points
- Personalized use case recommendations

Day 1: Deconstruction & Strategy
- Realities of AI at work
- The Builder Mindset
- Process Mapping Workshop (Design Thinking, Thin Slicing)
- Advanced Prompting Workshop & Prompting Lab

Day 2: Architecture & Deployment
- Talent Market / Workforce Intelligence Workshop
- Knowledge Management Workshop (NotebookLM, RAG)
- Customize the Tools Workshop (Google Gems)
- Mastermind & Capstone
- Project Presentation

POST-PROGRAM:
- 3 weeks Slack support
- 3x 1-hour virtual office hours
- 1-business day response time

POTENTIAL CAPSTONE PROTOTYPES:
- Outreach Personalizer
- JD Optimizer
- Interview Guide Creator
- Resume Screener

DELIVERABLES:
1. 2-day live virtual AI Essentials cohort (20 participants)
2. Pre-cohort intake analysis
3. Academy Enablement Kit Access
4. 3x office hour sessions
5. Slack support (3 weeks)
6. Executive Impact Report

COMMERCIAL TERMS:
- Total Fees: \$28,500 USD
- Deposit: 50% (\$14,250) upon signature
- Balance: 50% (\$14,250) 7 days prior to Day 1
- Payment: ACH, SWIFT Wire, Wise, or Stripe (+3% CC fee)

ASSUMPTIONS:
- Client provides Google Gemini, NotebookLM, Google Workspace access
- SOPs provided 5 business days before Day 1
- Washington State governing law

DATE: November 27, 2025
REFERENCE: AEA-TLBT-2025-001"

EMBEDDING=$(get_embedding "$SOW_CONTENT")

if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
    PAYLOAD=$(jq -n \
        --arg type "contract-sow" \
        --arg source "legal-document" \
        --arg content "$SOW_CONTENT" \
        --arg indexed_at "$NOW" \
        --arg client "Talabat" \
        --arg reference "AEA-TLBT-2025-001" \
        --arg value "28500" \
        --arg currency "USD" \
        --arg date "2025-11-27" \
        --arg service "AI Essentials Cohort" \
        '{
            type: $type,
            source: $source,
            content: $content,
            indexed_at: $indexed_at,
            version: 1,
            contract: {
                client: $client,
                reference: $reference,
                value: $value,
                currency: $currency,
                date: $date,
                service: $service
            }
        }')

    upsert_to_qdrant "clients" "talabat-sow-aea-tlbt-2025-001" "$EMBEDDING" "$PAYLOAD"
    TOTAL_INDEXED=$((TOTAL_INDEXED + 1))
    echo "  ✅ SOW indexed"
fi

# ============================================
# 3. INDEX OFFBEAT VIDEO TRANSCRIPTION
# ============================================
echo ""
echo "🎬 Indexing Eman Offbeat Presentation → transcripts collection"

ensure_collection "transcripts"

OFFBEAT_CONTENT="EMAN EL KOSHAIRY - OFFBEAT PRESENTATION: AI ADOPTION AT TALABAT

SPEAKER: Eman El Koshairy, Senior Manager L&D at Talabat
EVENT: Offbeat (AI adoption story sharing)

KEY THEMES:
1. Enterprise AI Adoption Journey
2. Five Assumptions That Changed My Mind About AI
3. Moving from 'Learning About AI' to 'Learning With AI'

FIVE KEY ASSUMPTIONS (that changed):

1. ASSUMPTION: Everyone uses AI the same way
   REALITY: Usage varies wildly - from skeptics to power users
   INSIGHT: Need tiered enablement approach

2. ASSUMPTION: AI adoption is about tools
   REALITY: It's about mindset and workflow integration
   INSIGHT: Focus on builder mindset, not just tool training

3. ASSUMPTION: Measuring AI adoption is straightforward
   REALITY: Traditional L&D metrics don't capture AI impact
   INSIGHT: Exploring Worklytics for behavior-based measurement

4. ASSUMPTION: One AI tool fits all
   REALITY: Different functions need different approaches
   INSIGHT: Function-specific enablement paths needed

5. ASSUMPTION: AI training is a one-time event
   REALITY: AI evolves rapidly, learning must be continuous
   INSIGHT: Embedded AI learning, not standalone courses

TOOLS & PLATFORMS MENTIONED:
- Sana AI: Learning platform with AI tutor capabilities
- Google Gemini: Enterprise AI assistant
- Worklytics: Measuring AI adoption through behavioral data
- NotebookLM: Knowledge management and RAG

AI CHAMPIONS PROGRAM:
- Building internal network of AI advocates
- Peer learning and support model
- Cross-functional collaboration

TALABAT AI JOURNEY:
- Started with pilot groups
- L&D team as early adopters
- Now scaling across Talent Acquisition
- Focus on practical, job-relevant use cases

LEARNING APPROACH:
- Shift from 'learning about AI' to 'learning with AI'
- Hands-on, project-based learning
- Real work, real outcomes
- Building functional prototypes

QUOTE: 'We're not just training people on AI tools - we're transforming how they think about work.'

EVENT DATE: 2025 (Q3/Q4)
LOCATION: Virtual presentation"

EMBEDDING=$(get_embedding "$OFFBEAT_CONTENT")

if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
    PAYLOAD=$(jq -n \
        --arg type "event-transcript" \
        --arg source "video-transcription" \
        --arg content "$OFFBEAT_CONTENT" \
        --arg indexed_at "$NOW" \
        --arg speaker "Eman El Koshairy" \
        --arg company "Talabat" \
        --arg event "Offbeat" \
        --arg topic "AI Adoption" \
        '{
            type: $type,
            source: $source,
            content: $content,
            indexed_at: $indexed_at,
            version: 1,
            transcript: {
                speaker: $speaker,
                company: $company,
                event: $event,
                topic: $topic
            }
        }')

    upsert_to_qdrant "transcripts" "eman-offbeat-ai-adoption-talabat" "$EMBEDDING" "$PAYLOAD"
    TOTAL_INDEXED=$((TOTAL_INDEXED + 1))
    echo "  ✅ Offbeat transcript indexed"
fi

# ============================================
# 4. INDEX ADAM-EMAN CALL TRANSCRIPT
# ============================================
echo ""
echo "📞 Indexing Adam-Eman Call → communications collection"

ensure_collection "communications"

CALL_CONTENT="ADAM KOVACS - EMAN EL KOSHAIRY FOLLOW-UP CALL TRANSCRIPT

PARTICIPANTS:
- Adam Kovacs: Co-founder, AI Enablement Academy
- Eman El Koshairy: Senior Manager L&D, Talabat

CONTEXT: Sales/discovery follow-up call discussing AI training engagement

KEY DISCUSSION POINTS:

1. COHORT STRUCTURE:
- Considering both Foundations (awareness) and Essentials (hands-on) tracks
- Essentials: 2-day intensive, hands-on building
- Foundations: Shorter, broader audience
- Decision: Start with Essentials for TA team (20 people)

2. TARGET AUDIENCE:
- Talent Acquisition team (primary)
- People Organization staff
- ~20 participants for first cohort

3. TOOLS DISCUSSION:
- Talabat uses Smart Recruiters as ATS
- Google Gemini Enterprise available
- NotebookLM for knowledge management
- Sana as learning platform

4. TIMING & LOGISTICS:
- Virtual delivery preferred
- Pre-cohort intake and customization
- Post-cohort support (3 weeks)
- Office hours for ongoing questions

5. USE CASES DISCUSSED:
- Candidate sourcing optimization
- Screening automation
- Personalized outreach
- JD optimization
- Interview guide creation

6. HACKATHON DISCUSSION:
- Potential future hackathon event
- Bring together multiple teams
- Competition format with judges
- Real business challenges

7. PRICING & PROPOSAL:
- Discussed modular approach
- Foundations vs Essentials pricing
- Value of hands-on builder approach
- ROI through time savings

8. SANA INTEGRATION:
- Eman mentioned Sana AI tutor capabilities
- Interest in NotebookLM for private RAG
- Custom chatbots (Google Gems) for workflows

9. NEXT STEPS:
- Adam to send updated proposal
- Eman to confirm participant list
- Schedule pre-cohort intake
- Align on dates

RELATIONSHIP CONTEXT:
- Warm, collaborative tone
- Eman is AI champion internally
- Multiple touchpoints before this call
- Building toward long-term partnership

CALL DATE: November 2025
DURATION: ~45 minutes"

EMBEDDING=$(get_embedding "$CALL_CONTENT")

if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
    PAYLOAD=$(jq -n \
        --arg type "call-transcript" \
        --arg source "sales-call" \
        --arg content "$CALL_CONTENT" \
        --arg indexed_at "$NOW" \
        --arg participants "Adam Kovacs, Eman El Koshairy" \
        --arg company "Talabat" \
        --arg purpose "Sales follow-up" \
        --arg outcome "Proposal sent" \
        '{
            type: $type,
            source: $source,
            content: $content,
            indexed_at: $indexed_at,
            version: 1,
            communication: {
                participants: $participants,
                company: $company,
                purpose: $purpose,
                outcome: $outcome
            }
        }')

    upsert_to_qdrant "communications" "adam-eman-talabat-call-nov2025" "$EMBEDDING" "$PAYLOAD"
    TOTAL_INDEXED=$((TOTAL_INDEXED + 1))
    echo "  ✅ Call transcript indexed"
fi

# ============================================
# 5. INDEX EMAN'S LINKEDIN PROFILE
# ============================================
echo ""
echo "👤 Indexing Eman LinkedIn Profile → contacts collection"

ensure_collection "contacts"

LINKEDIN_CONTENT="EMAN EL KOSHAIRY - LINKEDIN PROFILE

CURRENT ROLE:
Senior Manager, Learning & Development
Talabat (Delivery Hero)
October 2023 - Present
Dubai, UAE

PREVIOUS EXPERIENCE:

1. Careem (Uber subsidiary)
   - Learning & Development roles
   - Built learning programs for MENA operations

2. noon (Mahali Academy)
   - L&D leadership
   - E-commerce sector experience

3. AlMakinah (Co-founder)
   - Tech education startup
   - Teaching coding and technology skills
   - Entrepreneurial experience

EDUCATION:
- German University in Cairo (GUC)
  Computer Science / Engineering background

- Johannes Kepler Universität Linz, Austria
  Masters program
  International education experience

CERTIFICATIONS & SKILLS:
- ORSC Certified Coach (Organization & Relationship Systems Coaching)
- Learning & Development expertise
- AI adoption and enablement
- Instructional design
- Leadership development
- Change management

AREAS OF FOCUS:
- Enterprise AI adoption
- Learning experience design
- Building learning cultures
- Technology-enabled learning
- Coaching and development

PROFILE HIGHLIGHTS:
- Background in both tech (CS) and people (L&D)
- Entrepreneurial mindset (AlMakinah co-founder)
- International experience (Egypt, Austria, UAE)
- Passionate about AI transformation
- Systems coaching certification

NETWORK:
- Active in L&D community
- Speaker at industry events (Offbeat)
- Thought leader on AI in learning

CONTACT CONTEXT:
- Primary POC for Talabat engagement
- AI champion within organization
- Decision influencer for training investments
- Collaborative, forward-thinking approach

RELATIONSHIP TO AEA:
- Client contact for AI Essentials cohort
- Engaged in discovery and sales process
- Aligned on AI enablement vision
- Potential long-term partner"

EMBEDDING=$(get_embedding "$LINKEDIN_CONTENT")

if [ -n "$EMBEDDING" ] && [ "$EMBEDDING" != "null" ]; then
    PAYLOAD=$(jq -n \
        --arg type "contact-profile" \
        --arg source "linkedin" \
        --arg content "$LINKEDIN_CONTENT" \
        --arg indexed_at "$NOW" \
        --arg name "Eman El Koshairy" \
        --arg title "Senior Manager, Learning & Development" \
        --arg company "Talabat" \
        --arg location "Dubai, UAE" \
        --arg relationship "client-contact" \
        '{
            type: $type,
            source: $source,
            content: $content,
            indexed_at: $indexed_at,
            version: 1,
            contact: {
                name: $name,
                title: $title,
                company: $company,
                location: $location,
                relationship: $relationship
            }
        }')

    upsert_to_qdrant "contacts" "eman-elkoshairy-talabat-linkedin" "$EMBEDDING" "$PAYLOAD"
    TOTAL_INDEXED=$((TOTAL_INDEXED + 1))
    echo "  ✅ LinkedIn profile indexed"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Client document indexing complete"
echo "   Total indexed: $TOTAL_INDEXED documents"
echo ""
echo "📊 Collections updated:"
echo "   - research (Talabat company research)"
echo "   - clients (SOW/contract)"
echo "   - transcripts (Offbeat presentation)"
echo "   - communications (Adam-Eman call)"
echo "   - contacts (Eman LinkedIn profile)"
