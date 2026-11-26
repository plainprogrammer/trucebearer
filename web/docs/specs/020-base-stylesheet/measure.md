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

  // AC-1.3: at least 8px between separate controls
  for (const row of d.querySelectorAll('.sg-row, .app-actions__inner')) {
    const k = [...row.children].map((el) => el.getBoundingClientRect());
    for (let i = 0; i < k.length; i++) for (let j = i + 1; j < k.length; j++) {
      const dx = Math.max(k[j].left - k[i].right, k[i].left - k[j].right);
      const dy = Math.max(k[j].top - k[i].bottom, k[i].top - k[j].bottom);
      if (Math.max(dx, dy) < 7.5) out.problems.push(`gap under 8px in ${row.className}`);
    }
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

## Results (2026-11-25, Chrome, `bin/rails server`, development)

| Width x height | Problems found | Position | `barBottomGap` top / middle / end | Clear of bar at end | Header scrolled away | Main width |
|---|---|---|---|---|---|---|
| 320 x 800 | none | sticky | 0 / 0 / 0.1 | yes | yes | 305 (scrollbar takes 15) |
| 360 x 800 | none | sticky | 0 / 0 / 0.2 | yes | yes | 345 |
| 390 x 800 | none | sticky | 0 / 0 / 0.2 | yes | yes | 375 |
| 768 x 800 | none | sticky | 0 / 0 / 0.2 | yes | yes | 640 |
| 1024 x 800 | none | sticky | 0 / 0 / 0.2 | yes | yes | 640 |

"None" means: no sideways scroll, every target at least 44 by 44, at least 8 pixels between separate controls, body text 16 pixels, no text under 14 pixels, controls at 16 pixels. The 0.1 and 0.2 are sub-pixel rounding at the very end of the page.

| Check | Result |
|---|---|
| Short viewport (AC-3.9) | 800 x 400: `static`. 800 x 480: `sticky`. At 400 high the bar sits at the very end of the page |
| Short content (AC-3.4) | At 360 x 800 with the content removed: the page is exactly 800 high and `barBottomGap` is 0 |
| Focus (AC-3.6) | 21 controls in the main content, each focused from the top of the page: all clear of the action area. The two buttons inside the action area are the area itself. The focus ring is `solid 3px`, offset `2px` |
| One / two / three / four buttons at 360 | One: 313 x 44, full width. Two: 153 x 44 each, side by side with 8 between. Three: two on a row and the third full width. Four: two rows of two. A `button_to` form wrapper: the buttons sit as the flex items (two side by side) |
| `/` at 360 (AC-3.7) | No `.app-actions`, no sideways scroll, header 46 high (a 44 link and a 2 border), `h1` 32 pixels |
| Network (AC-6.3) | 14 requests: the page, six stylesheets from `127.0.0.1:3020`, and the app's own Turbo and Stimulus scripts. No font request |

## Not checked here

- **Hover, pressed (`:active`), forced colors and reduced motion.** The browser tooling in this environment cannot force a pseudo-class state or a media feature. The rules were read instead: the pressed state changes fill and draws an inset ring (`.button:active`), hover is inside `@media (hover: hover)`, borders are real borders, and `.button` loses its transition under `prefers-reduced-motion: reduce`.
- **Pinch and double-tap zoom, real safe-area insets, the iOS toolbar, and `:active` on touch.** These need a real iPhone. They are owed to the maintainer in Issue #71 (AC-1.4, 1.6, 3.2 and 3.5).

## Screenshots

`screenshots/styleguide-360.png` (360 x 800, top of the page), `screenshots/styleguide-768.png` (768 x 1024, top of the page), `screenshots/styleguide-360-powers.png` (360 x 800, scrolled to the power badges). They were taken as described under "Method".
