# Feature 020: Mobile-first base stylesheet

**Status:** Approved
**Version:** 1.2.1
**Created:** 2026-11-25
**Last Updated:** 2026-11-25
**Issue:** #20
**Branch:** `web/20-base-stylesheet`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-25 | First draft |
| 1.1.0 | 2026-11-25 | Changed after the first independent review.<br>• Interaction states get their own tokens and documented pairs, and tricks that dodge the contrast proof (`opacity`, `filter`, `color-mix()`) are banned.<br>• The action area is in the page flow and sticks to the bottom; the header scrolls away. Focus rule is WCAG 2.4.11 ("not entirely hidden") with one scroll-padding token.<br>• The gap rule is scoped to separate controls. Power colors appear on the style guide only inside badges, and a single badge helper is the one way to render one.<br>• Every AC now has a verification row. Checks that need a phone are marked as owed to the maintainer, not claimed.<br>• The style guide shows static variants only, with no measured ratios, so no parser ships in production code.<br>• Reflow is checked at 320 pixels, and the layout is designed for 360 and up.<br>• Hue is measured in HSL on the final hex values, as a circular distance. The color-detection rules are made complete and the root view's own `main` is removed |
| 1.2.0 | 2026-11-25 | Changed after the second independent review.<br>• Power pairs are shown on the style guide through the badges only.<br>• The "tokens only" rule gets a narrow, stated exemption, and the focus ring gets tokens.<br>• The forbidden-words check scans a fixed set of paths and file names, and exempts `docs/specs/`.<br>• `opacity`, `filter`, `mix-blend-mode` and `color-mix()` are banned outright.<br>• Pressed states change shape as well as fill, and every state has a stated treatment.<br>• The keyboard-open claim is removed from AC-3.9. The helper accepts a symbol or a string.<br>• Markup conventions are shown on the style guide only, with no form builder.<br>• The phone pass gets a tracking Issue. Smaller fixes to limits, wording and Verification |
| 1.2.1 | 2026-11-25 | Approved at Gate A. While planning: AC-2.8 allows the single declaration `opacity: 1`, since Firefox dims placeholder text by default and no other way cancels it. The phone-pass Issue is #71 |

## Problem Statement

The playtest has to beat paper, and a cramped or fiddly phone screen won't. Players hold a phone at a table, often with one hand, in dim light, while others talk. Every screen from #21 onwards (create game, join, order entry, reveal) needs somewhere to start: a shared look, shared sizes and one place where the colors live. Without it each screen invents its own, and contrast and tap-size mistakes get repeated. The generated app has an empty stylesheet and a bare placeholder page.

## Goals

- A plain-CSS base stylesheet, served through Propshaft with no build step, that lays out a single-column phone screen: a header, scrolling main content and a bottom action area that stays in view.
- One set of design tokens (CSS custom properties) for color, type, spacing and target size. Later screens use the tokens and never write raw colors or sizes.
- An original palette in which every documented foreground/background pair meets WCAG 2.2 AA contrast, with a plain RSpec unit spec that computes the ratios from the stylesheet itself.
- Buttons, lists and form controls whose tap targets are at least 44 by 44 CSS pixels.
- Seven distinct, original power colors, each shown only together with the power's name.
- A development-only `/styleguide` page that shows every component, as the visual check for this work and for later changes to it.

## Non-Goals

- Any game screen. Create game, join, seat, order entry and reveal are #21 onwards.
- Dark mode (see Out of Scope for the argument).
- Web fonts, icon fonts, icons, logos or artwork. System fonts only.
- JavaScript. The stylesheet needs none, and nothing here adds a Stimulus controller.
- Styles for modals, sheets, toasts, tabs or a flash banner. They come with the first screen that needs one, and are built so a Hotwire Native path configuration can route them later.
- A good two-column-of-buttons layout below 360 CSS pixels. At 320 the page must not scroll sideways or lose content (AC-3.1), and nothing more is promised.
- A new gem, a Node tool, Tailwind or any CSS preprocessor.

## Users and Context

**Primary users:** Players at a physical board, entering secret orders on their own phones.
**Secondary users:** The host, who uses the same screens plus host controls. Developers and agents building later screens, who consume the tokens and components.
**Usage context:** A phone held in one hand, portrait, indoors, often in dim light. The browser may be Mobile Safari, Chrome on Android, or later the web view inside a Hotwire Native app, where a native bar may already supply a title.
**User mental model:** Big, obvious, tappable things. Readable at arm's length. A power is known by its name first and its color second.

