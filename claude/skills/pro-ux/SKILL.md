---
name: pro-ux
description: Boyd's "pro-UX" house style for any interface, dashboard, report page, tool or chart. It means quiet greys and hairline borders, EB Garamond, dense information shown by default, more detail on hover, and keyboard shortcuts for everything, aimed at power users. Use when the user says "pro-UX", "pro UX", "in the explorer style", "like the plot explorer", or asks for a page, dashboard, or tool without naming another style. The reference implementation is the Plot Explorer at /Users/brk/projects/mats/plotting/explore/index.html.
---

# pro-UX

The style of the Plot Explorer (`/Users/brk/projects/mats/plotting/explore/index.html`).
In one line: **Tufte-style, keyboard-first, information-dense, details on demand.**
When in doubt, open that file and copy what it does. Its `<style>` block (lines 11–224) is the source of truth for every value below.

**The interactions matter more than the look.** A page can copy every colour and font here and still feel wrong. That happens when hovering does nothing, the tooltip chases the cursor, and the cards can't be moved or renamed. Read the Hover, Click and Cards sections before writing any code.

## Principles

- **Show the data, not the chrome.** No gradients, no rounded cards, no icons where a word fits, no decorative colour. Every pixel carries information.
- **Dense by default.** Put everything a power user needs on screen at once: counts, n, interval kind, filters in force, ids. Do not hide information behind clicks if it fits.
- **Hover reveals, click commits.** Hovering anything shows more about it at once, highlights it everywhere it appears, and dims the rest. Clicking makes that state stick.
- **Every action has a key.** Show the key beside the control (`<kbd>c</kbd>colour`), so the interface teaches its own shortcuts.
- **Nothing is lost.** Deletes give an undo toast. `z`/`Z` undo and redo. State lives in the address bar, so every view is a shareable link.
- **The user owns the layout.** Cards and tabs can be dragged, renamed, minimised, resized, duplicated and deleted, and the layout persists.
- **Black and white, colour only for data.** Text, borders and controls stay black, white and grey. Dark `#3a3a40` marks "on" or "selected". Red appears only for errors and destructive hovers. Every other colour on the page encodes a value or an identity (see Colour).
- **Titles say what the reader sees.** Charts carry a title, a subtitle naming what is pooled or filtered, and "mean ± 95% CI (t), n = 12 per point".

## Hover

There are two kinds of hover popup. Never mix them.

| | Control hint (`#hint`) | Data card (`#tip`) |
|---|---|---|
| For | Explaining a button, header, `(?)` | Anything that is data: a mark, a bar, a table row, a log row |
| Look | Dark `--dark` box, white 14px plain sentence | White card, 380px wide, `0 6px 24px rgba(0,0,0,0.12)` shadow |
| Delay | 350ms; 120ms for icons; 0ms for `(?)` | **None.** It appears and updates on every mouse move |
| Position | Just below the element, flipped above near the bottom edge | **Static**: see below |

**The data card does not follow the cursor.** Like the item tooltip in Factorio, it sits at a fixed place. It is `position:fixed; top:60px` (below the sticky bar), against the side of the screen away from what is hovered. If the hovered chart's centre is on the right half of the window, the card goes at `left:16px`, otherwise at `right:16px` (`placeTip` in the explorer). It never covers the thing being looked at, never jitters, and the eye always knows where to find it. Its contents update in place as the cursor moves.

**What goes in the data card**, top to bottom:
1. **Zoom inset** (charts and timelines). A live 3× magnified view of the neighbourhood under the cursor, 378 by 240, redrawn on every mouse move, with the hovered item highlighted in it. ⌥-scroll or pinch changes the zoom from 1× to 40×. The caption reads "3.0× zoom · pinch or ⌥ scroll to change". It is what makes thin slivers and crowded points readable.
2. **Heading.** The entity's colour swatch (11px square) and its name in weight 600.
3. **Subtitle** (optional). One muted line of context, such as a window title or a description.
4. **Table.** Muted labels on the left, values on the right, right-aligned in tabular numbers. Group rows with a `--soft` rule between groups. Include everything known about the item: value, interval, n, start and end, duration, ids, the filter or reduction that produced it.
5. **Note.** A 13px muted line saying what a click will do: "click to see the 12 rows behind this point".

