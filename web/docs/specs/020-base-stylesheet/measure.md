# How the base stylesheet was measured

Spec 020 verifies geometry in a real browser, not in the normal spec run. This file keeps the procedure, the snippet and the results, so the same check can be repeated, and so a later system spec (Issue #73) can turn each step into an automated example.

## Method

A desktop Chrome window cannot be made 320 to 390 pixels wide (its floor is about 500). So a scratch page holds the page under test in an `iframe` of the wanted size. It is served by the same Rails server, so it is same-origin and the snippet can reach into the frame. The frame's size is the viewport the page sees, so media queries, `dvh` and `position: sticky` behave as on a phone of that size.

1. From `web/`, run `bin/rails server -p 3020`.
2. Create `web/public/frame.html`, which must **not** be committed (add it to the exclude list with `echo web/public/frame.html >> "$(git rev-parse --git-path info/exclude)"`, and delete both afterwards):

   ```html
   <!doctype html><title>frame</title>
   <body style="margin:0;background:#888;display:flex;justify-content:center">
   <iframe id="f" style="border:0;display:block"></iframe>
   <script>
     const p = new URLSearchParams(location.search), f = document.getElementById('f');
     f.style.width = (p.get('w') || 360) + 'px'; f.style.height = (p.get('h') || 800) + 'px';
     f.src = p.get('src') || '/styleguide';
   </script>
   ```

3. Open `http://127.0.0.1:3020/frame.html?w=360&h=800`. Define `measure` (below) in the page console, then run it for each width.
4. Screenshots: headless Chrome enforces a minimum window width of about 600, so take the frame page in a window at least 600 wide and crop the centre, which is where the flex layout puts the frame: `Google Chrome --headless=new --hide-scrollbars --virtual-time-budget=4000 --window-size=600,800 --screenshot=out.png "http://127.0.0.1:3020/frame.html?w=360&h=800"`, then `sips -c 800 360 out.png`. A direct `--window-size=360,800` screenshot is wrong: it lays the page out at the wider minimum and crops the right side off.

## Selectors a system spec can use

| What | Selector |
|---|---|
| Things that must be at least 44 by 44 | `.button`, `.app-header__name`, `.list__row`, `.control`, `.choice` |
| Separate controls that need an 8 pixel gap | the children of `.sg-row` and `.app-actions__inner` |
| The sticky action area | `.app-actions` (its buttons are `.app-actions__inner > .button`) |
| The header, which scrolls away | `.app-header` |
| The column | `.app-main` (at most 640 pixels wide) |
| Style guide sections | `section[data-component]` |
| Static states | `.button[disabled]`, `.button[aria-disabled=true]`, `.control[aria-invalid=true]`, `.choice[aria-disabled=true]` |

## The snippet

```js
// Parent page: http://localhost:3020/frame.html. Set the frame size, load the page, then:
//   const f = document.getElementById('f'); f.style.width = '360px'; f.style.height = '800px';
//   measure(f.contentWindow)
function measure(win) {
  const d = win.document, doc = d.documentElement;
  const out = { width: win.innerWidth, height: win.innerHeight, problems: [] };
  if (doc.scrollWidth > doc.clientWidth) out.problems.push(`sideways scroll: ${doc.scrollWidth} > ${doc.clientWidth}`);

  // AC-1.2: tap targets (links in running text are exempt)
  for (const el of d.querySelectorAll('.button, .app-header__name, .list__row, .control, .choice')) {
    const r = el.getBoundingClientRect();
    if (r.width < 43.5 || r.height < 43.5) out.problems.push(`small target ${el.className}: ${r.width.toFixed(1)}x${r.height.toFixed(1)}`);
  }
  // A choice row overlaps nothing: its next sibling starts at or below its bottom edge
  for (const el of d.querySelectorAll('.choice + .choice')) {
    const a = el.previousElementSibling.getBoundingClientRect(), b = el.getBoundingClientRect();
    if (b.top < a.bottom - 0.5) out.problems.push('choice rows overlap');
  }

  // AC-1.3: at least 8px between every two separate controls (buttons and fields).
  // Rows of one list, and rows of one group of choices, touch on purpose and are not compared.
  const sep = [...d.querySelectorAll('.button, .control')].filter((el) => el.getClientRects().length);
  for (let i = 0; i < sep.length; i++) for (let j = i + 1; j < sep.length; j++) {
    const a = sep[i].getBoundingClientRect(), b = sep[j].getBoundingClientRect();
    const dx = Math.max(b.left - a.right, a.left - b.right), dy = Math.max(b.top - a.bottom, a.top - b.bottom);
    if (Math.max(dx, dy) < 7.5) out.problems.push(`gap under 8px between ${sep[i].className} and ${sep[j].className}`);
  }

  // AC-1.1 and AC-1.4: text sizes
  if (parseFloat(win.getComputedStyle(d.body).fontSize) < 16) out.problems.push('body text under 16px');
  for (const el of d.querySelectorAll('body *')) {
    if (![...el.childNodes].some((n) => n.nodeType === 3 && n.textContent.trim())) continue;
    const s = parseFloat(win.getComputedStyle(el).fontSize);
    if (s < 14) out.problems.push(`text under 14px: ${el.tagName}.${el.className} ${s}px`);
  }
  for (const el of d.querySelectorAll('.control')) {
    if (parseFloat(win.getComputedStyle(el).fontSize) < 16) out.problems.push('control text under 16px');
  }

  // AC-3.2 to 3.4, 3.8, 3.10: the action area, when the page has one
  const bar = d.querySelector('.app-actions');
  out.actionArea = !!bar;
  if (bar) {
    out.position = win.getComputedStyle(bar).position;
    out.barBottomGap = +(win.innerHeight - bar.getBoundingClientRect().bottom).toFixed(1);   // 0 when stuck or at the page bottom
    const last = d.querySelector('.app-main').lastElementChild.getBoundingClientRect();
    out.clearOfBar = last.bottom <= bar.getBoundingClientRect().top + 0.5;                  // check at the end of the scroll
  }
  out.headerTop = +d.querySelector('.app-header').getBoundingClientRect().top.toFixed(1);   // below 0 once scrolled
  out.mainWidth = +d.querySelector('.app-main').getBoundingClientRect().width.toFixed(1);   // at most 640
  out.pageHeight = doc.scrollHeight;
  out.ok = out.problems.length === 0;
  return out;
}
```

## Procedure, for each width 320, 360, 390, 768 and 1024 (frame height 800)

1. Run `measure` at scroll top, at the middle (`win.scrollTo(0, doc.scrollHeight / 2)`) and at the end (`win.scrollTo(0, doc.scrollHeight)`). `barBottomGap` stays 0 at all three, `clearOfBar` is true at the end, and `headerTop` is negative once scrolled (AC-3.2, 3.3, 3.10).
2. Short content (AC-3.4): remove every `.stack > *:not(h1)` in the frame, so the content is short, and confirm `barBottomGap` is 0 at scroll top and the page is exactly one viewport high.
3. Focus (AC-3.6): focus each control with `el.focus()` from the top of the page, and confirm its top is above the action area's top.
4. Short viewport (AC-3.9): at 800 by 400 the area's `position` is `static`; at 800 by 480 it is `sticky`.
5. Column (AC-3.8): at 768 and 1024, `mainWidth` is at most 640.
6. Action area shapes: replace the buttons with one, two, three and four, and with two `button_to`-style forms.
7. `/` at 360 (AC-3.7): no `.app-actions`.
8. Network (AC-6.3): load `/styleguide` in the tab, and read the network log.

## Results (2026-11-25, Chrome, `bin/rails server`, development, after the review fixes)

The snippet above was run in headless Chrome from a scratch page, at each width, against the final stylesheets.

| Width x height | Problems found | Position | `barBottomGap` top / middle / end | Clear of bar at end | Header scrolled away | Main width |
|---|---|---|---|---|---|---|
| 320 x 800 | none | sticky | 0 / 0 / 0.1 | yes | yes | 305 (scrollbar takes 15) |
| 360 x 800 | none | sticky | 0 / 0 / 0 | yes | yes | 345 |
| 390 x 800 | none | sticky | 0 / 0 / 0 | yes | yes | 375 |
| 768 x 800 | none | sticky | 0 / 0 / 0 | yes | yes | 640 |
| 1024 x 800 | none | sticky | 0 / 0 / 0 | yes | yes | 640 |

"None" means: no sideways scroll, every target at least 44 by 44, at least 8 pixels between every two separate controls (buttons and fields, all pairs), body text 16 pixels, no text under 14 pixels, controls at 16 pixels. The 0.1 is sub-pixel rounding at the very end of the page.

| Check | Result |
|---|---|
| Short viewport (AC-3.9) | 800 x 400: `static`. 800 x 480: `sticky`. At 400 high the bar sits at the very end of the page (measured before the review fixes; the rule did not change) |
| Short content (AC-3.4) | At 360 x 800 with the content removed: the page is exactly 800 high and `barBottomGap` is 0 (measured before the review fixes; the rule did not change) |
| Focus behind the bar (AC-3.6) | For each of 20 controls in the main content, the page was scrolled so the control sat 10 pixels below the top of the action area, hidden behind it, and then `el.focus()` was called. With the stylesheet as written, 0 of 20 stayed hidden. With `scroll-padding-bottom` set to 0, 20 of 20 stayed hidden. So the check can fail, and the padding is what makes it pass |
| Tab order | No element has a `tabindex` other than 0 or -1, so the order is the order of the page. A real Tab-key pass was not made: the browser tooling's key input was not usable for it |
| One / two / three / four buttons at 360 | One: 313 x 44, full width. Two: 153 x 44 each, side by side with 8 between. Three: two on a row and the third full width. Four: two rows of two. A `button_to` form wrapper: the buttons sit as the flex items (two side by side) |
| 200 percent text (AC-1.5, WCAG 1.4.4), at 360 | With the root size set to 200 percent: two buttons ("Back", "Send orders") stack to full width, 88 high, no label spills; one long label wraps; `/` and `/styleguide` have no sideways scroll. One limit: a single word wider than the whole column (for example a 20 letter word at 200 percent) still makes its button wider than the screen, because a minimum width of "min-content" cannot also let a word break |
| `/` at 360 (AC-3.7) | No `.app-actions`, no sideways scroll, header 46 high (a 44 link and a 2 border), `h1` 32 pixels |
| Network (AC-6.3) | 14 requests: the page, six stylesheets from `127.0.0.1:3020`, and the app's own Turbo and Stimulus scripts. No font request |
| Pressed look | The `.button:active` declarations were applied to a primary button by hand (the `:active` state itself cannot be forced here): the fill becomes `rgb(22, 58, 105)` and the inset ring is `rgb(255, 255, 255)` 2 pixels, so the thicker edge shows. Danger buttons use `on-danger` for the ring in the same way. Secondary buttons, list rows and choices use `border` |
| Disabled shape (AC-2.7) | Disabled buttons, a disabled link-button, a disabled field and a disabled choice row all have a `dashed` border, so a disabled control differs by shape as well as color |

## Not checked here

- **Hover, real `:active`, forced colors and reduced motion.** The browser tooling in this environment cannot force a pseudo-class state or a media feature. The rules were read, and the pressed values were applied by hand as above. The spec's Verification row names Chrome's emulation for these, so this is a deviation, recorded in the pull request. Issue #71 asks the phone pass to look at pressed feedback.
- **A real Tab-key pass.** See the Tab order row.
- **Other browsers.** Only Chrome was used. Safari and Firefox are not checked, apart from what #71 covers on an iPhone.
- **Pinch and double-tap zoom, real safe-area insets, the iOS toolbar, and `:active` on touch.** These need a real iPhone. They are owed to the maintainer in Issue #71 (AC-1.4, 1.6, 3.2 and 3.5).

## Screenshots

`screenshots/styleguide-360.png` (360 x 800, top of the page), `screenshots/styleguide-768.png` (768 x 1024, top of the page), `screenshots/styleguide-360-powers.png` (360 x 800, scrolled to the power badges). They were taken as described under "Method".