## User Stories

### Story 1: Comfortable reading and tapping

**As a** player
**I want** text I can read and controls I can hit without zooming or mis-tapping
**So that** I can enter orders quickly while the table is talking

**Acceptance criteria:**

- [ ] **AC-1.1** Given any page that uses the layout When it is shown at a width of 360 CSS pixels Then body text is at least 16 CSS pixels and no text on the page is smaller than 14 CSS pixels
- [ ] **AC-1.2** Given the `/styleguide` page When every button, link styled as a button, header app-name link, tappable list row, text field, select, text area, checkbox row and radio row is measured at widths of 360 and 768 CSS pixels Then each one's tappable area is at least 44 by 44 CSS pixels. (Links inside running text are exempt.)
- [ ] **AC-1.3** Given two separate controls (buttons, links styled as buttons, fields) that sit next to each other or one above the other When they are measured Then the gap between their tappable areas is at least 8 CSS pixels. (Rows of one list, and rows of one group of choices, touch each other on purpose, and each is at least 44 pixels tall.)
- [ ] **AC-1.4** Given a text field, select or text area When it is focused on a phone Then its text size is at least 16 CSS pixels, so Mobile Safari does not zoom the page
- [ ] **AC-1.5** Given a person who has set a larger text size in the browser or the system When the page is shown Then the text grows with it, because no font size in the stylesheets is written in `px` (including inside the `font` shorthand) and no root font size is set
- [ ] **AC-1.6** Given a touch device When a button, link styled as a button or tappable list row is tapped Then it shows a visible pressed state (a different fill and a thicker border, see FR-6), and a double tap on it does not zoom the page. Pinch zoom of the page still works

### Story 2: Contrast that holds up

**As a** player with low vision, or anyone reading in poor light
**I want** text and control edges that stand out from what is behind them
**So that** I never have to guess what a label says or where a button ends

**Acceptance criteria:**

- [ ] **AC-2.1** Given the stylesheet's color tokens When the contrast spec computes the WCAG contrast ratio of each documented text pair in the table under FR-3 Then every ratio, compared unrounded, is at least 4.5
- [ ] **AC-2.2** Given the same spec When it computes the ratio of each documented non-text pair (control boundaries, focus ring, power colors against their backgrounds) Then every ratio, compared unrounded, is at least 3
- [ ] **AC-2.3** Given a color token is added to the token file that no documented pair uses, or a documented pair names a token that does not exist When the contrast spec runs Then it fails and names the token
- [ ] **AC-2.4** Given a color written in any form (hex of any length, `rgb()`, `rgba()`, `hsl()`, `hsla()`, `hwb()`, `lab()`, `lch()`, `oklab()`, `oklch()`, `color()`, `color-mix()`, a named color or a system color) in the value of any declaration outside the token file When the contrast spec runs Then it fails and names the file and line. (`transparent`, `currentColor` and `inherit` are allowed. Comments are not scanned)
- [ ] **AC-2.5** Given a custom property in the stylesheets whose value is a color, and that is not named `--color-*` or is not in the token file When the contrast spec runs Then it fails and names it
- [ ] **AC-2.6** Given a documented pair whose colors are changed so the ratio falls below its threshold When the contrast spec runs Then it fails and prints the pair, the ratio and the threshold
- [ ] **AC-2.7** Given an error message, a required marker or a disabled control When it is shown Then its state is carried by words or shape as well as color (for example the words "Error:" or "Required"), so a person who cannot tell the colors apart still gets it
- [ ] **AC-2.8** Given the stylesheets When they are scanned Then `opacity`, `filter`, `mix-blend-mode` and `color-mix()` appear nowhere, since they would make a computed ratio untrue and nothing in this work needs them. The one allowed form is `opacity: 1`, which only cancels a browser's own dimming (Firefox dims placeholder text)

### Story 3: A layout that fits a phone

**As a** player
**I want** a title at the top, my content in the middle and the main action always within thumb reach at the bottom
**So that** I never scroll to find the button that sends my orders

**Acceptance criteria:**