**Highlight on hover, dim the rest.** The hovered entity is promoted: redrawn on top with a thicker stroke (2.4px lines, 3.6px dots with a white outline), or outlined in `--dark`. Everything else in that view drops to `opacity:0.2` with an 80ms transition. In a table, the hovered row gets the `--tint` background. In a timeline or bar chart, every other bar that is not this entity dims.

**Linked highlighting across views.** An entity is the same thing everywhere it appears, so hovering it in any view highlights it in all of them. Hovering a row in a summary table promotes that entity's marks in the chart or timeline and dims everything else there. Hovering a mark in the chart tints its row in every table and log, scrolling it into view only if the user asked. Legends work the same way: hovering a legend entry is hovering that entity.

**Hover previews, click commits.** Any control that changes the view previews its result when hovered: after 400ms, or 250ms if a preview is already showing. Leaving the control reverts the preview, and clicking keeps it (`preview` and `endPreview` in the explorer). For entities, hover is a temporary highlight. Click pins it: the pin persists, goes in the address bar and shows in the scope line. `Esc` unpins.

## Click

- **Click a data mark to drill down.** Open the side panel (`#rows`) with the raw records behind it. Put a header in bold with what was clicked, the value, its interval and n. Add a histogram of the records' values, where clicking a bar filters to that bar. Records list highest first, each with a score badge, ids and a one-line preview. Clicking a record expands its fields. `j`/`k` step, `o` opens, `Esc` closes.
- **Click a card to select it.** It gets the dark outline, and the keyboard acts on the selected card.
- **Click empty space in a card header to minimise it** (see Cards).
- **Mousedown cancels hover.** It hides hints and popovers so they never sit under a drag or a click.

## Cards and tabs

Any page with more than one chart or table is a set of **cards**. Any tool with more than one set is a row of **tabs** (pages). Both belong to the user. Save every change as it happens: PATCH to the server, or `localStorage` if the page has no server.

