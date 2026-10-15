# UI Design Guidelines (on-demand)

On-demand reference for UI/UX design reviews of **custom UI embedded into forms** — PCF controls, web
resources, HTML/JS components. Not for form layout itself: form-configuration questions go to
[`form-configuration-best-practices.md`](../../../../shared/dv/agent/wiki/sop/model-driven-apps/form-configuration-best-practices.md) first.

When designing or reviewing PCF controls, web resources, or custom UI components, consult these resources:

**Always read before making custom-UI recommendations:**
- Visual standards: [`pcf-theming-and-styling-best-practices.md`](../../../../shared/dv/agent/wiki/sop/pcf-controls/pcf-theming-and-styling-best-practices.md) — TESTED native Dataverse styling values, Fluent UI v9 tokens, Drawer/Dialog portal fix
- Accessibility: [`pcf-accessibility-i18n-and-security-best-practices.md`](../../../../shared/dv/agent/wiki/sop/pcf-controls/pcf-accessibility-i18n-and-security-best-practices.md) — WCAG 2.1 AA, the three Dataverse `DateTimeBehavior` modes
- PCF umbrella + foundational rules: [`pcf-control-development.md`](../../../../shared/dv/agent/wiki/sop/pcf-controls/pcf-control-development.md)

## Core Design Areas

- Microsoft Fluent UI design principles and component library
- Dynamics 365 Customer Engagement visual language and patterns
- PCF control styling best practices
- Web resource UI implementation standards
- Accessibility requirements (WCAG 2.1 AA compliance)
- Responsive design for Dynamics 365 forms and views
- Color systems, typography, spacing, and iconography

## UI Review Checklist

### Visual Consistency
- Colors match Dynamics 365 theme variables
- Typography uses Segoe UI with correct sizes
- Spacing follows 4px/8px grid system
- Icons use Fluent UI icon set
- Border radii match platform standards (2-4px)

### Component Patterns
- Buttons follow Dynamics 365 hierarchy (primary, secondary, tertiary)
- Form fields match native input styling
- Dropdowns and lookups follow platform patterns
- Grids and lists match Dynamics 365 view styling
- Loading states use appropriate spinners/skeletons
- Error states follow platform error messaging patterns

### Accessibility
- Color contrast meets WCAG 2.1 AA (4.5:1 for text)
- Focus indicators are visible
- Interactive elements are keyboard accessible
- ARIA labels are properly implemented
- Screen reader compatibility verified

### Responsiveness
- Components adapt to form factor changes
- Touch targets meet minimum 44x44px requirement
- Layouts work in side panels and pop-ups

### Integration
- Control respects Dynamics 365 theme customizations
- Dark mode compatibility (if applicable)
- Proper use of CSS custom properties for theming
- No style conflicts with platform CSS

## UI Review Response Structure

```markdown
## Summary
[Brief assessment of UI compliance]

## Findings
### Strengths
[What aligns well with Dynamics 365 patterns]

### Issues
[Specific UI problems with severity levels]

## Recommendations
[Actionable improvements with code examples]

## References
[Links to relevant guidelines or documentation]
```

## Output Standards

- Be specific: Provide exact values (e.g., "#0078D4 for primary actions")
- Show examples: Include CSS/styled component code snippets
- Reference guidelines: Cite sections from the PCF theming/accessibility SOPs above
- Consider context: Tailor recommendations to specific control/resource type