- [ ] **AC-3.1** Given a page with a header, main content and an action area When it is shown at 320, 360, 390, 768 and 1024 CSS pixels wide Then it is one column, the page never scrolls sideways, and no content is cut off
- [ ] **AC-3.2** Given main content taller than the screen and a viewport at least 30rem tall When the page is scrolled to any position Then the action area stays at the bottom edge of the viewport and its buttons stay fully visible
- [ ] **AC-3.3** Given main content taller than the screen When the page is scrolled to the end Then the last line of main content can be scrolled fully clear of the action area
- [ ] **AC-3.4** Given main content shorter than the screen When the page is shown Then the action area sits at the bottom of the viewport, not directly under the content
- [ ] **AC-3.5** Given a phone with a bottom home indicator or a notch When the page is shown in portrait or landscape Then the header, content and action area keep clear of the unsafe edges
- [ ] **AC-3.6** Given keyboard focus moves into a control inside main content When the browser scrolls it into view Then the control is not entirely hidden behind the action area, with the action area at its height for one row of buttons
- [ ] **AC-3.7** Given a page that provides no action area When it is shown Then no empty bar and no reserved space appears at the bottom
- [ ] **AC-3.8** Given a viewport wider than 40rem When the page is shown Then header text, content and action buttons line up in one centered column no wider than 40rem
- [ ] **AC-3.9** Given a viewport shorter than 30rem (a phone in landscape) When the page is scrolled Then the action area no longer sticks and sits after the content, so it never takes more than a part of the screen. With short content it still sits at the bottom of the page (AC-3.4)
- [ ] **AC-3.10** Given main content taller than the screen When the page is scrolled Then the header scrolls out of view with the content

### Story 4: Powers named and colored

**As a** player
**I want** each power to have its own color that always comes with its name
**So that** I can tell powers apart at a glance, and nothing depends on seeing color

**Acceptance criteria:**

- [ ] **AC-4.1** Given the token file When its power color tokens are listed Then there is exactly one for each of `austria`, `england`, `france`, `germany`, `italy`, `russia` and `turkey`, named `--color-power-<identifier>`
- [ ] **AC-4.2** Given the seven power colors When their hues are computed in HSL from the final hex values Then the circular distance between any two is at least 25 degrees
- [ ] **AC-4.3** Given a view that needs a power badge When it renders one Then it does so through one helper, `power_badge(identifier)`, which accepts the identifier as a symbol or a string and prints the power's name as the badge text; and given an identifier that is not one of the seven, or none, Then it raises `ArgumentError` rather than render a badge
- [ ] **AC-4.4** Given the stylesheets When they are searched for `--color-power-` references outside the token definitions Then they occur only in the power badge rules
- [ ] **AC-4.5** Given the `/styleguide` page When it shows power badges Then there is one for each of the seven powers, each with its name and its token name beside it, and none without a name
- [ ] **AC-4.6** Given the plan When it is read Then it records the starting hue, the method, the alphabetical assignment, any tuning and the final values, and states that no edition of the game was consulted

### Story 5: A visual check and a menu of parts

**As a** developer or agent building the next screen
**I want** one page that shows every component, with its tokens
**So that** I can reuse a part rather than invent one, and see at once if a change breaks one

**Acceptance criteria:**

- [ ] **AC-5.1** Given the app running in the development or test environment When `GET /styleguide` is requested Then it responds with 200, and the page has one named section for each component of FR-6 (button, link, list, field, choice, power badge, heading and text), each showing its static variants (default, each variant, disabled, invalid, where the component has them)
- [ ] **AC-5.2** Given the app running in the production environment When `GET /styleguide` is requested Then it responds with 404
- [ ] **AC-5.3** Given the layout and the root page When their links and navigation are read Then none leads to `/styleguide`
- [ ] **AC-5.4** Given the `/styleguide` page When it is shown Then it shows each color token other than the power tokens as a labelled swatch, each documented pair other than the power pairs (which the seven badges stand for) as a sample of its foreground on its background, with the two token names and the minimum ratio, and the type scale and spacing scale
- [ ] **AC-5.5** Given the `/styleguide` page When it is read Then it contains only text written for this page, with none from the game's rulebook

### Story 6: Plain, original and light

**As a** maintainer
**I want** the stylesheet to carry nothing from the game's publisher and nothing I must build or install
**So that** the project's licenses and the trademark rules hold, and a self-hoster can run it as is

**Acceptance criteria:**

