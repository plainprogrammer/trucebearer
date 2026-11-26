# Design system

The visual rules every screen of the web app builds to. Screens #21 to #28 take their parts from the catalog at the end of this page, and add each new part to `/styleguide` in the same pull request.

Where things live:

- **Decisions:** `docs/architecture.md`, "Design system". If this page and that section disagree, say so in an Issue.
- **Values:** `web/app/assets/stylesheets/tokens.css`. A spec holds the palette and power values exactly, and checks that every color token appears on this page with its value.
- **Contrast:** `web/spec/styles/contrast_spec.rb` computes every documented pair from the token file on each run.
- **How the base stylesheet was specified:** `web/docs/specs/020-base-stylesheet/spec.md`, version 2.0 and later.

The look is light only. It comes from the Cold War palette of the logo: pale blue Ice and its tints for the light end, dark Iron for text, a darker steel blue for the main action, and signal amber for focus.

## Palette

Colors are CSS custom properties named `--color-...`. Rules read tokens only; no screen writes a raw color.

| Token | Value | Used for |
|---|---|---|
| `--color-page` | `#eef3f6` | Page background |
| `--color-surface` | `#ffffff` | Action area, list rows, fields, the secondary button fill, the power-initial tag's tile |
| `--color-ice` | `#a7c4d4` | The header's fill. A background only: never text, never a control's edge, never a line |
| `--color-ice-pale` | `#dde8ee` | Selected rows, the host section (built by #21), the "acting as" banner (later screens) |
| `--color-steel` | `#4f7a93` | Decorative only: the rule under the header. It carries no meaning and no control uses it |
| `--color-text` | `#22262b` | Body text, headings ("Iron"); the unowned supply center's edge and center |
| `--color-text-muted` | `#4a5560` | Hints, placeholders, secondary text |
| `--color-border` | `#65727e` | Edge of a field, a secondary button, a list row |
| `--color-link` | `#2c5873` | Links in running text |
| `--color-link-visited` | `#5b3a7a` | Visited links |
| `--color-primary` | `#3d6178` | The main action: the primary button |
| `--color-primary-pressed` | `#2b4657` | The primary button pressed |
| `--color-on-primary` | `#ffffff` | The label on a primary button |
| `--color-danger` | `#9e2a22` | Destructive actions, "dislodged", errors |
| `--color-danger-pressed` | `#7a1f19` | The danger button pressed |
| `--color-on-danger` | `#ffffff` | The label on a danger button |
| `--color-focus` | `#a8480a` | The focus ring |
| `--color-disabled-text` | `#56606a` | A disabled control's label and edge |
| `--color-disabled-fill` | `#d3dce2` | A disabled control's fill |
| `--color-on-power` | `#ffffff` | A power's name on its badge; the center of an owned supply center. It is the same white the artwork's marks are drawn in |

`primary` is the main action. `steel` is decorative only.

Outcomes and seat states do not get their own hues. They are words (and, from #82, a glyph) on a neutral or tinted ground. Only "dislodged" and errors use `danger`.

### Documented pairs

Every pair below is computed from the tokens on each spec run, and none may fall under its minimum. Text pairs need 4.5, and non-text pairs (edges, rings, rules) need 3.

| Foreground on background | Minimum |
|---|---|
| `text` on `page`, `surface`, `ice`, `ice-pale` | 4.5 |
| `text-muted` on `page`, `surface`, `ice-pale` | 4.5 |
| `link` and `link-visited` on `page`, `surface`, `ice-pale` | 4.5 |
| `on-primary` on `primary`, `primary-pressed` | 4.5 |
| `danger` on `page`, `surface` | 4.5 |
| `on-danger` on `danger`, `danger-pressed` | 4.5 |
| `on-power` on each power color | 4.5 |
| each power color as text on `surface` (the initial tag) | 4.5 |
| `primary`, `primary-pressed`, `border`, `danger`, `danger-pressed` against `page`, `surface`, `ice-pale` | 3 |
| `focus` against `page`, `surface`, `ice`, `ice-pale` | 3 |
| `steel` against `page`, `surface` | 3 |
| `disabled-text` on `disabled-fill` | 3 |
| each power color against `page`, `surface`, `ice-pale` | 3 |

A new color is one token plus one documented pair, or the contrast spec fails. If a pair fails, raise it with the numbers. Do not change a value.

## Power colors

Seven muted, original colors, one per power. Each is named `--color-power-<identifier>`.

| Power | Token | Value | Hue |
|---|---|---|---|
| Austria | `--color-power-austria` | `#586f2a` | olive |
| England | `--color-power-england` | `#822635` | oxblood |
| France | `--color-power-france` | `#744983` | plum |
| Germany | `--color-power-germany` | `#196666` | teal |
| Italy | `--color-power-italy` | `#866713` | ochre |
| Russia | `--color-power-russia` | `#994324` | rust |
| Turkey | `--color-power-turkey` | `#324e8f` | cobalt |

- **The values are fixed.** They are the maintainer's choice (decision 42), not the output of a method, and nobody tunes one by eye. England and Russia are 25.7 degrees apart in hue, just over the 25-degree rule that a spec checks, so even a small change can break it.
- **Provenance.** Each hue was chosen to differ from the color the power's piece commonly has in print. Nothing was taken from any edition: no edition's colors, artwork or fonts were sampled, traced or looked up, and no edition was consulted.
- **Always with a name or an initial.** A power color is never shown alone. A badge carries the full name, a unit carries the initial in its tag, and a supply center's owner is in its label.
- **Color blindness.** Austria, Italy and Russia look alike to a person with red-green color blindness. That is why units carry an initial and badges a name.
- **Where a power color may be used:** the fill of a power badge, the fill of a unit's silhouette, the owned disk and edge of a supply center, and the text and border of the power-initial tag. Nowhere else: not as a plain text color, a line, a dot, or a button color.

## Type

- **Body text** is the system sans, `--font-sans`. Sizes are `rem` steps (`--text-sm` to `--text-2xl`), and body text is never under 16 pixels.
- **Mono** is `--font-mono: "Plex Mono", ui-monospace, "SF Mono", Menlo, Consolas, monospace`. The face is IBM Plex Mono Medium, Latin subset, one WOFF2 file served by this app with `font-display: swap`. It is used only for phase headers, join codes, province abbreviations, outcome tags and the power-initial tag. Elsewhere, put the `.mono` class on the element. Do not read `--font-mono` in a new rule.
- **Phase headers** are capitals with letter spacing set in CSS. The source text stays in sentence case.
- **Medium only.** The face has one weight, so bold and regular look the same in `.mono`. Never rely on bold to mean something there. The `@font-face` declares the face for a weight range, so the browser does not fake a bold.
- **No request to a third party.** The font file, the stylesheets and the scripts all come from this app.

## Units and supply centers

- One **army** drawing (a chevron shield) and one **fleet** drawing (a warship) serve every power, filled with the power's color. The artwork's full drawings are used from 24 pixels up, and the `-small` drawings below that.
- **Power-initial tag.** A white tile in the bottom-right corner of every unit, holding the power's initial (A, E, F, G, I, R, T) in the power's color, with a border in the power's color. It is part of the icon, so it works where no name is printed.
- **Supply center.** Owned is a disk in the owner's color with a white center. Unowned is a white disk with an Iron (`text`) edge and an Iron center.
- **Sizes.** List rows use 32 pixels. A future map will use about 20. The helper draws any size, but the 14-pixel text rule is exempted for the tag initial only at the sizes this app uses, 20 to 48 pixels. A size under 20 is outside that exemption.
- **Small icons need a name.** At 20 pixels the tag's initial is only about 5 pixels tall, so in this release's lists and screens a visible name sits beside a unit icon under 24 pixels, and the icon is then `decorative: true`. The future map settles its own labeling.
- **The artwork.** The master drawings are in `assets/icons/` (CC BY-SA 4.0). The app uses byte-for-byte copies in `web/app/assets/images/icons/`, and a spec fails if a copy differs from its master. Change the master, then copy it again. Never edit a copy.

## Helpers

`unit_icon` and `supply_center_icon` are **the only way** to draw these icons, as `power_badge` is the only way to draw a badge.

```ruby
unit_icon(power, type, size: 32, decorative: false)
supply_center_icon(owner, size: 32, decorative: false)
```

- They inline the SVG (no `url(`, no `<img>`), and color it by power token through classes.
- Unless `decorative: true`, they render `role="img"` with a label: "Army, Austria", "Fleet, England", "Supply center, Italy", or "Supply center, unowned" for a `nil` owner. With `decorative: true` they render `aria-hidden="true"` instead, because a visible label sits next to them.
- The power and the type each accept a symbol or a string. An unknown power or type, or a size that is not an Integer above zero, raises `ArgumentError`. A `nil` owner is the unowned look.
- Parts of a drawing are classes (`unit-icon__silhouette`, `supply-center-icon__disk`, and so on). A page with many icons never repeats an id.

Issue #21 adds three more helpers: `join_code_text(code)` (the code as mono text in two groups), `qr_card(url, label:, caption: nil)` (an inline SVG code on white, the caption, the link as text) and `power_tiles(taken: [])` (seven tiles, each with its badge). Draw these parts only through them.

## Component catalog

Class names follow the pattern of the base stylesheet: block, `__element`, `--variant`. Each screen Issue builds its components to this catalog and adds them to `/styleguide`.

**Already built, restyled by the re-theme:** `.app`, `.app-header`, `.app-main`, `.app-actions`; `.button` (`--secondary`, `--danger`); `.list`, `.list__row`; `.field`, `.control`; `.choices`, `.choice`; `.power-badge`.

**Built with the re-theme:** `unit_icon`, `supply_center_icon`, `.mono`.

### Playtest screens

| Component | Class | Built by | Notes |
|---|---|---|---|
| Phase header | `.phase-header` (partial `phases/_header`) | #22 (built) | Season, year, phase type in mono capitals; the viewer's power badge on the right |
| Banner | `.banner` (`--info`, `--warning`, `--danger`; partial `shared/_banner`) | #22 (built) | One sentence ("Orders are locked", "Acting as Italy", "The host entered your orders at 8:42"); rendered through one partial so #82 can add a glyph in one place |
| Confirmation page | `.confirm` (layout partial `shared/_confirm`) | #22 (built) | A full page, not a modal: heading, consequences in plain words, confirm button, cancel link. #26 reuses it |
| Join code | `.join-code` (`join_code_text`) | #21 (built) | Six mono characters, large, in two groups of three, as one selectable line of text |
| QR card | `.qr-card` (`__code`, `__caption`, `__link`; `qr_card`) | #21 (built) | QR code on white with a caption under it (the join code, or a power's badge for a seat) and the link as text |
| Power tile | `.power-tile` (`--taken`; `.power-tiles`, `power_tiles`) | #21 (built) | Seven tiles in a grid; an open tile is a button, a taken tile says "Taken" and is not a control |
| Host section | `.host-section` | #21 (built) | `ice-pale` ground with a "Host" heading, apart from the player's own screen |
| Unit row | `.unit-row` (extends `.list__row`; partial `seat_orders/_unit_row`) | #23 (built) | Unit icon, province name with its abbreviation, current order or "holds", chevron drawn by CSS |
| Picker step | `.picker`, `.picker__draft` (partial `order_pickers/_draft`; choices `order_pickers/_choice`) | #23 (built) | Each step is a page; the draft order so far at the top; choices are a `.list` of links, and the last pick is a form |
| Submit bar | `.submit-bar`, `.save-status` (partials `seat_orders/_submit_bar`, `shared/_save_status`) | #23 (built) | In `.app-actions`; the button carries the count ("2 of 3 ordered"); the status reads "Saved", "Saves when you pick", "Not saved", and "Saving…" while Turbo submits a form |
| Seat status | `.seat-status` | #24 | Seven rows: badge plus "Submitted" or "Not submitted"; a live region announces changes; rendered through one partial |
| Result row | `.result-row`, `.outcome-tag` | #25 | The order in words, then a mono tag ("Succeeded", "Bounced", "Support cut", "Dislodged"); dislodged uses `danger`; tags through one partial |
| Result group | `.result-group` (`--reading`) | #25 | Grouped by power; the host's reading variant has larger type and dislodged units first |
| Segmented toggle | `.segmented` | #27 | Army or fleet; a radio group styled as two joined buttons |
| Game card | `.game-card` | #28 | Game name, phase header, your power |

### 1.0 screens

| Component | Class | Built by |
|---|---|---|
| "Check your email" page | `.notice-page` (forms use `.field` and `.button`) | #42 |
| Empty state | `.empty-state` | #43 |
| Callout | `.callout` (claim your seat) | #44 |
| Adjustment counter | `.adjust-count` ("Build 2", "Disband 1") | #46 |
| Changed marker | `.changed-marker` (changed after the reveal) | #47 |
| Absent seat state | `.seat-status__absent` | #48 |
| Drift check | designed with decision #35 | #49 |
| Timeline, event log | `.timeline`, `.event-log` | #50 |
| Supply-center table | `.sc-table` (final standings) | #50 |
| Prose page, key-value list | `.prose`, `.key-value` | #51 |
| Footer | `.app-footer` linking "About this instance" | #51 |

### Glyphs (#82)

Outcome (succeeded, bounced, cut, dislodged), seat state (submitted, not submitted, absent), banner (info, warning, error), chrome (back, chevron, host, history). In the playtest these states use words alone.

### Map-only icons (1.x, not drawn yet)

Home-center marker, dislodged and stand-off markers, move, support and convoy arrows, pale territory tints of the power colors.
