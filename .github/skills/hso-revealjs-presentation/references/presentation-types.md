# Presentation Types Reference

This document provides recommended structures for common HSO presentation types.

---

## 1. Solution Analysis / Recommendation

**Purpose:** Present options, compare approaches, and recommend a solution.

**Typical Duration:** 15-25 slides

**Recommended Size:** 1280x720

### Structure

| Slide # | Section | Purpose |
|---------|---------|---------|
| 1 | Title | Context, main title, date |
| 2-3 | Executive Summary | Key findings, recommendation preview |
| 4-5 | Current State | Existing systems, pain points |
| 6-8 | Requirements | Business needs, technical requirements |
| 9-12 | Option Analysis | Each option as a card with pros/cons |
| 13 | Comparison Table | Side-by-side feature comparison |
| 14 | Recommendation | Clear recommendation with rationale |
| 15 | Implementation Timeline | Phases, milestones |
| 16 | Investment Summary | Costs, ROI |
| 17 | Next Steps | Clear action items with dates |
| 18 | Appendix (optional) | Supporting details |

### Speaker Notes Guidance

- **Recommendation slides:** Emphasize confidence, use phrases like "based on our analysis" and "we recommend"
- **Comparison slides:** Be neutral but highlight differentiators
- **Cost slides:** Explain value proposition, not just numbers

---

## 2. Training / Workshop

**Purpose:** Teach users how to perform tasks in a system.

**Typical Duration:** 30-60 slides (broken into sessions)

**Recommended Size:** 1920x1080 (larger for screenshots)

### Structure

| Slide # | Section | Purpose |
|---------|---------|---------|
| 1 | Title | Training title, version date |
| 2 | Agenda | Overview of all sessions |
| 3-5 | Introduction | Context, why this matters |
| 6 | Session 1 Divider | Section break with description |
| 7-15 | Session 1 Content | Concepts, screenshots, workflows |
| 16 | Practice Scenario 1 | Hands-on exercise |
| 17 | Session 2 Divider | Section break |
| 18-30 | Session 2 Content | More advanced concepts |
| ... | Additional Sessions | Continue pattern |
| N-2 | Summary | Key takeaways |
| N-1 | Resources | Documentation links, support contacts |
| N | Q&A | Discussion slide |

### Key Elements

- **Screenshots:** Use `tango-screenshot` class, max height 520px
- **Step-by-step:** Use `step-num` numbered steps
- **Practice scenarios:** Include setup, task list, expected outcome
- **Workflows:** Visualize processes with `workflow` component

### Speaker Notes Guidance

- Include exact click paths for demos
- Note common mistakes to watch for
- Mention keyboard shortcuts
- Reference time estimates per section

---

## 3. Technical Architecture

**Purpose:** Document system design for technical stakeholders.

**Typical Duration:** 10-20 slides

**Recommended Size:** 1280x720 or 1920x1080 for complex diagrams

### Structure

| Slide # | Section | Purpose |
|---------|---------|---------|
| 1 | Title | Solution name, version |
| 2 | Overview | High-level architecture diagram |
| 3-4 | Components | Major system components |
| 5-7 | Data Flow | How data moves through system |
| 8-9 | Integrations | External systems, APIs |
| 10-11 | Security | Authentication, authorization |
| 12 | Performance | SLAs, scaling considerations |
| 13-14 | Deployment | Environments, pipelines |
| 15 | Monitoring | Logging, alerting |
| 16 | Technical Decisions | ADRs, key choices |

### Key Elements

- Heavy use of `diagram-box` components
- Custom CSS may be needed for complex diagrams
- Consider embedding external diagram tools (Mermaid, draw.io)

---

## 4. Project Status Update

**Purpose:** Brief stakeholders on project progress.

**Typical Duration:** 5-10 slides

**Recommended Size:** 1280x720

### Structure

| Slide # | Section | Purpose |
|---------|---------|---------|
| 1 | Title | Project name, reporting date |
| 2 | Executive Summary | RAG status, key metrics |
| 3 | Accomplishments | What was completed |
| 4 | In Progress | Current work |
| 5 | Upcoming | Next sprint/phase |
| 6 | Risks & Issues | Blockers, mitigations |
| 7 | Timeline | Updated schedule |
| 8 | Asks | What's needed from stakeholders |

### Key Elements

- Use `stat-box` for metrics (% complete, sprint velocity)
- Use badges for status: ✓ Done, ● In Progress, ○ Not Started
- RAG colors: var(--hso-teal) = Green, var(--hso-amber) = Amber, var(--hso-coral) = Red

---

## 5. Demo / Capability Showcase

**Purpose:** Demonstrate product capabilities to prospects or stakeholders.

**Typical Duration:** 15-25 slides

**Recommended Size:** 1920x1080 (larger for screenshots/demos)

### Structure

| Slide # | Section | Purpose |
|---------|---------|---------|
| 1 | Title | Product/capability name |
| 2 | Agenda | What will be shown |
| 3-4 | Context | Problem being solved |
| 5-6 | Demo 1 | First capability with screenshots |
| 7 | Value Statement | Why this matters |
| 8-10 | Demo 2 | Second capability |
| 11 | Value Statement | Benefits |
| ... | Additional Demos | Continue pattern |
| N-2 | Summary | Recap of capabilities |
| N-1 | Differentiators | Why choose this solution |
| N | Next Steps | How to proceed |

### Key Elements

- Large screenshots with callout annotations
- Quote boxes for customer testimonials
- Stat boxes for metrics and improvements

---

## Slide Count Guidelines

| Presentation Type | Min Slides | Max Slides | Time per Slide |
|-------------------|-----------|-----------|----------------|
| Solution Analysis | 12 | 25 | 2-3 min |
| Training | 25 | 60 | 2-5 min |
| Architecture | 8 | 20 | 3-5 min |
| Status Update | 5 | 10 | 1-2 min |
| Demo | 10 | 25 | 2-3 min |

---

## Universal Best Practices

### Opening Slides

1. Always include context line above title (client name, project)
2. Include date and HSO branding
3. Set expectations with clear agenda

### Content Slides

1. One main idea per slide
2. Maximum 5-6 bullet points
3. Use visuals over text when possible
4. Left-align body text for readability

### Closing Slides

1. Summarize key points (3-5 max)
2. Clear, actionable next steps with owners and dates
3. Include contact information or resources slide

### Speaker Notes

Every slide MUST have speaker notes containing:
- Key talking points (what to say, not what's on screen)
- Transition phrases to next slide
- Anticipated questions and answers
- Time estimates for longer sections