- [ ] **AC-6.1** Given the stylesheet files When they are inspected Then they are plain CSS files in the app's stylesheet folder, served by Propshaft, and no step turns other files into them
- [ ] **AC-6.2** Given the stylesheet files When they are searched for `@font-face`, `@import` and `url(` Then there are none
- [ ] **AC-6.3** Given a page with the layout When it is loaded Then the browser makes no request for a font file, and every stylesheet request is for a file served by this app
- [ ] **AC-6.4** Given the Gemfile and the importmap When they are compared with `main` Then they have no new gem and no new pin, and the app has no Node file
- [ ] **AC-6.5** Given the contents and the file names under `app/`, `lib/` and `spec/` (other than the spec that holds the search pattern) and the contents of `config/routes.rb` When they are searched without regard to case for `diplomacy` or a word that starts with `dip` Then there are no matches. (`docs/specs/` is exempt by name, since the spec and plan must be free to discuss the rule)
- [ ] **AC-6.6** Given the root page When `GET /` is requested Then it responds with 200, its own content (its `h1` and its sentence) is unchanged, it contains a single `main` landmark supplied by the layout, and it renders inside the new layout

## Functional Requirements

### FR-1: Delivery

The styles are plain modern CSS files in `app/assets/stylesheets/`, linked by the layout's existing `stylesheet_link_tag :app`.

**Must:**
- Work with Propshaft alone: no preprocessor, no bundler, no Node, no new gem.
- Keep the cascade order independent of file names and load order.
- Use only CSS features that MDN lists as Baseline "widely available", and list in the plan each feature used. This keeps the same stylesheet working in a Hotwire Native web view.
- Weigh at most 24 KB in total, uncompressed, with every file in the folder counted, the style guide's own rules included. Those ship to production too, so they stay under 4 KB of that total.
- Set `lang="en"`, the viewport meta tag and `viewport-fit=cover` in the layout, so the stylesheet can use the unsafe-area insets.

**Must not:**
- Use `@import`, `url(`, web fonts, JavaScript or inline `style` attributes.
- Use `!important`, other than in one documented place if the plan can show it is needed.

### FR-2: Tokens

All values that may repeat live in CSS custom properties on `:root`, in one file that holds only tokens.

| Group | Tokens |
|---|---|
| Color | `--color-page`, `--color-surface`, `--color-text`, `--color-text-muted`, `--color-border`, `--color-link`, `--color-link-visited`, `--color-primary`, `--color-primary-pressed`, `--color-on-primary`, `--color-danger`, `--color-danger-pressed`, `--color-on-danger`, `--color-focus`, `--color-disabled-text`, `--color-disabled-fill`, `--color-on-power`, and `--color-power-<identifier>` for the seven powers |
| Type | `--font-sans`, `--text-sm`, `--text-base`, `--text-lg`, `--text-xl`, `--text-2xl`, `--leading-tight`, `--leading-normal`, `--weight-regular`, `--weight-strong` |
| Spacing | `--space-1` to `--space-8` (0.25, 0.5, 0.75, 1, 1.5, 2, 3 and 4 rem), `--gutter` |
| Sizing | `--tap-min` (at least 44 CSS pixels at any root font size, for example `max(44px, 2.75rem)`), `--content-max` (`40rem`), `--radius`, `--border-width`, `--focus-width` (at least 2 pixels), `--focus-offset`, `--scroll-pad` (the room kept clear below a scrolled-to control for the action area, including the bottom safe-area inset) |

Where each color is used:

| Token | Used for |
|---|---|
| `page` | Page background |
| `surface` | Header, action area, list rows, fields, secondary button fill, badges' surroundings |
| `text` | Body text, headings, the label on a secondary button |
| `text-muted` | Hints, placeholder text, secondary text |
| `border` | Edge of a field, a secondary button, a list row |
| `link`, `link-visited` | Links in running text |
| `primary`, `primary-pressed`, `on-primary` | Primary button fill, its pressed and hover fill, and its label |
| `danger`, `danger-pressed`, `on-danger` | Error text and an invalid field's edge; danger button fill, its pressed and hover fill, and its label |
| `focus` | Focus ring |
| `disabled-fill`, `disabled-text` | A disabled control |
| `power-<id>`, `on-power` | A power badge's fill and name |

Treatments that need no color of their own:

- A secondary button's pressed and hover state uses `page` as its fill, and a tappable list row's does too. Rows rest on `surface`.
- `page` and `surface` differ, and each resting fill differs from its pressed fill. The contrast spec checks that the values differ.
- Every pressed state also thickens the border to twice `--border-width`, so pressing is visible by shape as well as fill.
- Link hover thickens the underline.
- The header's app-name link uses `text`, is underlined only on hover and focus, and is at least `--tap-min` high.
- A disabled control's border uses `disabled-text`.

**Must:**
- Define the font stack as system fonts only, with `system-ui` first and a generic `sans-serif` last.
- Define the type scale in `rem`, with `--text-base` at `1rem` and no step smaller than `0.875rem`.
- Write each color token as a six-digit hex value with no transparency, so that every contrast ratio is exact and no blending is involved.

