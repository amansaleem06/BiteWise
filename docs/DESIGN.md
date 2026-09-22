# TasteWise Design System

Publish-ready spec for marketing, legal, and the Flutter app. Living examples:
[design-system.html](design-system.html). Tokens: [tokens.json](tokens.json).
Marketing: [index.html](index.html).

Brand: **TasteWise**. Tagline: **Discover. Taste. Share.**
Theme source: `lib/app/theme/` (maroon, cream, champagne, Fraunces, Source Sans 3).

## Principles

1. **Clarity.** One idea per surface. Type reads at arm’s length. Icons are tools.
2. **Deference.** The plate is the hero. Chrome is hairline, not shadow. No orange “food app” clichés.
3. **Depth.** Motion is 150 / 250 / 400ms. Sheets rise; toasts float. Honor `prefers-reduced-motion`.
4. **Continuity.** Light and dark are the same product. Interactive color is maroon in light, champagne in dark — matching `AppTheme`.

## Do

- Use Fraunces for display, headlines, and dish titles; Source Sans 3 for UI.
- Cap in-app content at 720px; marketing at 1120px on a 12-column grid.
- Space on an 8px grid (4px only for optical alignment).
- Buttons 54px, pill. Cards 28px radius, 0.5px outline, elevation 0.
- One primary button per view. Destructive actions use error red, not maroon.
- Visible labels on fields. Focus ring: cream halo + champagne/interactive ring.
- Champagne for stamps, stars, tab indicator, and focus — not body text on cream.

## Don’t

- Don’t introduce Inter, Segoe, or a foreign blue/orange for links.
- Don’t set `#B8956A` as small text on `#FDF8F1` (fails WCAG AA).
- Don’t put the brand gradient on every CTA — only the menu seal and the closing download band.
- Don’t add drop shadows to feed / plate cards.
- Don’t ship a new hex, radius, or type size without a token in `tokens.json`, CSS, and Dart.
- Don’t counterfeit Apple or Google store badge artwork.

## Foundations

| Token | Value | Flutter |
|---|---|---|
| Primary | `#4A0E0E` | `AppColors.primary` |
| Accent | `#B8956A` | `AppColors.accent` |
| Cream / canvas | `#FDF8F1` | `AppColors.cream` / `backgroundLight` |
| Ink | `#1A0C0C` | `AppColors.charcoal` |
| Dark canvas | `#140A0A` | `AppColors.backgroundDark` |
| Error / success / star | `#DC2626` / `#15803D` / `#EAB308` | `AppColors.error` / `success` / `ratingStar` |

**Contrast (approx.):** charcoal on cream 15.4:1 AAA; secondary `#6B5752` on cream 6.1:1 AA; cream on dark canvas 15.6:1 AAA. Accent on cream is decorative only.

**Type (9 levels):** display, headline, title, subtitle, body-lg, body, label, caption, overline. Web body is 16px. Responsive via `clamp()` in CSS.

**Grid:** 12 columns, 24px gutter, margins 16 / 24 / 48, max 1120px.

**Spacing:** 8, 16, 24, 32, 40, 48, 64, 80, 96, 128. Map Flutter `AppSpacing.xs…xxl`.

## Components

Thirty-seven components (button through form field group) with states, anatomy, usage, accessibility, and code are documented in [design-system.html](design-system.html). CSS classes live in `docs/assets/tastewise.css` (`tw-btn`, `tw-input`, `tw-chip`, `tw-card`, …). Flutter implements the same language through `ThemeData` in `app_theme.dart`.

## Patterns

- **Hero:** overline + display + lede + two CTAs + device.
- **Feed:** stories, cuisine chips, plate cards; chrome hides on reverse scroll.
- **Auth:** `AppStrings.welcomeTitle`; cream stage gradient.
- **Legal:** 720px column, shared nav, same tokens.
- **Async:** skeleton → empty + one CTA → error + retry.
- **Claim:** pending badge, calm copy, human approval.

## Developer guide

### Web (this folder)

```html
<link rel="stylesheet" href="assets/tastewise.css" />
<script src="assets/site.js" defer></script>
```

- Use CSS variables (`var(--color-interactive)`), never raw hex in page CSS.
- Theme: `data-theme="light|dark"` or omit for system. `site.js` persists the toggle.
- New component: add class in `tastewise.css`, document in `design-system.html`, add token if it introduces a size or color.

### Flutter

- Colors → `lib/app/theme/app_colors.dart`
- Type → `app_typography.dart` (Fraunces + Source Sans 3)
- Space / radius / duration → `app_spacing.dart`
- Theme assembly → `app_theme.dart`
- Do not hardcode `Color(0xFF…)` in features. If a value is missing, add it to `AppColors` and `tokens.json` together.

### Shipping the site

GitHub Pages serves `docs/`:

| Page | URL |
|---|---|
| Marketing | https://amansaleem06.github.io/BiteWise/ |
| Design system | https://amansaleem06.github.io/BiteWise/design-system.html |
| Privacy / terms / support | `privacy.html` / `terms.html` / `support.html` |

Keep legal copy in those HTML files; restyle only through `tastewise.css`.
