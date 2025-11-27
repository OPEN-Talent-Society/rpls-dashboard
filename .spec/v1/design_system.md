# Design System & UX Guidelines

## 1. Core Principles
*   **Data Density:** High. Economists need context. Avoid "whitespace for the sake of whitespace."
*   **Motion:** Purposeful.
    *   *Good:* Bars growing when data loads.
    *   *Bad:* Gratuitous page transitions that slow navigation.
*   **Typography:** Inter (Variable). Tabular figures (`font-feature-settings: "tnum"`) are mandatory for all numbers.

## 2. Component Specifications

### The Chart Card
- **Header:** Title (H3) + "Ask AI" Action.
- **Body:** LayerChart (SVG).
- **Footer:** Sparkline trend + Delta (e.g., "+5% YoY").
- **State:**
    - *Loading:* Gray Shimmer (matches chart shape).
    - *Error:* "Data Unavailable" with Retry button.
    - *Empty:* "No data for this filter."

### The Command Palette (Cmd+K)
- **Trigger:** `Cmd+K` or Search Icon in Navbar.
- **Input:** Natural Language enabled.
- **Sections:**
    - *Suggested:* "Show me Construction in TX"
    - *Filters:* "Sector...", "State..."
    - *History:* Last 3 queries.

### The Insight Panel (AI)
- **Appearance:** Glassmorphism sidebar or collapsible drawer.
- **Interaction:** Streaming text.
- **Citations:** `[1]`, `[2]` links that, when hovered, highlight data points on the main dashboard.

## 3. Accessibility Standards (WCAG 2.1 AA)
1.  **Color:** Minimum 4.5:1 contrast for text. Charts must use patterns + color (for colorblindness).
2.  **Keyboard:** All interactive elements (Charts, Filters) must be focusable via Tab.
3.  **Screen Readers:**
    - Charts must hide SVG (`aria-hidden="true"`) and expose a visually hidden table.
    - Status updates (AI Loading) must use `aria-live="polite"`.

## 4. Technology Choices
- **Icons:** Lucide-Svelte (Consistent stroke weight).
- **Charts:** LayerChart or Unovis (Svelte-native, D3-based).
- **Animation:** Svelte Transitions (`fly`, `fade`) + Motion One.