**Must not:**
- Write a raw color, a raw font stack, a raw font size or a raw spacing value outside the token file. Rules read tokens only. Exempt are media query conditions (custom properties cannot be used there), `0`, percentages and layout fractions. Only the color and font-size rules are tested (AC-2.4, AC-1.5). The rest is a review check.
- Hold a color in a custom property that is not a `--color-*` token in the token file (AC-2.5).

### FR-3: Palette and contrast

The light palette is original (FR-9). The contrast spec parses the token file and checks these documented pairs. Thresholds follow WCAG 2.2: 4.5 for text, 3 for graphics and control boundaries. No pair here uses the large-text threshold, so nothing relies on it.

| Pair (foreground on background) | Use | Min |
|---|---|---|
| `text` on `page`, on `surface` | Body text, secondary button label | 4.5 |
| `text-muted` on `page`, on `surface` | Hints, placeholders, secondary text | 4.5 |
| `link` on `page`, on `surface` | Links in running text | 4.5 |
| `link-visited` on `page`, on `surface` | Visited links | 4.5 |
| `on-primary` on `primary`, on `primary-pressed` | Label of a primary button | 4.5 |
| `primary` and `primary-pressed` against `page`, against `surface` | Edge of a filled button | 3 |
| `border` against `page`, against `surface` | Edge of a field, a secondary button, a list row | 3 |
| `danger` on `page`, on `surface` | Error text | 4.5 |
| `on-danger` on `danger`, on `danger-pressed` | Label of a danger button | 4.5 |
| `danger` and `danger-pressed` against `page`, against `surface` | Edge of a danger button or an invalid field | 3 |
| `focus` against `page`, against `surface` | Focus ring | 3 |
| `disabled-text` on `disabled-fill` | Label of a disabled control | 3 |
| `on-power` on each `power-<identifier>` | A power's name in its badge | 4.5 |
| each `power-<identifier>` against `page`, against `surface` | A power badge's edge | 3 |

A secondary button's label in its pressed state is `text` on `page`, which the first row already covers. WCAG exempts disabled controls from contrast rules. The 3 on the disabled pair is a house rule so a disabled label can still be read.

**Must:**
- Compute relative luminance and the contrast ratio as WCAG 2.2 defines them, and compare the ratio unrounded (so 4.49 fails). Anything that displays a ratio rounds it down.
- Take the ratios from the stylesheet files themselves, never from a copy of the values.
- Hold its own list of expected pairs that matches the table above, so removing a pair from the code does not pass silently.
- Check every one of the pairs above, and fail on any color token that no pair uses, and on any pair that names a token that is missing (AC-2.3).
- Run as a plain RSpec unit spec that needs no browser and no Rails boot beyond what loading the file requires.

**Must not:**
- Treat a pair as passing because it was passing once. Each run recomputes.
- Use `opacity` (other than `opacity: 1`), `filter`, `mix-blend-mode` or `color-mix()` anywhere (AC-2.8). Disabled and pressed states change the token, never the opacity.

### FR-4: Power colors

**Must:**
- Provide one color token per power, named from the identifiers in `adjudicator/docs/interface.md`: `austria`, `england`, `france`, `germany`, `italy`, `russia`, `turkey`.
- Show a power's color only as the fill of a power badge that holds the power's name as text.
- Render a badge only through the helper `power_badge(identifier)`, which takes an identifier from those seven, as a symbol or a string, and prints the name for it from a list of seven names written in the helper. A later issue replaces that list with the names the gem's map returns, once the app pins the gem. A missing or unknown identifier raises `ArgumentError`.
- Keep the seven colors at least 25 degrees apart in hue, measured as a circular distance in HSL on the final hex values.
- Accept that one light `on-power` color over seven dark fills puts all seven in a narrow band of darkness, so they differ chiefly by hue. This is acceptable because the name is always printed with the color.

**Must not:**
- Use a power color as a plain text color, as a line, a dot or a map marker on its own, or as a button color.
- Use any color to say which power is which without the name beside it.

### FR-5: Layout

The layout file gives every page the same frame: a header, a main area and an optional action area.

