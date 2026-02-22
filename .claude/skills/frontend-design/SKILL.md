---
name: frontend-design
description: "Design and implement distinctive, production-ready frontend interfaces with strong aesthetic direction. Use when asked to create or restyle web pages, components, or applications (HTML/CSS/JS, React, Vue, etc.)."
---

# Frontend Design Skill

Design and implement memorable frontend interfaces with a clear, intentional aesthetic. The output is real, working code — not mood boards. Every visual choice must be rooted in purpose and context. Avoid generic "AI slop" at all costs.

## When to Use

Use this skill when the user wants to:
- Create a new web page, landing page, dashboard, or app UI
- Design or redesign frontend components or screens
- Improve typography, layout, color, motion, or overall visual polish
- Convert a concept or brief into a high-fidelity, coded interface

## Inputs to Gather (or Assume)

Before coding, identify:
- **Purpose & audience**: What problem does this UI solve? Who uses it?
- **Brand/voice**: Any reference brands, tone, or visual inspiration?
- **Technical constraints**: Framework, library, CSS strategy, accessibility, performance
- **Content constraints**: Required copy, assets, data, features

If the user did not provide this, ask **2-4 targeted questions**, or state reasonable assumptions in a short preface.

## Design System Definition (Required)

Commit to a **single, bold aesthetic direction**. Name it. Execute it without compromise.

Draw from extremes — brutally minimal, maximalist chaos, retro-futuristic, organic/natural, luxury/refined, playful/toy-like, editorial/magazine, brutalist/raw, art deco/geometric, soft/pastel, industrial/utilitarian — or invent your own. Use these as jumping-off points, not templates. Bold maximalism and refined minimalism both work — the key is intentionality, not intensity.

Before writing any code, define all six:

1. **Visual direction** — one sentence that captures the vibe
2. **Differentiator** — what makes this UI unforgettable? The one thing someone remembers.
3. **Typography system** — display + body fonts, scale, weight, casing. Choose fonts that are beautiful and unexpected — not defaults you've seen a thousand times.
4. **Color system** — dominant, accent, neutral; define as CSS variables. Dominant colors with sharp accents outperform timid, evenly-distributed palettes.
5. **Layout strategy** — grid rhythm, spacing scale, hierarchy plan. Consider asymmetry, overlap, diagonal flow, grid-breaking elements.
6. **Motion strategy** — 1-2 high-impact interaction moments. One well-orchestrated page load with staggered reveals creates more delight than scattered micro-interactions.

If the user wants code only, skip the written explanation but still follow this process internally.

**Match implementation complexity to the vision.** Maximalist designs need elaborate code with extensive animations and effects. Minimalist designs need restraint, precision, and obsessive attention to spacing and typography. The code serves the concept.

## Implementation Principles

- **Working code**: HTML/CSS/JS or framework code that runs as-is
- **Semantic & accessible**: headings, labels, focus states, keyboard nav, `prefers-reduced-motion`
- **Responsive**: fluid layouts, breakpoints, responsive typography
- **Tokenized styling**: CSS variables for colors, spacing, radii, shadows
- **Modern layout**: CSS Grid/Flex, no brittle positioning hacks

## Aesthetic Guidelines

### Typography
- Typography defines the voice of the design — treat it as a first-class decision
- **Never** use default/overused fonts: Inter, Roboto, Arial, system stacks, Space Grotesk
- Pair a **distinct display font** with a **refined body font**
- Implement clear hierarchy through size, weight, spacing, and casing
- Vary choices across projects — never converge on the same fonts repeatedly

### Color & Theme
- Commit to a palette with a strong point-of-view
- Avoid timid, overused gradients (purple-to-pink on white is banned)
- Use contrast intentionally and verify legibility
- Vary between light and dark themes across projects

### Composition & Layout
- Unexpected layouts: asymmetry, overlap, diagonal flow, grid-breaking elements
- Use negative space deliberately (or controlled density if maximalist)
- Create visual rhythm and hierarchy through spacing and alignment
- Avoid cookie-cutter hero + 3 card layouts

### Detail & Atmosphere
- Create depth and atmosphere — never default to flat solid colors
- Techniques to draw from: gradient meshes, noise textures, geometric patterns, layered transparencies, dramatic shadows, decorative borders, grain overlays, custom cursors
- Use shadows/glows only when they serve the concept
- Consider unique borders, masks, or clip-paths for distinct shapes
- Match texture density to the aesthetic — brutalist gets raw, luxury gets subtle

### Motion & Interaction
- Prioritize CSS-only solutions for plain HTML
- Use Motion library (Framer Motion) for React when available
- Focus on high-impact moments: orchestrated page loads with staggered `animation-delay`, scroll-triggered reveals, hover states that surprise
- One standout interaction beats ten forgettable ones
- Honor `prefers-reduced-motion`

## Avoid

- Cookie-cutter hero + 3 card layouts
- Generic gradients and default font choices
- Unmotivated decorative elements
- Overly flat, characterless component library aesthetics
- Predictable layouts and component patterns
- Converging on the same choices across different projects

## Deliverables

- Full code with file names or component boundaries
- CSS variables or config objects for easy customization
- Inline SVGs or generative CSS patterns when assets are needed — no placeholder images

## Quality Checklist (Self-validate)

Before delivering, verify every point:

- [ ] Aesthetic direction is unmistakable — someone could name the vibe in one word
- [ ] Typography feels intentional and expressive, not default
- [ ] Layout and spacing are consistent and purposeful
- [ ] Color palette is cohesive, legible, and has a point-of-view
- [ ] Interactions enhance the experience without clutter
- [ ] Code runs as provided and is production-ready
- [ ] Design is distinct from your previous outputs — no recycled choices

**A design is only as strong as its commitment. Choose a direction and execute it without flinching.**