**Card header** (`.ch`), left to right:
- **Grip** `⠿` in `#b0b0b8`. Dragging starts only from the grip, so text in the card stays selectable. While dragging, the card is at `opacity:0.35`. It drops before or after the card under the cursor, split by that card's vertical midpoint, and the new order is saved.
- **Title**, 19–20px at weight 500. Double-click opens an inline input over it (`inlineEdit`): `Enter` or blur saves, `Esc` cancels. Clearing it brings back the automatic title, shown in `#9a9aa2` when empty.
- **Subtitle**: muted counts and scope ("18 distinct · share of active time").
- A spacer, then small buttons: **copy** (copies the card's view as text, then says "copied" for 900ms), **duplicate** (inserted right after), and **×** (delete).
- Clicking anywhere else in the header **minimises** the card to one line: title plus a strip of miniature charts. Clicking again restores it.

**Card body:**
- A **resize handle** in the bottom-right corner of each chart (`.rz`, a two-line diagonal glyph, `ns-resize`). Dragging sets the height from 140 to 1400px. Double-click resets it.
- Double-click an **axis label** to rename it, just like a title.
- A dashed `+ new card` button closes the list.

**Delete** never asks. The card goes, and the toast says `deleted "Apps"` with an undo button for 10 seconds. `u` also undoes it.

**Tabs** (sticky white bar at the top):
- The active tab is dark.
- Drag to reorder. Dropping on `+` puts the tab last.
- Double-click to rename in place.
- A faint `×` turns red on hover, and deleting gives an undo toast.
- `+` adds a page.
- **Hovering a tab for 160ms opens an outline**: a popover just under the tab listing that page's cards, numbered, each with a thumbnail and a title. Clicking an entry switches page, scrolls to the card and flashes its outline for 1.2s. The outline closes the moment the mouse leaves both the tab and the list, and mousedown on the tab closes it.

## Emphasis in text

- **Labels muted, values bold.** "app: **Firefox** · device: **Mac**". Labels are `--mute`; values are `--fg` at weight 600.
- **Entities carry their colour.** Wherever an entity's name appears (table, tooltip, legend, log, side panel), put its colour swatch before it: a 9–11px square in the same colour as its chart marks.
- **Scores get coloured badges.** A value on a known scale gets a small bordered badge with its background from a diverging map (PRGn), and white text when the background is dark. Show it as "7/10", not a bare 7.
- **Underline what differs.** When sibling panels share most of a title, underline the words that differ (`text-decoration:underline 1.5px; text-underline-offset:3px`).
- **Small caps for field names** in expanded records, with a coloured left rule per field.
- Red is for errors and failures only.

## Colour

Colour is a data channel, not decoration. Before colouring anything, name what the colour encodes. If you can't, leave it black, white or grey. Pick the kind of map from what the values are:

| Values | Map | Choices (d3 interpolators) |
|---|---|---|
| Identities, unordered, at most 8 | Categorical | Okabe–Ito (default), `tol-bright`, `tol-vibrant`, `tol-muted` |
| An ordered quantity: time spent, count, rank, recency, size | Sequential | `inferno`, `magma`, `viridis`, `cividis`, `plasma` |
| A quantity with a meaningful middle: change from yesterday, above or below a baseline, a score around its midpoint | Diverging | `red-blue` (`RdBu`), `brown-teal` (`BrBG`), `purple-orange` (`PuOr`), `green-purple` (`PRGn`) |

**Use a gradient wherever a quantity is ranked or compared.** For example, in a table of apps by time spent, give each row a colour from a sequential map by its time. Heavy use gets the strong end and light use the faint end. Apply the colour as an underline under the value and the name, not as a fill:

```html
<span class="q" style="--q:#420a68">5h 32m Twitter</span>   <!-- heavy: inferno at 0.2 -->
<span class="q" style="--q:#f98e09">2m 30s WhatsApp</span>  <!-- light: inferno at 0.75 -->
```
```css
.q { text-decoration:underline 2.5px var(--q); text-underline-offset:4px; text-decoration-skip-ink:none; }
```

- **Clip the ends.** On white, keep `t` in about [0.1, 0.85] for inferno and magma, and [0, 0.9] for viridis. The palest end vanishes against white, and the darkest end looks like text.
- **Scale it the way the data spreads.** Durations and counts are heavy-tailed, so map them on a log scale or by rank. Otherwise one large value makes every other row the same colour.
- **The strong end means "more"** (more time, more change, a higher score). Reverse the map when needed; the explorer names the reversed form `<map>-reversed`.
- **Diverging maps sit their midpoint on the real middle**: zero change, the baseline or the score's midpoint. Never the data's mean.
- **Every gradient gets a key.** Put a small ramp (`.sw .ramp`, 11px high) with its end values in the card subtitle: "underline: time spent, 2m ▭▭▭ 5h 32m".
- **One encoding per colour per view.** If the timeline colours apps by identity (categorical), the same colours mean the same apps in the tables. In that case, a time gradient goes on a different element, such as the underline, never on the swatch.
- **No gradient where nothing is compared.** A single number, a label, a button or a header stays black.

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
- **Chips** (`.chip`): small toggles for filter values. Click toggles, shift-click keeps only this one, double-click selects all.
- **Segmented control** (`.seg`): a key, a label, then options separated by `--soft` rules, with the chosen one dark.
- **Action button with key** (`.act`): `<kbd>` in faint grey, then the label. When on, it is dark with a light grey key.
- **Toast** (`#toast`): dark, bottom left, with an undo button, gone after 10s.
- **Side panel** (`#rows`): slides in from the right, `min(680px, 48vw)` wide. See Click.
- **Refresh banner** (`#refresh`): dark, bottom centre, appears when data changes elsewhere.
- **Inline editor** (`.inl`): a fixed-position input placed over the text being renamed, with a shadow.

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
- Colours follow the Colour section. Okabe–Ito is `#0072B2 #D55E00 #009E73 #CC79A7 #E69F00 #56B4E9 #F0E442 #000000`. A numeric colour dimension defaults to viridis. Offer every map as a clickable swatch with its ramp (`#cmaps`), and let a second click reverse it.
- Means are dots with radius 2.8 and a white 0.9px outline. Intervals are 1px rules at 0.75 opacity, and bands are filled at 0.13 opacity. Individual observations are dots with radius 1.8–1.9 at about 0.33 opacity, jittered within their colour's lane.
- No gridlines by default. Fixed y range from the metric's theoretical minimum to maximum. Same metric means same range on every panel.
- Label lines at the line's end, not with a legend, when there are six or fewer.
- Hover follows the Hover section: a pointer ring on the nearest point, the series promoted, the rest at 0.2, and the static data card with a zoom inset.
- An ordered colour dimension (a fraction, a step, a size) gets a sequential map, so the lines read as a gradient: in the explorer, yellow for 0.005 through to black for 1. The order of the lines is then visible before reading any label.

## Two levels of detail: glance and read

Every chart exists at two sizes, and the user toggles between them by clicking the card header. Read the two reference pictures beside this file before drawing a chart: `glance.png` (minimised) and `read.png` (expanded). They show the same card at each size, and they are the target.

**Glance (minimised card).** For someone who already knows what the axes are and wants to see how the lines move. In the explorer it's a 150 by 86 pixel panel, in a horizontal strip beside the card title, with one panel per facet:
- **Kept:** every line, dot, band and colour, exactly as in the full chart.
- **Title:** only the facet name ("Distress", "Greek", "Bird"), 11.5px, muted.
- **Axes:** only the two end ticks on each axis ("0" and "100"), 9.5px, tick length 2. No axis labels.
- **Gone:** the legend, the subtitle, the gridlines and the resize handle.

**Read (expanded card).** For when the user has forgotten what is what:
- **Title:** the full chart title, with the words that differ between panels underlined ("Judge score vs finetuning step — <u>Greek</u>").
- **Subtitle:** model, statistic and interval, and n per point ("gemma-3-27b-it · mean ± 95% CI (t) · n = 42–50 per point").
- **Legend:** a colour legend.
- **Axes:** labelled, every tick, light gridlines.
- **Size:** panels at their full height, which the resize handle sets.

Rules:
- Strip labels, not data. The glance has the same marks and colours as the full chart, so its shape matches what expands.
- The same y range in every panel at both sizes, so the panels compare at a glance.
- The glance must still be honest: keep the interval bands, and keep the y end ticks so a flat line at 0 never looks like one at 100.
- A page of minimised cards is an overview of everything, one line per card. Remember each card's state and restore it on reload.

## Do not

- Use sans-serif fonts, a component library (Material, Bootstrap, Tailwind defaults), big rounded corners, drop shadows on resting cards, or colourful buttons.
- Hide numbers that fit, or truncate text the user may need. Scroll or wrap instead.
- Add a confirmation dialog when an undo would do.
- Use emoji or icon fonts. Use small inline SVG icons at stroke width 1.3–1.5, only where a word will not fit.

## Common misses

These are the mistakes a model makes when it copies the look but not the behaviour:

- **The data tooltip follows the cursor** and covers the bars next to it. Pin it to a fixed side of the screen.
- **Data details go into the dark hint** as plain lines of text after a 600ms delay. Data goes in the white card, instantly, with a heading, swatch, bold values and a table.
- **Hover highlights nothing.** Only a crosshair or a background tint moves, and the rest of the chart stays at full strength. Promote the hovered entity and dim the others.
- **Views are not linked.** Hovering a table row leaves the chart unchanged, so the user must click (pin) to find where it is. Hover should already show it.
- **Thin slivers stay unreadable.** A dense timeline needs the zoom inset in the data card.
- **Cards are fixed.** No grip, no rename, no minimise, no resize, no delete with undo, and no tabs. Every card needs the full header.
- **Minimise only hides.** A minimised card that collapses to its title throws away the overview. It should shrink to the glance-sized charts.
- **Ranked lists have no gradient.** A table sorted by time spent shows every row in the same black. Underline each row in a sequential colour by its value, with a key.
- **Gradients are splattered.** Colour that encodes nothing, or a categorical map used for an ordered quantity.

## Checklist before showing it

- Every control has a key, and the key is printed on the control.
- Every non-obvious control has a `data-hint`.
- Hover any data: the card appears at once, at a fixed side of the screen, with a swatch, bold name, table and click note.
- Hover any entity in one view: it is highlighted and the rest dimmed in every view that shows it.
- Hover a view-changing control: the result previews, and leaving reverts it.
- Drag a card by its grip, double-click its title, click its header, drag its resize handle, delete it and undo. Do the same for a tab.
- Minimise every card: the page becomes a readable overview of small charts with the same lines and colours. Expand one: it has the full title, subtitle, legend and axis labels.
- Every number column uses tabular numbers, and every chart states n and the interval kind.
- Every colour on the page encodes something you can name. Every ranked list and comparison uses a sequential or diverging gradient with a key.
- Reload the page: the view and layout come back.
- It works at phone width without sideways scrolling.