**Must:**
- Show the app name in the header, as a link to the root page, in a size no larger than `--text-lg`. The header scrolls away with the page and does not stick.
- Render a page's `content_for :actions`, when present, in an action area at the bottom, and render nothing when it is absent (AC-3.7).
- Put the action area in the page flow, after main, and keep it stuck to the bottom of the viewport while the page scrolls, as long as the viewport is at least 30rem tall (AC-3.2). Below that height it flows after the content (AC-3.9).
- Make the page at least one viewport high, so a short page puts the action area at the bottom (AC-3.4).
- Keep a scroll-padding at the bottom of the page of `--scroll-pad`, sized for one row of buttons, so a control scrolled to is not entirely hidden (AC-3.6). If the area stacks into more rows, a control may sit partly behind it. That is allowed, since WCAG 2.4.11 asks only that it is not entirely hidden.
- Keep content clear of the unsafe edges (AC-3.5).
- Hold content to `--content-max` and center it, while the header and action area backgrounds run edge to edge.
- Let up to two buttons share a row equally in the action area, in the order the page gives them. A single button, and any button that no longer fits beside another, takes the full width. Every button stays at least `--tap-min` high.

**Must not:**
- Rely on a fixed header height, a fixed action area height, or `vh` alone for the page height.
- Hide the header or action area with the stylesheet. A later native wrapper decides that (see Out of Scope).
- Make main the scroll container. The page itself scrolls, so Turbo's scroll restoration and a native web view keep working.

### FR-6: Components

Each component has a plain class name and a state for every case in the table. All of them use tokens only.

| Component | Variants and states |
|---|---|
| Button | primary (default), secondary, danger; hover (only where hover exists), pressed, focus-visible, disabled. Works on `button`, `a` and `input[type=submit]`. Disabled is the `disabled` attribute, or `aria-disabled="true"` on a link |
| Link | in running text: underlined, color `link`; visited, hover, focus-visible |
| List | a stack of rows, each with a visible boundary; rows that can be tapped fill the whole row as the target; plain rows show text only |
| Field | label above the control, optional hint, optional error; text, email, number and search inputs, select, text area |
| Choice | checkbox and radio, each with its label inside the tappable row |
| Power badge | one per power, text is the name |
| Heading and text | `h1` to `h3`, body, muted, small |

**Must:**
- Make a tap target at least `--tap-min` high and wide (AC-1.2), with at least `--space-2` between separate controls (AC-1.3).
- Draw a real border on buttons and fields, so they stay visible when the system forces its own colors (Windows high contrast).
- Show a visible keyboard focus ring (`:focus-visible`) of at least 2 pixels, in `--color-focus`, with an offset, and never remove the outline without replacing it.
- Show an invalid field with a changed border, with error text under the field that starts with the word "Error:", and tie the error text to the field in the markup (`aria-describedby` or the Rails equivalent) so it does not rely on color (AC-2.7).
- Show a disabled control with a visibly different fill and text color, from tokens, and make it ignore pointer events. A disabled link also has no `href`, or has `tabindex="-1"`, since pointer rules do not stop keyboard use.
- Give every pressed state a different fill and a border twice `--border-width` thick (see FR-2).
- Leave form markup conventions (the "Error:" prefix, `aria-describedby`, the "Required" marker, `aria-disabled`) as patterns shown on the style guide. #20 ships no form builder or form helper, and AC-2.7 is reviewed on that page.
- Keep any transition under 150 ms, and switch transitions off when the person asks for less motion.
- Apply hover styles only where the device can hover.
- Suppress double-tap zoom on controls only (`touch-action: manipulation`), and leave pinch zoom of the page alone.

**Must not:**
- Use a placeholder as the only label.
- Put a control's meaning in color alone (AC-2.7).
- Use an icon, image, background image or icon font for any component.

### FR-7: The style guide

`GET /styleguide` shows the tokens and every component from FR-6 in its static variants. The root placeholder page stays a plain placeholder that #21 will replace, and is not used as the showcase. It does lose its own `main` element, which the layout now supplies, and keeps its `h1` and its sentence.

**Must:**
- Respond 404 in production (AC-5.2). How the route is hidden is a plan matter, and the plan must say how a spec exercises it.
- Render inside the same layout as every other page, so it shows the real header and one action area holding two buttons. The plan decides how the other arrangements (one button, a stack) are exercised during measurement, for example by editing the page in the browser.
- Show every color token other than the power tokens as a swatch with its name; show every documented pair other than the power pairs as a sample of its foreground on its background with the two token names and the minimum ratio, copied from the table above (a third hand copy, after the table and the contrast spec; the request spec asserts the sample count, so a dropped sample is caught); show the type scale and the spacing scale; and show each power badge through `power_badge`, with its token name beside it.
- Show static variants only: default, each variant, disabled and invalid. Hover, pressed and focus-visible are checked in a real browser (see Verification).
- Contain only text written from scratch for this page.

