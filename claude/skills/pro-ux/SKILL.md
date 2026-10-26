---
name: pro-ux
description: Boyd's "pro-UX" house style for any interface, dashboard, report page, tool or chart. It means quiet greys and hairline borders, EB Garamond, dense information shown by default, more detail on hover, and keyboard shortcuts for everything, aimed at power users. Use when the user says "pro-UX", "pro UX", "in the explorer style", "like the plot explorer", or asks for a page, dashboard, or tool without naming another style. The reference implementation is the Plot Explorer at /Users/brk/projects/mats/plotting/explore/index.html.
---

# pro-UX

The style of the Plot Explorer (`/Users/brk/projects/mats/plotting/explore/index.html`).
In one line: **Tufte-style, keyboard-first, information-dense, details on demand.**
When in doubt, open that file and copy what it does. Its `<style>` block (lines 11–224) is the source of truth for every value below.

## Principles

- **Show the data, not the chrome.** No gradients, no rounded cards, no icons where a word fits, no decorative colour. Every pixel carries information.
- **Dense by default.** Put everything a power user needs on screen at once: counts, n, interval kind, filters in force, ids. Do not hide information behind clicks if it fits.
- **More on hover.** Anything that needs explaining gets a `data-hint` tooltip. Charts get a rich hover card (zoomed inset plus a table of values). Small `(?)` marks explain controls.
- **Every action has a key.** Show the key beside the control (`<kbd>c</kbd>colour`), so the interface teaches its own shortcuts.
- **Nothing is lost.** Deletes give an undo toast. `z`/`Z` undo and redo. State lives in the address bar, so every view is a shareable link.
- **Quiet, then one strong accent.** Greys do the work. Dark `#3a3a40` marks "on" or "selected". Red appears only for errors and destructive hovers.
- **Titles say what the reader sees.** Charts carry a title, a subtitle naming what is pooled or filtered, and "mean ± 95% CI (t), n = 12 per point".

## Tokens

```css
:root { --fg:#2a2a2e; --mute:#77777f; --soft:#e2e2e6; --line:#d3d3d9; --bg:#f4f4f6; --tint:#eef1f6; --dark:#3a3a40; --bad:#b00020;
        --font:"EB Garamond", Garamond, Georgia, serif; }
* { box-sizing:border-box; border-radius:2px; }
body { margin:0; font:16px/1.4 var(--font); color:var(--fg); background:var(--bg); }
button, input, select { font:inherit; color:inherit; }
```

- **Font.** EB Garamond for everything, including inputs, charts and code-like labels. Load it from Google Fonts with weights 400, 500, 600 and italic 400.
- **Type scale.** 21px for page headings, 19–20px at weight 500 for card and chart titles, 15–16px for body and subtitles, 13–14px for secondary labels. Use `font-variant-numeric:tabular-nums` for every column of numbers.
- **Surfaces.** The page is `--bg`. Cards and panels are white with a 1px `--line` border. Inner dividers use `--soft`.
- **Corners.** 2px everywhere, so nearly square.
- **Shadows.** Only on floating things (tooltips, popovers, side panels): `0 6px 24px rgba(0,0,0,0.12)`.
- **Hover.** Background goes to `--tint`, border goes to `#b9bec9` or `#8a8f9c`.
- **On or selected.** Background `--dark`, white text. A selected card gets `box-shadow:0 0 0 2px var(--dark)`.
- **Faint text.** Use `#a0a0a8` for keys, counts and placeholders, and `#55555c` for subtitles.
- **Spacing is tight.** Buttons are `padding:1px 10px`, gaps are 4–8px, card padding is 8px, and the gap between cards is 16px.

## Components

Copy these from `index.html` and do not reinvent them:

- **Buttons** (`.btn`): white, 1px border, 1px by 10px padding, tint on hover.
- **Tabs**: a sticky white top bar. The active tab is dark. Tabs can be dragged to reorder. A faint `×` turns red on hover.
- **Chips** (`.chip`): small toggles for filter values. Click toggles, shift-click keeps only this one, double-click selects all.
- **Segmented control** (`.seg`): a key, a label, then options separated by `--soft` rules, with the chosen one dark.
- **Action button with key** (`.act`): `<kbd>` in faint grey, then the label. When on, it is dark with a light grey key.
- **Hint tooltip** (`#hint`, `data-hint`): dark background, white 14px text, max 360px wide. Delay 350ms, 120ms for icons, 0ms for `(?)`. Place it below the element and flip it above near the bottom edge. Hide it on mousedown.
- **Hover card** (`#tip`): white, 380px wide. A zoomed inset sits on top and a two-column table below, with muted labels and right-aligned tabular numbers.
- **Toast** (`#toast`): dark, bottom left, with an undo button, gone after 10s.
- **Side panel** (`#rows`): slides in from the right, `min(680px, 48vw)` wide. `j`/`k` step through rows, `o` opens one, `Esc` closes. Expandable fields use small-caps labels and a coloured left rule.
- **Refresh banner** (`#refresh`): dark, bottom centre, appears when data changes elsewhere.
- **Popover list** (`#outline`): white, shadowed, rows with a thumbnail. It opens on hover and closes as soon as the mouse leaves.

## Keyboard conventions

- Single keys, no modifiers. Ignore keys while focus is in an input, textarea, select or contenteditable element, and when Cmd, Ctrl or Alt is held.
- `j`/`k` (and the arrow keys) move, `o` or `Enter` opens, `Esc` closes or deselects, `/` focuses the command or search field.
- `1`–`9` jump to an item. `[` and `]` step through values. `=` resets a filter.
- `z` undoes and `Z` redoes. `u` undoes the last delete.
- Capital letters are for rarer or global toggles (for example `P` blurs names for screenshots).
- A text command field mirrors the full state (`x:step color:frac +band`). `Enter` applies it and `Esc` reverts it.
- Offer a `(?)` button that lists every shortcut, and remember whether it was open.

## State

- Keep the view in the address bar with `history.replaceState`, so links like `/p/<page>/<card>/<panel>` reopen exactly that view.
- Use `localStorage` only for small per-viewer conveniences such as the last page or an open help panel, wrapped in `try`/`catch`.
- Save edits as they happen (PATCH per change). Never use a save button that can lose work, and never overwrite stored text that was never loaded.

## Charts

- Observable Plot 0.6.16 and d3 7.9.0 from jsdelivr. Charts use the page font at 15px, `color:#111`, white background.
- Categorical colours: Okabe–Ito by default (`#0072B2 #D55E00 #009E73 #CC79A7 #E69F00 #56B4E9 #F0E442 #000000`), and the Paul Tol sets as alternatives. Sequential: viridis (stop at 0.9 so the last colour is not too pale). Diverging: red-blue or green-purple.
- Means are dots with radius 2.8 and a white 0.9px outline. Intervals are 1px rules at 0.75 opacity, and bands are filled at 0.13 opacity. Individual observations are dots with radius 1.8–1.9 at about 0.33 opacity, jittered within their colour's lane.
- No gridlines by default. Fixed y range from the metric's theoretical minimum to maximum. Same metric means same range on every panel.
- Label lines at the line's end, not with a legend, when there are six or fewer.
- Hovering a series dims the others to 0.2 opacity.

## Do not

- Use sans-serif fonts, a component library (Material, Bootstrap, Tailwind defaults), big rounded corners, drop shadows on resting cards, or colourful buttons.
- Hide numbers that fit, or truncate text the user may need. Scroll or wrap instead.
- Add a confirmation dialog when an undo would do.
- Use emoji or icon fonts. Use small inline SVG icons at stroke width 1.3–1.5, only where a word will not fit.

## Checklist before showing it

- Every control has a key, and the key is printed on the control.
- Every non-obvious control has a `data-hint`.
- Every number column uses tabular numbers, and every chart states n and the interval kind.
- Reload the page: the view comes back from the address bar.
- Delete something: an undo toast appears.
- It works at phone width without sideways scrolling.
