# Feature 020: Mobile-first base stylesheet

**Status:** Approved (2.0.x approved at Gate A on 2026-11-26; 1.2.1 was approved and shipped by #20)
**Version:** 2.1.1
**Created:** 2026-11-25
**Last Updated:** 2026-11-26
**Issue:** #20, amended by #81
**Branch:** `web/20-base-stylesheet`, then `web/81-cold-war-theme`

---

## Changelog

| Version | Date | Change |
|---------|------|--------|
| 1.0.0 | 2026-11-25 | First draft |
| 1.1.0 | 2026-11-25 | Changed after the first independent review.<br>• Interaction states get their own tokens and documented pairs, and tricks that dodge the contrast proof (`opacity`, `filter`, `color-mix()`) are banned.<br>• The action area is in the page flow and sticks to the bottom; the header scrolls away. Focus rule is WCAG 2.4.11 ("not entirely hidden") with one scroll-padding token.<br>• The gap rule is scoped to separate controls. Power colors appear on the style guide only inside badges, and a single badge helper is the one way to render one.<br>• Every AC now has a verification row. Checks that need a phone are marked as owed to the maintainer, not claimed.<br>• The style guide shows static variants only, with no measured ratios, so no parser ships in production code.<br>• Reflow is checked at 320 pixels, and the layout is designed for 360 and up.<br>• Hue is measured in HSL on the final hex values, as a circular distance. The color-detection rules are made complete and the root view's own `main` is removed |
| 1.2.0 | 2026-11-25 | Changed after the second independent review.<br>• Power pairs are shown on the style guide through the badges only.<br>• The "tokens only" rule gets a narrow, stated exemption, and the focus ring gets tokens.<br>• The forbidden-words check scans a fixed set of paths and file names, and exempts `docs/specs/`.<br>• `opacity`, `filter`, `mix-blend-mode` and `color-mix()` are banned outright.<br>• Pressed states change shape as well as fill, and every state has a stated treatment.<br>• The keyboard-open claim is removed from AC-3.9. The helper accepts a symbol or a string.<br>• Markup conventions are shown on the style guide only, with no form builder.<br>• The phone pass gets a tracking Issue. Smaller fixes to limits, wording and Verification |
| 1.2.1 | 2026-11-25 | Approved at Gate A. While planning: AC-2.8 allows the single declaration `opacity: 1`, since Firefox dims placeholder text by default and no other way cancels it. The phone-pass Issue is #71 |
| 2.0.0 | 2026-11-26 | Amended by Issue #81 (the Cold War re-theme), a MAJOR change because it replaces FR-9 and reverses two shipped rules (no web fonts, no icons).<br>• **Palette (FR-2, FR-3, AC-2.x):** the #20 palette is replaced by the fixed Cold War values of decision 41; `ice`, `ice-pale` and `steel` are added, and the new pairs are documented. `ice` may only be a background (AC-2.9), and `on-power` must stay equal to the artwork's white (AC-2.10).<br>• **Power colors (FR-4, FR-9, AC-4.4, AC-4.5, AC-4.6, AC-5.4):** the even-spread method is replaced by seven fixed values (decision 42) that no one tunes by eye. AC-4.2's 25-degree rule stays. Power colors may also appear in the unit-icon and supply-center rules, including as the text and border of the power-initial tag.<br>• **Fonts and icons (Non-goals, AC-6.2, AC-6.3, FR-1, FR-6):** system fonts, plus exactly one `@font-face` whose `url()` points to a font file this app serves, and no request to a third party. The only icons are the two helpers' inline drawings.<br>• **New:** Story 7 (unit and supply-center icons, FR-10), Story 8 (the monospace, FR-11) and Story 9 (the design-system document, FR-12).<br>• **Also changed, and not in the Issue's list:**<br>– AC-1.1 exempts the initial inside a unit icon's drawing at 20 to 48 pixels, because it cannot be 14 pixels inside a 12-unit tag.<br>– The Issue's pairs (`text` on `ice`, `focus` on `ice`, `steel` on `page`) imply a header on `ice` with a `steel` rule; FR-2 says so.<br>– AC-5.1 gains three style-guide sections and FR-7 the matching content; AC-7.3 also rejects a bad `size`; the NFR on performance allows one font request and a `swap` re-set of `.mono` text; the Verification rows move the layout checks onto the system specs of #73 and add rows for the new ACs.<br>– The Out of Scope line about a monospace token for join codes is replaced by the later-Issue list, and the line about automated geometry specs is dropped, since #73 shipped them.<br>– AC-2.9 and AC-2.10 are new checks (`ice` is background only; `on-power` is the artwork's white; every palette value is held exactly), and AC-6.2 declares the font for a weight range so no bold is faked.<br>• Reviewed by a read-only Fable pass at Gate A (round 1: no blocking findings; 17 non-blocking, applied) |
| 2.0.1 | 2026-11-26 | Approved at Gate A. The rule for a visible name beside a unit icon under 24 pixels applies to this release's lists and screens only, and does not bind the future map (1.x), which settles its own labeling. Wording only (PATCH) |
| 2.0.2 | 2026-11-26 | Cites Issue #86 (the root change that adds `assets/icons/**` to the web workflow's paths) in the Error Scenarios. Wording only (PATCH) |
| 2.1.0 | 2026-11-26 | Amended by spec 022 (#22), approved at its Gate A. The total weight limit of FR-1 and the Performance section goes from 24 KB to 32 KB (32,768 bytes), and the style guide's share from 4 KB to 6 KB (6,144 bytes). Reason: the screen components the design-system catalog plans, which were not listed when 24 KB was set. `spec/styles/stylesheet_rules_spec.rb` enforces the new numbers |
| 2.1.1 | 2026-11-26 | Records the phone pass of Issue #71. The maintainer checked AC-1.4, AC-1.6, AC-3.2 and AC-3.5 on an iPhone in Mobile Safari, and all four passed, so their boxes are ticked. No behavior change (PATCH) |

## Problem Statement

The playtest has to beat paper, and a cramped or fiddly phone screen won't. Players hold a phone at a table, often with one hand, in dim light, while others talk. Every screen from #21 onwards (create game, join, order entry, reveal) needs somewhere to start: a shared look, shared sizes and one place where the colors live. Without it each screen invents its own, and contrast and tap-size mistakes get repeated. The generated app has an empty stylesheet and a bare placeholder page.

## Goals

- A plain-CSS base stylesheet, served through Propshaft with no build step, that lays out a single-column phone screen: a header, scrolling main content and a bottom action area that stays in view.
- One set of design tokens (CSS custom properties) for color, type, spacing and target size. Later screens use the tokens and never write raw colors or sizes.
- An original palette (the Cold War palette of the logo, fixed in FR-2) in which every documented foreground/background pair meets WCAG 2.2 AA contrast, with a plain RSpec unit spec that computes the ratios from the stylesheet itself.
- Buttons, lists and form controls whose tap targets are at least 44 by 44 CSS pixels.
- Seven distinct, original power colors, each shown only together with the power's name or initial.
- One army icon, one fleet icon and one supply-center icon, colored by power through two helpers, and one self-hosted monospace font for the few places that need it (Stories 7 and 8).
- `web/docs/design-system.md`, the catalog every later screen builds to (Story 9).
- A development-only `/styleguide` page that shows every component, as the visual check for this work and for later changes to it.

## Non-Goals

- Any game screen. Create game, join, seat, order entry and reveal are #21 onwards.
- Dark mode (see Out of Scope for the argument).
- Icon fonts, logos, board artwork, or any font or icon beyond these: the system fonts, the one self-hosted monospace (FR-11) and the army, fleet and supply-center drawings from `assets/icons/` (FR-10). Body text stays in the system sans. Every font and icon is served by this app, never by a third party.
- Glyphs for outcomes, seat states, banners and chrome (Issue #82), and any screen component of the catalog in `web/docs/design-system.md` other than the ones built here.
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

- [ ] **AC-1.1** Given any page that uses the layout When it is shown at a width of 360 CSS pixels Then body text is at least 16 CSS pixels and no text on the page is smaller than 14 CSS pixels. (One exemption: the initial inside a unit icon's drawing, at the sizes this app uses, 20 to 48 pixels. It is part of an image whose accessible name, or the visible label beside it, carries the full words, and it scales with the icon, so it cannot be 14 pixels inside a tag that is 12 of the icon's 32 units. See AC-7.5)
- [ ] **AC-1.2** Given the `/styleguide` page When every button, link styled as a button, header app-name link, tappable list row, text field, select, text area, checkbox row and radio row is measured at widths of 360 and 768 CSS pixels Then each one's tappable area is at least 44 by 44 CSS pixels. (Links inside running text are exempt.)
- [ ] **AC-1.3** Given two separate controls (buttons, links styled as buttons, fields) that sit next to each other or one above the other When they are measured Then the gap between their tappable areas is at least 8 CSS pixels. (Rows of one list, and rows of one group of choices, touch each other on purpose, and each is at least 44 pixels tall.)
- [x] **AC-1.4** Given a text field, select or text area When it is focused on a phone Then its text size is at least 16 CSS pixels, so Mobile Safari does not zoom the page
- [ ] **AC-1.5** Given a person who has set a larger text size in the browser or the system When the page is shown Then the text grows with it, because no font size in the stylesheets is written in `px` (including inside the `font` shorthand) and no root font size is set
- [x] **AC-1.6** Given a touch device When a button, link styled as a button or tappable list row is tapped Then it shows a visible pressed state (a different fill and a thicker border, see FR-6), and a double tap on it does not zoom the page. Pinch zoom of the page still works

### Story 2: Contrast that holds up

**As a** player with low vision, or anyone reading in poor light
**I want** text and control edges that stand out from what is behind them
**So that** I never have to guess what a label says or where a button ends

**Acceptance criteria:**

- [ ] **AC-2.1** Given the stylesheet's color tokens When the contrast spec computes the WCAG contrast ratio of each documented text pair in the table under FR-3 (including `text` on `ice` and on `ice-pale`, `text-muted` on `ice-pale`, and each power color as text on `surface`, which is how the power-initial tag is read) Then every ratio, compared unrounded, is at least 4.5
- [ ] **AC-2.2** Given the same spec When it computes the ratio of each documented non-text pair (control boundaries, focus ring on `page`, `surface` and `ice`, `steel` on `page` and on `surface`, power colors against `page`, `surface` and `ice-pale`) Then every ratio, compared unrounded, is at least 3
- [ ] **AC-2.3** Given a color token is added to the token file that no documented pair uses, or a documented pair names a token that does not exist When the contrast spec runs Then it fails and names the token
- [ ] **AC-2.4** Given a color written in any form (hex of any length, `rgb()`, `rgba()`, `hsl()`, `hsla()`, `hwb()`, `lab()`, `lch()`, `oklab()`, `oklch()`, `color()`, `color-mix()`, a named color or a system color) in the value of any declaration outside the token file When the contrast spec runs Then it fails and names the file and line. (`transparent`, `currentColor` and `inherit` are allowed. Comments are not scanned)
- [ ] **AC-2.5** Given a custom property in the stylesheets whose value is a color, and that is not named `--color-*` or is not in the token file When the contrast spec runs Then it fails and names it
- [ ] **AC-2.6** Given a documented pair whose colors are changed so the ratio falls below its threshold When the contrast spec runs Then it fails and prints the pair, the ratio and the threshold
- [ ] **AC-2.7** Given an error message, a required marker or a disabled control When it is shown Then its state is carried by words or shape as well as color (for example the words "Error:" or "Required"), so a person who cannot tell the colors apart still gets it
- [ ] **AC-2.8** Given the stylesheets When they are scanned Then `opacity`, `filter`, `mix-blend-mode` and `color-mix()` appear nowhere, since they would make a computed ratio untrue and nothing in this work needs them. The one allowed form is `opacity: 1`, which only cancels a browser's own dimming (Firefox dims placeholder text)
- [ ] **AC-2.9** Given the stylesheets When every declaration that reads `--color-ice` is listed Then each is a `background` or `background-color`. (`ice` is never text, never a control's edge, never a line. Its pairs are `text` and `focus` on it. `--color-ice-pale` is a different token and is not limited this way)
- [ ] **AC-2.10** Given the token file When `--color-on-power` is read Then it is `#ffffff`, the white the artwork's marks and unowned disk are drawn in (FR-10), so the white in a drawing and the `on-power` white cannot drift apart. And given the palette of FR-2 When the contrast spec reads the token file Then every value in the Color table of FR-2 and every power value of FR-9 is exactly as written there (the Cold War palette is fixed, and no one adjusts a value by eye)

### Story 3: A layout that fits a phone

**As a** player
**I want** a title at the top, my content in the middle and the main action always within thumb reach at the bottom
**So that** I never scroll to find the button that sends my orders

**Acceptance criteria:**

- [ ] **AC-3.1** Given a page with a header, main content and an action area When it is shown at 320, 360, 390, 768 and 1024 CSS pixels wide Then it is one column, the page never scrolls sideways, and no content is cut off
- [x] **AC-3.2** Given main content taller than the screen and a viewport at least 30rem tall When the page is scrolled to any position Then the action area stays at the bottom edge of the viewport and its buttons stay fully visible
- [ ] **AC-3.3** Given main content taller than the screen When the page is scrolled to the end Then the last line of main content can be scrolled fully clear of the action area
- [ ] **AC-3.4** Given main content shorter than the screen When the page is shown Then the action area sits at the bottom of the viewport, not directly under the content
- [x] **AC-3.5** Given a phone with a bottom home indicator or a notch When the page is shown in portrait or landscape Then the header, content and action area keep clear of the unsafe edges
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
- [ ] **AC-4.4** Given the stylesheets When they are searched for `--color-power-` references outside the token definitions Then they occur only in rules whose every selector is a power badge (`.power-badge--<id>`), a unit icon (`.unit-icon--<id>`) or a supply-center icon (`.supply-center-icon--<id>`) variant. Those rules may use a power color as the fill of the badge, of the unit's silhouette and of the owned supply center, and as the text and border of the power-initial tag, and nowhere else
- [ ] **AC-4.5** Given the `/styleguide` page When it shows power colors Then it does so only through the power badges (one for each of the seven powers, each with its name and its token name beside it, and none without a name), the unit section (AC-7.10) and the supply-center section (AC-7.10), and a power color appears on no other sample
- [ ] **AC-4.6** Given the plan (the version 2.0.0 phases in `plan.md` of this spec folder) and `web/docs/design-system.md` When they are read Then each records the seven final values, says they are the fixed values of decision 42 and that none was derived by a method or tuned, and says that no edition's colors, artwork or fonts were sampled, traced or looked up for them. And given the old derivation under "The palette" in `plan.md` and the comment at the top of `tokens.css` Then each is marked superseded by 2.0.0 (the plan) or rewritten (the comment), so no file still says the colors come from an even spread

### Story 5: A visual check and a menu of parts

**As a** developer or agent building the next screen
**I want** one page that shows every component, with its tokens
**So that** I can reuse a part rather than invent one, and see at once if a change breaks one

**Acceptance criteria:**

- [ ] **AC-5.1** Given the app running in the development or test environment When `GET /styleguide` is requested Then it responds with 200, and the page has one named section for each component of FR-6 (button, link, list, field, choice, power badge, heading and text, unit icon, supply-center icon, mono text), each showing its static variants (default, each variant, disabled, invalid, where the component has them)
- [ ] **AC-5.2** Given the app running in the production environment When `GET /styleguide` is requested Then it responds with 404
- [ ] **AC-5.3** Given the layout and the root page When their links and navigation are read Then none leads to `/styleguide`
- [ ] **AC-5.4** Given the `/styleguide` page When it is shown Then it shows each color token other than the power tokens as a labelled swatch, each documented pair other than the power pairs (which the badges, the unit section and the supply-center section stand for) as a sample of its foreground on its background, with the two token names and the minimum ratio, and the type scale and spacing scale
- [ ] **AC-5.5** Given the `/styleguide` page When it is read Then it contains only text written for this page, with none from the game's rulebook

### Story 6: Plain, original and light

**As a** maintainer
**I want** the stylesheet to carry nothing from the game's publisher and nothing I must build or install
**So that** the project's licenses and the trademark rules hold, and a self-hoster can run it as is

**Acceptance criteria:**

- [ ] **AC-6.1** Given the stylesheet files When they are inspected Then they are plain CSS files in the app's stylesheet folder, served by Propshaft, and no step turns other files into them
- [ ] **AC-6.2** Given the stylesheet files When they are searched for `@font-face`, `@import` and `url(` Then there is no `@import`, there is exactly one `@font-face` and exactly one `url(`, and that `url(` is inside the `@font-face` and points to the `.woff2` file in `app/assets/fonts/` by a path that names no scheme and no host (so it can only be served by this app). The `@font-face` sets `font-display: swap` and declares the one face for the weight range 400 to 700, so the browser never fakes a bold of a face that is Medium only
- [ ] **AC-6.3** Given a page with the layout When it is loaded Then every request the page makes (the page, stylesheets, scripts, the font) is to this app's own origin and none goes to a third party, and the only request for a font is the one `.woff2` file
- [ ] **AC-6.4** Given the Gemfile and the importmap When they are compared with `main` Then they have no new gem and no new pin, and the app has no Node file
- [ ] **AC-6.5** Given the contents and the file names under `app/`, `lib/` and `spec/` (other than the spec that holds the search pattern) and the contents of `config/routes.rb` When they are searched without regard to case for `diplomacy` or a word that starts with `dip` Then there are no matches. (`docs/specs/` is exempt by name, since the spec and plan must be free to discuss the rule)
- [ ] **AC-6.6** Given the root page When `GET /` is requested Then it responds with 200, its own content (its `h1` and its sentence) is unchanged, it contains a single `main` landmark supplied by the layout, and it renders inside the new layout

### Story 7: Units and supply centers that read at a glance (added in 2.0.0)

**As a** player
**I want** each unit to show its type and its power, and each supply center to show who owns it
**So that** I can tell my army from your fleet at arm's length, even where no name is printed and even if I cannot tell the colors apart

**Acceptance criteria:**

- [ ] **AC-7.1** Given `unit_icon(:austria, :army)` When it is rendered Then the output is one inline `<svg>` with `role="img"`, `aria-label="Army, Austria"`, `viewBox="0 0 32 32"`, `width` and `height` of 32, and the classes `unit-icon unit-icon--austria`; it holds no `url(`, `<style>`, `<image>`, `<script>`, `<title>` or `id` attribute (the artwork's part ids become part classes, so many icons on one page never repeat an id). The label is the type's word, a comma, then the power's name, for example "Fleet, England". The power and the type each accept a symbol or a string
- [ ] **AC-7.2** Given `decorative: true` When a unit icon or a supply-center icon is rendered Then it has `aria-hidden="true"` and no `role` and no `aria-label` (a visible label sits next to it), and is otherwise the same drawing
- [ ] **AC-7.3** Given a power that is not one of the seven or is missing, or a type that is not `army` or `fleet` (for example `:submarine`), or a size that is not an Integer above zero When `unit_icon` is called Then it raises `ArgumentError` and renders nothing. And given a supply-center owner that is not one of the seven (an empty string, say) or a size that is not an Integer above zero When `supply_center_icon` is called Then it raises `ArgumentError` too. (A `nil` owner is not an error: it means unowned, AC-7.6)
- [ ] **AC-7.4** Given a size under 24 When a unit icon is rendered Then it is drawn from the `-small` artwork (`army-small.svg` or `fleet-small.svg`), and from 24 up from the full artwork (`army.svg` or `fleet.svg`). A supply-center icon has one drawing for every size
- [ ] **AC-7.5** Given any unit icon at any size When it is rendered Then the bottom-right 12 by 12 units of the drawing hold the power-initial tag: a tile spanning x and y from 20 to 32 in `surface`, with a border drawn inside the tile at least 1.5 units wide (so about 1 pixel at size 20) in the power's color, and the power's initial in the power's color (A, E, F, G, I, R, T), written as `<text>` inside the tile, hidden from assistive technology (the label already says the words) and set in the monospace of FR-11. The text's size is an SVG `font-size` attribute in drawing units, so it scales with the icon and no stylesheet writes a `px` size. The tag is part of the drawing, so it works where no name is printed
- [ ] **AC-7.6** Given `supply_center_icon(nil)` When it is rendered Then it is an inline `<svg>` with `role="img"`, `aria-label="Supply center, unowned"`, `viewBox="0 0 32 32"`, `width` and `height` of 32 and the classes `supply-center-icon supply-center-icon--unowned`. Given `supply_center_icon(:italy)` Then its label is "Supply center, Italy" and its classes are `supply-center-icon supply-center-icon--italy`. The owner accepts a symbol or a string
- [ ] **AC-7.7** Given the icons shown in a real browser When their computed colors are read Then: the silhouette of a unit is filled with its power's color token and its marks are white; the tag's tile is filled with `surface` and bordered, and its initial filled, with the power's color token; an owned supply center's disk and edge are filled with the owner's color token and its center with `on-power`; an unowned one has a white disk and its edge and center are filled with `text`
- [ ] **AC-7.8** Given the views and helpers When they are searched for `<svg` Then it occurs only in the icon helper module's file and in no view, so the two helpers are the only way to draw these icons, as `power_badge` is for a badge
- [ ] **AC-7.9** Given the five drawings in `app/assets/images/icons/` and their masters in `assets/icons/` When the spec compares each pair byte for byte Then they are identical, there is no copy without a master and no master drawing without a copy, and a difference fails the spec naming the file. And given the app's code When it is searched Then nothing reads `assets/icons/` at run time (the Docker build context is `web/`, so only the copies exist there)
- [ ] **AC-7.10** Given the `/styleguide` page When its unit section is read Then it shows every power's army and fleet at 20, 32 and 48 pixels (42 icons, the 20 pixel row using the small drawings), each through `unit_icon`, with the power named beside each and one row of them on an `ice-pale` ground (so the power-on-`ice-pale` pairs of FR-3 are shown on something); and its supply-center section shows each of the seven owners and the unowned look, each through `supply_center_icon`, and names each power beside its icon

### Story 8: One monospace for the few places that need it (added in 2.0.0)

**As a** player
**I want** phase headers, join codes, province abbreviations and outcome tags in a face that keeps letters and digits evenly spaced
**So that** I can read a six-character code aloud, and a column of abbreviations lines up

**Acceptance criteria:**

- [ ] **AC-8.1** Given the token file When `--font-mono` is read Then it is `"Plex Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace`
- [ ] **AC-8.2** Given an element with the class `mono` When its computed font family is read in a real browser Then it starts with `Plex Mono`, and `document.fonts.load('1rem "Plex Mono"')` resolves with exactly one loaded face (so the file really loads); and given the stylesheets Then, in this version, `--font-mono` is read only by `.mono` and by the power-initial tag's rule. (Later components get the face by carrying the `mono` class in their markup, and do not read the token)
- [ ] **AC-8.3** Given `app/assets/fonts/` When it is listed Then it holds exactly one font file, a `.woff2` of IBM Plex Mono Medium cut down to the Latin subset, and the `OFL.txt` of the same release beside it. And given that file When its SHA-256 is computed Then it equals the one `web/NOTICE` records
- [ ] **AC-8.4** Given `web/NOTICE` When it is read Then it credits IBM Plex Mono (IBM Corp., SIL Open Font License 1.1) with the source URL, the release version and the file's SHA-256, and carries the CC BY-SA 4.0 notice for the inlined artwork from `assets/icons/`

### Story 9: One page that says how to build a screen (added in 2.0.0)

**As a** developer or agent building screens #21 to #28
**I want** one document with the palette, the type rules, the icon rules, the helpers and the component catalog
**So that** every screen builds shared parts to one plan instead of inventing its own

**Acceptance criteria:**

- [ ] **AC-9.1** Given `web/docs/design-system.md` When it is read Then it holds the palette with every value, the power colors, the type rules, the unit and supply-center rules, the helper rules, and the component catalog (what each screen Issue builds, with its class names and the Issue that builds it), as Issue #81 sets them out
- [ ] **AC-9.2** Given the token file and the document When the spec compares them Then every `--color-<name>` token in the token file appears in the document with its hex value on the same line, so the document cannot fall behind the tokens

## Functional Requirements

### FR-1: Delivery

The styles are plain modern CSS files in `app/assets/stylesheets/`, linked by the layout's existing `stylesheet_link_tag :app`.

**Must:**
- Work with Propshaft alone: no preprocessor, no bundler, no Node, no new gem.
- Keep the cascade order independent of file names and load order.
- Use only CSS features that MDN lists as Baseline "widely available", and list in the plan each feature used. This keeps the same stylesheet working in a Hotwire Native web view.
- Weigh at most 32 KB (32,768 bytes) in total, uncompressed, with every file in the folder counted, the style guide's own rules included. Those ship to production too, so they stay under 6 KB (6,144 bytes) of that total. (The limits were 24 KB and 4 KB until spec 022 raised them.) (The font file is not a stylesheet and is not counted.)
- Set `lang="en"`, the viewport meta tag and `viewport-fit=cover` in the layout, so the stylesheet can use the unsafe-area insets.

**Must not:**
- Use `@import`, a `url(` other than the one in the single `@font-face` (AC-6.2), a web font other than that one, JavaScript or inline `style` attributes.
- Use `!important`, other than in one documented place if the plan can show it is needed.

### FR-2: Tokens

All values that may repeat live in CSS custom properties on `:root`, in one file that holds only tokens.

| Group | Tokens |
|---|---|
| Color | `--color-page`, `--color-surface`, `--color-ice`, `--color-ice-pale`, `--color-steel`, `--color-text`, `--color-text-muted`, `--color-border`, `--color-link`, `--color-link-visited`, `--color-primary`, `--color-primary-pressed`, `--color-on-primary`, `--color-danger`, `--color-danger-pressed`, `--color-on-danger`, `--color-focus`, `--color-disabled-text`, `--color-disabled-fill`, `--color-on-power`, and `--color-power-<identifier>` for the seven powers |
| Type | `--font-sans`, `--font-mono`, `--text-sm`, `--text-base`, `--text-lg`, `--text-xl`, `--text-2xl`, `--leading-tight`, `--leading-normal`, `--weight-regular`, `--weight-strong` |
| Spacing | `--space-1` to `--space-8` (0.25, 0.5, 0.75, 1, 1.5, 2, 3 and 4 rem), `--gutter` |
| Sizing | `--tap-min` (at least 44 CSS pixels at any root font size, for example `max(44px, 2.75rem)`), `--content-max` (`40rem`), `--radius`, `--border-width`, `--focus-width` (at least 2 pixels), `--focus-offset`, `--scroll-pad` (the room kept clear below a scrolled-to control for the action area, including the bottom safe-area inset) |

The color values are fixed (decision 41, the Cold War palette of the logo) and are held exactly, not tuned (AC-2.10):

| Token | Value | Token | Value |
|---|---|---|---|
| `page` | `#eef3f6` | `primary-pressed` | `#2b4657` |
| `surface` | `#ffffff` | `danger` | `#9e2a22` |
| `ice` | `#a7c4d4` | `danger-pressed` | `#7a1f19` |
| `ice-pale` | `#dde8ee` | `focus` | `#a8480a` |
| `steel` | `#4f7a93` | `disabled-text` | `#56606a` |
| `text` ("Iron") | `#22262b` | `disabled-fill` | `#d3dce2` |
| `text-muted` | `#4a5560` | `on-primary` | `#ffffff` |
| `border` | `#65727e` | `on-danger` | `#ffffff` |
| `link` | `#2c5873` | `on-power` | `#ffffff` |
| `link-visited` | `#5b3a7a` | | |
| `primary` | `#3d6178` | | |

The seven power values are in FR-9.

Where each color is used:

| Token | Used for |
|---|---|
| `page` | Page background |
| `surface` | Action area, list rows, fields, secondary button fill, badges' surroundings, the power-initial tag's tile |
| `ice` | Background only (AC-2.9): the header's fill. Never text, never a control's edge |
| `ice-pale` | Selected rows, the host section and the "acting as" banner, all from later Issues, so no rule here reads it (the style guide shows one row of units on it). Its text, muted-text and power-color pairs are documented now; a later Issue that puts a border, a primary or danger control, a link or a focus ring on it adds that pair then |
| `steel` | Decorative only: the rule under the header. It carries no meaning and no control uses it |
| `text` | Body text, headings, the label on a secondary button, the unowned supply center's edge and center |
| `text-muted` | Hints, placeholder text, secondary text |
| `border` | Edge of a field, a secondary button, a list row |
| `link`, `link-visited` | Links in running text |
| `primary`, `primary-pressed`, `on-primary` | Primary button fill, its pressed and hover fill, and its label |
| `danger`, `danger-pressed`, `on-danger` | Error text and an invalid field's edge; danger button fill, its pressed and hover fill, and its label |
| `focus` | Focus ring |
| `disabled-fill`, `disabled-text` | A disabled control |
| `power-<id>`, `on-power` | A power badge's fill and name; a unit icon's silhouette; an owned supply center's disk and edge, and `on-power` for its center; the text and border of the power-initial tag (FR-10) |

Treatments that need no color of their own:

- A secondary button's pressed and hover state uses `page` as its fill, and a tappable list row's does too. Rows rest on `surface`.
- `page` and `surface` differ, and each resting fill differs from its pressed fill. The contrast spec checks that the values differ.
- Every pressed state also thickens the border to twice `--border-width`, so pressing is visible by shape as well as fill.
- Link hover thickens the underline.
- The header's app-name link uses `text` on the header's `ice` fill, is underlined only on hover and focus, and is at least `--tap-min` high. Its focus ring is `focus` on `ice`.
- A disabled control's border uses `disabled-text`.

**Must:**
- Define `--font-sans` as system fonts only, with `system-ui` first and a generic `sans-serif` last. Define `--font-mono` as the self-hosted face first, then system monospaces, with a generic `monospace` last (AC-8.1).
- Define the type scale in `rem`, with `--text-base` at `1rem` and no step smaller than `0.875rem`.
- Write each color token as a six-digit hex value with no transparency, so that every contrast ratio is exact and no blending is involved.

**Must not:**
- Write a raw color, a raw font stack, a raw font size or a raw spacing value outside the token file. Rules read tokens only. Exempt are media query conditions (custom properties cannot be used there), `0`, percentages and layout fractions, the family name and weight range inside the one `@font-face` (it cannot read a token), and the presentation attributes inside the inlined drawings (their white and the tag text's `font-size` in drawing units), which are markup and not a stylesheet. Only the color and font-size rules are tested (AC-2.4, AC-1.5). The rest is a review check.
- Hold a color in a custom property that is not a `--color-*` token in the token file (AC-2.5).

### FR-3: Palette and contrast

The light palette is original and fixed (FR-2, FR-9). The contrast spec parses the token file and checks these documented pairs. Thresholds follow WCAG 2.2: 4.5 for text, 3 for graphics and control boundaries. No pair here uses the large-text threshold, so nothing relies on it.

| Pair (foreground on background) | Use | Min |
|---|---|---|
| `text` on `page`, on `surface` | Body text, secondary button label | 4.5 |
| `text` on `ice`, on `ice-pale` | Text in the header; text on a selected row, the host section, a banner | 4.5 |
| `text-muted` on `page`, on `surface`, on `ice-pale` | Hints, placeholders, secondary text | 4.5 |
| `link` on `page`, on `surface` | Links in running text | 4.5 |
| `link-visited` on `page`, on `surface` | Visited links | 4.5 |
| `on-primary` on `primary`, on `primary-pressed` | Label of a primary button | 4.5 |
| `primary` and `primary-pressed` against `page`, against `surface` | Edge of a filled button | 3 |
| `border` against `page`, against `surface` | Edge of a field, a secondary button, a list row | 3 |
| `danger` on `page`, on `surface` | Error text | 4.5 |
| `on-danger` on `danger`, on `danger-pressed` | Label of a danger button | 4.5 |
| `danger` and `danger-pressed` against `page`, against `surface` | Edge of a danger button or an invalid field | 3 |
| `focus` against `page`, against `surface`, against `ice` | Focus ring (on `ice`: the header's link) | 3 |
| `steel` against `page`, against `surface` | The decorative rule under the header (not required by WCAG; held to the non-text level against the page below it so it reads as a line. Against the `ice` header above it the ratio is lower, and that is accepted because the rule is decorative) | 3 |
| `disabled-text` on `disabled-fill` | Label of a disabled control | 3 |
| `on-power` on each `power-<identifier>` | A power's name in its badge | 4.5 |
| each `power-<identifier>` on `surface` | The power's initial in its tag, on the tag's tile | 4.5 |
| each `power-<identifier>` against `page`, against `surface`, against `ice-pale` | A power badge's edge; a unit or supply center and a tag's border on any of those grounds | 3 |

A power color on `surface` is listed twice, at 4.5 (initial text) and at 3 (edge); the contrast spec holds the pair once, at the higher minimum. `on-power` is the same white as `surface`, so `on-power` on a power color is the same ratio as that power color on `surface`; the two pairs stay separate because they name different tokens and different uses. A secondary button's label in its pressed state is `text` on `page`, which the first row already covers. WCAG exempts disabled controls from contrast rules. The 3 on the disabled pair is a house rule so a disabled label can still be read.

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
- Show a power's color only as: the fill of a power badge that holds the power's name as text; the fill of that power's unit icon, which carries the power's initial in its tag and the full name in its label; the fill of an owned supply center, whose label names the owner; and the text and border of the power-initial tag. No other use.
- Render a badge only through the helper `power_badge(identifier)`, which takes an identifier from those seven, as a symbol or a string, and prints the name for it from a list of seven names written in the helper. A later issue replaces that list with the names the gem's map returns, once the app pins the gem. A missing or unknown identifier raises `ArgumentError`.
- Keep the seven colors at least 25 degrees apart in hue, measured as a circular distance in HSL on the final hex values.
- Accept that one light `on-power` color over seven dark fills puts all seven in a narrow band of darkness, so they differ chiefly by hue. This is acceptable because the name or initial is always shown with the color. Austria, Italy and Russia look alike to a person with red-green color blindness, which is why a unit carries an initial and a badge a name.

**Must not:**
- Use a power color as a plain text color (the initial in the power-initial tag is the one exception), as a line, a dot or a map marker on its own, or as a button color.
- Use any color to say which power is which without the name or initial beside it.

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
| Unit icon | army and fleet for each of the seven powers; sizes 20, 32 and 48 shown (any size works); labelled or decorative (FR-10) |
| Supply-center icon | owned by each of the seven powers, and unowned; labelled or decorative (FR-10) |
| Mono text | the `.mono` class (FR-11) |

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
- Use an icon, image, background image or icon font for any component, other than the inline drawings the two icon helpers produce (FR-10). No `<img>`, no `background-image`, no icon font.

### FR-7: The style guide

`GET /styleguide` shows the tokens and every component from FR-6 in its static variants, including the unit section, the supply-center section and a mono text sample. The root placeholder page stays a plain placeholder that #21 will replace, and is not used as the showcase. It does lose its own `main` element, which the layout now supplies, and keeps its `h1` and its sentence.

**Must:**
- Respond 404 in production (AC-5.2). How the route is hidden is a plan matter, and the plan must say how a spec exercises it.
- Render inside the same layout as every other page, so it shows the real header and one action area holding two buttons. The plan decides how the other arrangements (one button, a stack) are exercised during measurement, for example by editing the page in the browser.
- Show every color token other than the power tokens as a swatch with its name; show every documented pair other than the power pairs as a sample of its foreground on its background with the two token names and the minimum ratio, copied from the table above (a third hand copy, after the table and the contrast spec; the request spec asserts the sample count, so a dropped sample is caught); show the type scale and the spacing scale; and show each power badge through `power_badge`, with its token name beside it; show every power's army and fleet at 20, 32 and 48 pixels through `unit_icon`, each of the seven owners and the unowned look through `supply_center_icon`, with the power named beside each, and one line of text in `.mono`.
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

### FR-9: Originality and the fixed colors (rewritten in 2.0.0)

Versions up to 1.2.1 derived the seven power colors by a method (an even spread of hues, assigned alphabetically, then tuned). That method is replaced by fixed values, which the maintainer chose (decision 42). They are held exactly.

| Power | Token | Value | Hue name |
|---|---|---|---|
| Austria | `--color-power-austria` | `#586f2a` | olive |
| England | `--color-power-england` | `#822635` | oxblood |
| France | `--color-power-france` | `#744983` | plum |
| Germany | `--color-power-germany` | `#196666` | teal |
| Italy | `--color-power-italy` | `#866713` | ochre |
| Russia | `--color-power-russia` | `#994324` | rust |
| Turkey | `--color-power-turkey` | `#324e8f` | cobalt |

**Must:**
- Hold these seven values and the palette of FR-2 exactly as written, and fail the contrast spec when any differs (AC-2.10).
- Keep the seven hues at least 25 degrees apart (AC-4.2). England and Russia are the closest pair, at 25.7 degrees, only just inside the rule, which is why no value may be adjusted by eye.
- When a documented pair fails its minimum, raise it as a question to the maintainer with the numbers. Do not change a value to make it pass.
- Record the seven final values and this provenance in the plan and in `web/docs/design-system.md` (AC-4.6).
- Choose any new neutral or accent color from the app's own aim (the Cold War palette of the logo), not from any edition.

**Must not:**
- Sample, trace, match by eye or look up the colors, fonts, board or artwork of any edition of the game. The maintainer chose each power's hue to be different from the color that power's piece commonly has in print. That is a choice made away from the editions, and nothing was taken from them.
- Derive, rotate or tune a power color by a method. There is no method any more, only the fixed values.

### FR-10: Units, supply centers and their helpers (added in 2.0.0)

The two helpers are the only way to draw these icons, as `power_badge` is the only way to draw a badge (AC-7.8). They live in their own helper module, beside `PowerBadgeHelper`, and reuse its list of the seven names.

**Must:**
- Draw from the five masters in `assets/icons/` (`army`, `army-small`, `fleet`, `fleet-small`, `supply-center`), inlined. The app never reads the repository's root folder at run time, since the Docker build context is `web/`. Each master is copied into `app/assets/images/icons/`, byte for byte, and a spec fails if a copy ever differs from its master (AC-7.9).
- Find each part of a drawing by the names in `assets/icons/README.md`: the silhouette, the white marks, the disk, the edge, the center. Because the artwork's ids would repeat on a page with many icons, the helper turns each id into a class and emits no `id`. It sets `width` and `height` from `size` and adds no `style` attribute.
- Color by class and token, never by a raw value in the stylesheet (AC-2.4): a unit's `color` is its power's token, so the silhouette (`currentColor`) takes it; the marks keep the artwork's white; an unowned supply center has `color` set to `text`; an owned one has the disk and the edge filled with the owner's token and the center with `on-power`.
- Draw the power-initial tag inside the unit's `svg`, in the corner the artwork leaves empty: a tile in `surface` with a border in the power's color and the initial in the power's color, in the monospace, hidden from assistive technology (AC-7.5).
- Use the `-small` unit drawings for any size under 24 (AC-7.4). At that size the initial is only about 5 pixels tall, so in this release's lists and screens a visible name sits beside a unit icon under 24 pixels (and the icon is then `decorative: true`). This does not bind the future map (1.x, about 20 pixels, no names beside its units): the map settles its own labeling.
- Name the icon for assistive technology with `aria-label` (the words in AC-7.1 and AC-7.6), or hide it with `aria-hidden="true"` when `decorative: true` because a visible label sits next to it (AC-7.2).
- Raise `ArgumentError` for an unknown power, type, owner or size (AC-7.3), and accept symbols and strings.

**Must not:**
- Place an icon with `<img>`, a background image, a sprite or `url(`. Edit a copy of a drawing (change the master and copy it again). Use an icon to say something without a label or an initial: a unit icon always carries its initial, and a supply center's owner is in its label.

### FR-11: The one self-hosted monospace (added in 2.0.0)

**Must:**
- Use IBM Plex Mono Medium, the Latin subset, as one WOFF2 file: the subset file IBM publishes in its official release (or the same file in the `@ibm/plex-mono` package at a pinned version), with no subsetting tool installed. The file sits in `app/assets/fonts/` with the `OFL.txt` of the same release. `web/NOTICE` records the source URL, the release version and the file's SHA-256 (AC-8.3, AC-8.4).
- Load it with one `@font-face` named `Plex Mono`, with `font-display: swap`, whose `url()` is this app's path to the file and nothing else (AC-6.2).
- Offer the `.mono` class, which sets `font-family: var(--font-mono)` and `font-weight: var(--weight-regular)`, and leaves size to the rule that uses it. The face is Medium only, so a regular-weight request is matched by the browser to that one face. The `@font-face` declares the face for a weight range (AC-6.2), so a bold request is never faked.
- Use it only for phase headers, join codes, province abbreviations, outcome tags and the power-initial tag, and elsewhere only through `.mono`. Phase headers are capitals with letter spacing set in CSS, from source text in sentence case. Those headers, codes and tags come from later Issues; here only `.mono` and the tag exist.
- Treat the font as a new asset, not a dependency: it adds no gem, pin or Node file (AC-6.4). The reason (a six-character join code is read aloud and must have even letters; no system monospace is the same on every phone) is given in the pull request.

**Must not:**
- Fetch the font, or anything else, from a third party at run time. Use it for body text.

### FR-12: The design-system document (added in 2.0.0)

`web/docs/design-system.md` is the catalog the screens of #21 to #28 build to. It holds the content Issue #81 sets out under "Design system content": the palette, the power colors, the type rules, the unit and supply-center rules, the helper rules and the component catalog, with the Issue that builds each component. `docs/architecture.md` ("Design system") stays the record of the decisions and points to it.

**Must:**
- Name every color token and value (AC-9.2) and every component's class name, in the pattern of #20 (block, `__element`, `--variant`).
- Say, in the type rules, that the face is Medium only, so bold and regular look the same in `.mono`, and that a screen must not rely on bold to mean anything there.

**Must not:**
- Contradict `docs/architecture.md`. If it would, raise an Issue first.

## Non-Functional Requirements

### Performance

- Total stylesheet weight at most 32 KB uncompressed (FR-1).
- The stylesheets cause at most one font request (the one `.woff2`, from this app) and no image or script request. The browser fetches the font only when text on the page uses `Plex Mono`.
- No layout shift caused by the stylesheet after first paint, with one allowed exception: `font-display: swap` may re-set text in `.mono` when the font arrives. That text is short and the tag's initial is inside a fixed-size drawing, so nothing around it moves. Icons carry `width` and `height`, so they never shift the page.

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
| 2.1 to 2.6, 2.8, 2.9, 2.10 | Plain RSpec unit spec that parses the stylesheets and computes WCAG ratios; scans declaration values for color forms and banned properties; checks that `ice` is read only as a background, that `on-power` is `#ffffff`, and that every palette and power value is exactly as FR-2 and FR-9 write it | Every `bundle exec rspec` |
| 1.5 | The same kind of spec: no `px` font size and no root font size in the stylesheets | Every `bundle exec rspec` |
| 1.4, 1.6 (the static parts), 3.5 (the static part) | The same kind of spec: field text size at least `1rem`, `touch-action: manipulation` on controls, `env(safe-area-inset-*)` and `viewport-fit=cover` present | Every `bundle exec rspec` |
| 4.1, 4.2, 4.4, 6.2, 6.5, 8.1, 8.2 (the token and rule reads), 8.3, 8.4, 9.2 and the 24 KB limit | The same kind of spec on the stylesheet text, the token file, `NOTICE`, the font folder (including the SHA-256) and the design-system document | Every `bundle exec rspec` |
| 4.3, 4.5, 5.1, 5.3, 5.4, 6.6, 3.7 | RSpec helper and request specs: the helper's output and its error, the style guide's named sections, the absence of links, the root page's content and landmark, and a page without an action area | Every `bundle exec rspec` |
| 7.1 to 7.6, 7.8 | RSpec helper specs for `unit_icon` and `supply_center_icon`: the markup, labels, decorative option, small drawing below 24, the tag, the `ArgumentError` cases and the absence of ids and `url(`; plus a scan of views and helpers for `<svg` | Every `bundle exec rspec` |
| 7.9 | RSpec file spec comparing each copy in `app/assets/images/icons/` with its master in `assets/icons/`, and scanning the app for a read of `assets/icons/`. The whole repository is checked out locally and in CI, so the spec can read the masters | Every `bundle exec rspec` |
| 7.7, 8.2 (the computed font), 6.3, 7.10 | Capybara system specs in real Chrome on `/styleguide`: computed fills and strokes of the icon parts against the token values, the computed `font-family` of `.mono`, every entry of `performance.getEntriesByType("resource")` on this origin with at most one font and that a `.woff2`, and the counts of icons in the unit and supply-center sections | Every `bundle exec rspec` |
| 5.2 | A request spec for the production case, by the mechanism the plan names | Every `bundle exec rspec` |
| 6.4 | The pull request's diff against `main` for the Gemfile, the importmap and any Node file | Review |
| 2.7, 4.6, 5.5, 6.1, 9.1 | Review of the markup, the plan, the design-system document and the style guide copy against the criterion | Review |
| 1.2, 3.1 (360 pixels), 3.2, 3.3, 3.6, 3.10 | The Capybara system specs of #73 (`spec/system/styleguide_layout_spec.rb`): 44 pixel targets, no sideways scroll at 360, the sticky action area and focus. They run on every `bundle exec rspec` and must pass unchanged after the re-theme: a failure is a defect in the stylesheet, not a reason to loosen a spec | Every `bundle exec rspec` |
| 1.1, 1.2, 1.3, 3.1, 3.2, 3.3, 3.4, 3.6, 3.8, 3.9, 3.10, 6.3 | A repeatable measurement in real Chrome at 320, 360, 390, 768 and 1024 pixels wide (and one short viewport), plus a keyboard pass and the network panel, with screenshots at 360 and 768 pixels. The measurement is a written procedure and a console snippet kept in the spec folder (not app JavaScript), and its results are recorded in the pull request | Before the pull request is ready |
| Pressed, hover, focus ring, forced colors, reduced motion | The same Chrome session, using its state and media emulation | Before the pull request is ready |
| 1.4 (zoom), 1.6 (touch), 3.5 (real insets), 3.2 (dynamic toolbar) | One pass on a real iPhone in Mobile Safari. No phone is available to the agent, so this is **owed to the maintainer** and is named as such in the pull request. Issue #71 tracks it and lists AC-1.4, 1.6, 3.2 and 3.5, and the pull request names it. Those four boxes stay unticked until #71 closes. **Done 2026-11-26:** the maintainer checked all four on an iPhone in Mobile Safari, against `/styleguide` on a development build, and all passed (#71) | Before the playtest |

When version 1.2.1 was approved the Gemfile had no browser-driving gem, so geometry was measured by hand. Issue #73 has since added Capybara with headless Chrome (`spec/system/`, `web/AGENTS.md`, "Testing"), and the system specs above now cover part of the Chrome row. The hand measurement stays as the procedure in `measure.md` for what no spec covers yet.

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
| The system asks for forced colors | Borders and text stay visible because they are real borders and text, not fills alone. The icons are SVG fills and strokes, so they keep their own colors on the forced background; this is checked by hand in Chrome's emulation with the other forced-colors checks |
| The system asks for reduced motion | No transition runs |
| A color token is added without a documented pair | The contrast spec fails and names it |
| A pair falls below its threshold | The contrast spec fails and prints the pair, ratio and threshold |
| A color is written outside the token file | The contrast spec fails and names the file and line |
| `power_badge` gets an unknown or missing identifier | It raises an error, and no badge is rendered |
| `unit_icon` gets an unknown power, a type such as `:submarine`, or a size that is not an Integer above zero | It raises `ArgumentError`, and nothing is rendered |
| `supply_center_icon` gets an unknown owner or a bad size | It raises `ArgumentError`. A `nil` owner is the unowned look, not an error |
| A unit icon is shown at 20 pixels | The `-small` drawing is used, and the tag's initial is very small. The icon is still labelled, and in a list the power is named beside it |
| The font file fails to load | `swap` keeps the fallback monospace on screen, and nothing else depends on the font. Icons and layout are unchanged |
| A copy of a drawing no longer matches its master | The file spec fails and names the file. Note: `.github/workflows/web.yml` runs only on `web/**` changes, so a pull request that edits a master alone (a `repo` change) does not run it, and the failure shows on the next web pull request. Adding `assets/icons/**` to that workflow's paths is a root change with its own Issue (#86), and is not made here |
| A request for `/styleguide` in production | 404 |
| The stylesheet is blocked or fails to load | The page is still readable and usable as plain, unstyled HTML, since no content comes from CSS |

## Open Questions

None. The decisions already made, for the record:

- **Style guide or root page:** a `/styleguide` page, development and test only (FR-7).
- **Dark mode:** out of scope (below).
- **Browser-driven specs:** measurement in real Chrome, recorded in the pull request, and a phone pass owed to the maintainer (Verification). Issue #73 has since added Capybara for the layout checks.
- **Main action color (2.0.0):** `primary` is the main action and `steel` is decorative only. The maintainer settled it when merging #80.
- **Palette and power values (2.0.0):** fixed by the maintainer (decisions 41 and 42) and held exactly.
- **Action area:** in the page flow and sticky, with a header that scrolls away (FR-5).

## Out of Scope (Future Considerations)

- **Dark mode (`prefers-color-scheme`).** The Issue allows it only if cheap. It is not. The palette tokens would split in two, so the documented pairs would need a second set, and the seven power colors would need a second set that also holds 4.5 against a dark badge text and 3 against a dark page. The contrast spec, the style guide and the screenshots would all double. The table is played in rooms where a phone may sit in a bright or a dim place, but the playtest has no evidence that either needs a dark theme. Because every color is a token and every pair is documented, adding dark mode later is an additive change with a contained blast radius. The stylesheet states `color-scheme: light` so browsers do not darken form controls on their own and mix themes.
- Styles for modal, sheet, tab, toast and flash components, until the first screen needs one.
- Glyphs for outcomes, seat states, banners and chrome (#82), the map-only icons (1.x), and every screen component of the catalog other than the ones built here (#21 to #28 and 1.0).
- Hiding the header or action area in a Hotwire Native wrapper, which a path configuration can decide later. The layout keeps them as separate, named regions so a later rule can target them.
- Replacing the helper's seven hardcoded names with the gem's map names, once the app pins the gem.
- Print styles, right-to-left layouts and translations.