**Must not:**
- Be linked from the layout, the root page, or any page a player sees.
- Show measured contrast ratios, or hold any code that reads or measures the stylesheets. The contrast spec owns the numbers.
- Be a game screen of any kind.

The root page is not the showcase because it will be rewritten by #21, and the visual check must outlast it. A separate page also lets one place show states that never appear together (disabled, invalid).

### FR-8: Accessibility behavior

**Must:**
- Meet WCAG 2.2 AA where a stylesheet can: contrast (1.4.3, 1.4.11), use of color (1.4.1), resize text (1.4.4), reflow at 320 pixels (1.4.10), focus visible (2.4.7), focus not obscured (2.4.11) and target size (2.5.8, which asks for 24 pixels; this app asks for 44).
- Give links in running text an underline, so they are not found by color alone.
- Keep text selectable and zoomable. The viewport tag does not set `user-scalable=no` or a maximum scale.
- Leave landmarks (`header`, `main`) to the layout, so each page has them once.

**Must not:**
- Prevent zooming.
- Remove focus outlines.

### FR-9: Originality

**Must:**
- Choose the seven power colors by one reproducible method of the app's own: spread seven hues evenly around the HSL color wheel, from a starting hue picked for this app, and assign them in alphabetical order of the power identifiers. Lightness and saturation are then set by hand so each fill meets its documented ratios with one light `on-power` color. Tuning may move lightness and saturation, and may move a hue by at most 5 degrees. The plan records the method as numbers, with the starting hue, the tuning and the final hex values, with no script unless one is justified.
- Choose the neutral and accent colors from the app's own aim (warm light page, cool dark text), not from any edition.
- State in the plan that no edition of the game was consulted.

**Must not:**
- Sample, trace, match by eye or look up the colors, fonts, board or artwork of any edition of the game.
- Pick a power's color because it resembles the color its piece has in a printed edition. The alphabetical assignment is the point: it is arbitrary on purpose.

If a maintainer objects to a result, the remedy is one rotation of the starting hue by half a step, recorded in the plan, and not a comparison against an edition.

## Non-Functional Requirements

### Performance

- Total stylesheet weight at most 24 KB uncompressed (FR-1).
- No font, image or script request is caused by the stylesheets.
- No layout shift caused by the stylesheet after first paint: no late-loading font, no image sizes to fix.

### Security

- No inline `style` attributes or `<style>` elements, so a strict content security policy can be turned on later without edits.
- `/styleguide` answers 404 in production, so the internet-facing instance gains no page from this work (`docs/architecture.md`, "Hosting"). Its rules ship to production, but are inert there.

### Reliability

- Without JavaScript the layout and every component still work.
- Where a CSS feature is unknown (`dvh`, `env()`), a one-line fallback (`vh`, zero) gives a usable layout.
- The contrast spec runs in the normal `bundle exec rspec` run and in CI (#18).

### Maintainability

- A new color is one token plus one documented pair, or the contrast spec fails.
- A new component uses tokens only, and is added to `/styleguide` in the same pull request.

## Verification

Each acceptance criterion has at least one row.

| AC | How | Runs |
|---|---|---|
| 2.1 to 2.6, 2.8 | Plain RSpec unit spec that parses the stylesheets and computes WCAG ratios; scans declaration values for color forms and banned properties | Every `bundle exec rspec` |
| 1.5 | The same kind of spec: no `px` font size and no root font size in the stylesheets | Every `bundle exec rspec` |
| 1.4, 1.6 (the static parts), 3.5 (the static part) | The same kind of spec: field text size at least `1rem`, `touch-action: manipulation` on controls, `env(safe-area-inset-*)` and `viewport-fit=cover` present | Every `bundle exec rspec` |
| 4.1, 4.2, 4.4, 6.2, 6.5 and the 24 KB limit | The same kind of spec on the stylesheet text and the files the pull request adds | Every `bundle exec rspec` |
| 4.3, 4.5, 5.1, 5.3, 5.4, 6.6, 3.7 | RSpec helper and request specs: the helper's output and its error, the style guide's named sections, the absence of links, the root page's content and landmark, and a page without an action area | Every `bundle exec rspec` |
| 5.2 | A request spec for the production case, by the mechanism the plan names | Every `bundle exec rspec` |
| 6.4 | The pull request's diff against `main` for the Gemfile, the importmap and any Node file | Review |
| 2.7, 4.6, 5.5, 6.1 | Review of the markup, the plan and the style guide copy against the criterion | Review |
| 1.1, 1.2, 1.3, 3.1, 3.2, 3.3, 3.4, 3.6, 3.8, 3.9, 3.10, 6.3 | A repeatable measurement in real Chrome at 320, 360, 390, 768 and 1024 pixels wide (and one short viewport), plus a keyboard pass and the network panel, with screenshots at 360 and 768 pixels. The measurement is a written procedure and a console snippet kept in the spec folder (not app JavaScript), and its results are recorded in the pull request | Before the pull request is ready |
| Pressed, hover, focus ring, forced colors, reduced motion | The same Chrome session, using its state and media emulation | Before the pull request is ready |
| 1.4 (zoom), 1.6 (touch), 3.5 (real insets), 3.2 (dynamic toolbar) | One pass on a real iPhone in Mobile Safari. No phone is available to the agent, so this is **owed to the maintainer** and is named as such in the pull request. Issue #71 tracks it and lists AC-1.4, 1.6, 3.2 and 3.5, and the pull request names it. Those four boxes stay unticked until #71 closes | Before the playtest |

The repository's Gemfile has no browser-driving gem, so the geometry checks cannot run in the normal spec run without a new test dependency (such as Capybara with a Selenium driver). The plan does not add one. Whether to add one is raised with the maintainer as a separate choice, and this spec is written so that doing so later turns the Chrome row into automated specs without changing any requirement.

## Error Scenarios

| Scenario | Expected Behavior |
|----------|-------------------|
| A browser does not know `dvh` | The page uses `vh`, and the layout still holds, only with the action area possibly under a browser bar until the bar hides |
| A device reports no safe-area insets | Those insets count as zero |
| A person sets the system text size very large | Text grows, controls grow with their text, nothing is clipped, and the page scrolls vertically only |
| A page puts more buttons in the action area than fit side by side | Buttons stack in the order given, and each stays full width and at least 44 pixels tall |
| The viewport is shorter than 30rem | The action area stops sticking and follows the content (AC-3.9) |
| The on-screen keyboard is open | The browser does not shrink the layout viewport, so the action area may be covered by the keyboard. Nothing requires it to stay visible |
| A person navigates with a keyboard | Every control shows a focus ring, and none is entirely hidden behind the action area |
| The system asks for forced colors | Borders and text stay visible because they are real borders and text, not fills alone |
| The system asks for reduced motion | No transition runs |
| A color token is added without a documented pair | The contrast spec fails and names it |
| A pair falls below its threshold | The contrast spec fails and prints the pair, ratio and threshold |
| A color is written outside the token file | The contrast spec fails and names the file and line |
| `power_badge` gets an unknown or missing identifier | It raises an error, and no badge is rendered |
| A request for `/styleguide` in production | 404 |
| The stylesheet is blocked or fails to load | The page is still readable and usable as plain, unstyled HTML, since no content comes from CSS |

## Open Questions

None. The decisions already made, for the record:

- **Style guide or root page:** a `/styleguide` page, development and test only (FR-7).
- **Dark mode:** out of scope (below).
- **Browser-driven specs:** no new dependency in this work; measurement in real Chrome, recorded in the pull request, and a phone pass owed to the maintainer (Verification).
- **Action area:** in the page flow and sticky, with a header that scrolls away (FR-5).

## Out of Scope (Future Considerations)

- **Dark mode (`prefers-color-scheme`).** The Issue allows it only if cheap. It is not. The palette tokens would split in two, so the documented pairs would need a second set, and the seven power colors would need a second set that also holds 4.5 against a dark badge text and 3 against a dark page. The contrast spec, the style guide and the screenshots would all double. The table is played in rooms where a phone may sit in a bright or a dim place, but the playtest has no evidence that either needs a dark theme. Because every color is a token and every pair is documented, adding dark mode later is an additive change with a contained blast radius. The stylesheet states `color-scheme: light` so browsers do not darken form controls on their own and mix themes.
- Styles for modal, sheet, tab, toast and flash components, until the first screen needs one.
- A monospace token for join codes, until #21 needs one.
- Hiding the header or action area in a Hotwire Native wrapper, which a path configuration can decide later. The layout keeps them as separate, named regions so a later rule can target them.
- Replacing the helper's seven hardcoded names with the gem's map names, once the app pins the gem.
- Automated browser specs for geometry (see Verification).
- Print styles, right-to-left layouts and translations.
