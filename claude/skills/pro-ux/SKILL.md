---
name: pro-ux
description: Boyd's "pro-UX" house style for any interface, dashboard, report page, tool or chart. It means quiet greys and hairline borders, EB Garamond, dense information shown by default, detail on hover that never covers the page, panels that peek on hover and dock on click, toggles that never move under the cursor, and keyboard shortcuts for everything, aimed at power users. Use when the user says "pro-UX", "pro UX", "in the explorer style", "like the plot explorer", or asks for a page, dashboard, or tool without naming another style. The reference implementation is the Plot Explorer at /Users/brk/projects/mats/plotting/explore/index.html.
---

# pro-UX

The style of the Plot Explorer (`/Users/brk/projects/mats/plotting/explore/index.html`).
In one line: **Tufte-style, keyboard-first, information-dense, details on demand.**
When in doubt, open that file and copy what it does. Its `<style>` block (lines 11–224) is the source of truth for every value below.

**The interactions matter more than the look.** A page can copy every colour and font here and still feel wrong. That happens when hovering does nothing, a tooltip covers what the user is reading, a toggle jumps away after one click, and the cards can't be moved or renamed. Read the Hover, Click, Panels and Cards sections before writing any code.

## Principles

- **Show the data, not the chrome.** No gradients, no rounded cards, no icons where a word fits, no decorative colour. Every pixel carries information.
- **Dense by default.** Put everything a power user needs on screen at once: counts, n, interval kind, filters in force, ids. Do not hide information behind clicks if it fits.
- **Hover reveals, click commits.** Hovering anything highlights it everywhere it appears and dims the rest. Hovering a panel's button floats the panel; clicking docks it. Clicking makes any hover state stick.
- **Nothing moves under the cursor.** A control that changes the layout stays exactly where it was after the click, so a second click in the same spot undoes the first (see Panels and toggles).
- **Say it once.** When every row holds the same value (the same prompt, the same id prefix), state it once above the table and give the space to something that differs. A column with no values goes last, 28px wide.
- **Explain in hints, not captions.** A sentence about how the interface works goes in the hint of the tab, heading or control it explains, never as a caption that pushes the content down.
- **Every action has a key.** Show the key beside the control (`<kbd>c</kbd>colour`), so the interface teaches its own shortcuts.
- **Nothing is lost.** Deletes give an undo toast. `z`/`Z` undo and redo. State lives in the address bar, so every view is a shareable link.
- **The user owns the layout.** Cards and tabs can be dragged, renamed, minimised, resized, duplicated and deleted, and the layout persists.
- **Black and white, colour only for data.** Text, borders and controls stay black, white and grey. Dark `#3a3a40` marks "on" or "selected". Red appears only for errors and destructive hovers. Every other colour on the page encodes a value or an identity (see Colour).
- **Titles say what the reader sees.** Charts carry a title, a subtitle naming what is pooled or filtered, and "mean ± 95% CI (t), n = 12 per point".

## Hover

There are two kinds of hover popup. Never mix them.

| | Control hint (`#hint`) | Data card (`#tip`) |
|---|---|---|
| For | Explaining a button, tab, header, `(?)` | Data that needs more room than the page has: a chart's zoom inset, a mark's full record |
| Look | Dark `--dark` box, white 14px plain sentence | White card, 380px wide, `0 6px 24px rgba(0,0,0,0.12)` shadow |
| Delay | 350ms; 120ms for icons; 0ms for `(?)` | **None.** It appears and updates on every mouse move |
| Position | Just below the element, flipped above near the bottom edge | **Static**: see below |

**Prefer no data card.** Add one only when both of these hold:
1. It shows clearly more than the page already shows, and that extra cannot fit in the page itself. A card that repeats the hovered table row is noise; the user had exactly such cards removed from two tables.
2. It covers nothing the user is looking at.

In order of preference, put hover detail:
1. **In the page.** Dense by default: if it fits, show it.
2. **In the hovered card's header.** A readout slot at the right of the card header, sized up front, whose text changes in place as the cursor moves ("aggregate-rate · 4,029 tokens · 61/100"). It reserves its space when the card renders, so nothing reflows while the cursor moves, and it covers nothing.
3. **In a data card**, only when the first two cannot hold it, laid out as below.

**The data card does not follow the cursor.** Like the item tooltip in Factorio, it sits at a fixed place. It is `position:fixed; top:60px` (below the sticky bar), against the side of the screen away from what is hovered. If the hovered chart's centre is on the right half of the window, the card goes at `left:16px`, otherwise at `right:16px` (`placeTip` in the explorer). It never covers the thing being looked at, never jitters, and the eye always knows where to find it. Its contents update in place as the cursor moves. A full-width table has no far side, so the card would sit on top of the rows being read: tables use the header readout instead.

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

## Panels and toggles

**Nothing moves under the cursor.** Every control that changes the layout (dock and float, collapse and expand, more and less, show and hide) stays exactly where it was after the click. The user clicks, looks, and clicks the same spot to undo, without hunting for the control. Leaving the page (following a link, opening an item) is the only exception. The usual breakages, and their fixes:
- A "more…" button that disappears once clicked, leaving "less" at the far end of the expanded text: put "less" where "more" was.
- A toggle hanging off the bottom edge of what it expands, so it slides down when clicked: move it into a row that never moves, such as the header.
- Show and hide controls in different places (a show toggle at the left edge, a close × at the far right of the opened panel): one button, one place, both states.
- A label that changes width ("Collapse" becomes "Expand") in a right-aligned toolbar: give the button a fixed width.
- A fixed-position button over a panel that docks: keep the button fixed, and pad the panel's header so the button never covers it.

Test every toggle: click it, check that `document.elementFromPoint` at the same point still returns the same control, click again, and check the page is back where it started.

**Peek or dock.** Secondary panels (a sidebar listing items, an outline, filters) are hidden by default behind one small button with an inline SVG icon, in a fixed spot: the top-left corner for a page sidebar, the top of the column for an in-page panel.
- **Hover** the button: the panel floats over the content, with a shadow. It closes 250ms after the pointer leaves both the button and the panel.
- **Click** the button: the panel docks. It takes layout space beside the content, stays open, and the choice persists across reloads.
- **Click again**: it floats again. The pointer is still over the button, so the panel stays open until the pointer leaves.
- One key (`b` for the sidebar) does what the click does, and the panel header shows the state and the key ("<kbd>b</kbd> docked").
- The filled half of the icon shows whether the panel is docked.

**List beside item on wide screens.** When the window has room for both (1200px for a 300px list), opening an item docks the list of its siblings automatically: list on the left, item on the right, the open item highlighted, and a click on another row swaps the item without leaving the page. Clicking the button records an explicit choice that overrides the automatic one; an "auto" link in the panel header clears it. Narrow windows float the list.

**Expand and collapse.**
- A collapsible card or item has a caret at the left of its heading: › closed, ⌄ open. The caret stays on the heading in both states. Prefer it to a "more…" button.
- Truncated content gets a "more" control only when a lot is hidden, more than about four lines; with less, show everything. The control sits in the horizontal centre of the faded bottom edge and says how much it hides ("▾ 226 more lines"). Clicking anywhere on the faded strip also expands.
- Anything foldable that repeats down a page or column (a JSON argument per table row, a tree) gets expand-all and collapse-all in its header. Trees open fully by default, with a depth stepper (− depth 2/5 + all) of fixed width.

**Say where a click leads.** A row that opens a list of items gets a disclosure caret that expands the items as sub-rows in place, each linking straight to its item. A row that goes to a single item says so ("1 sample →").

**Preferences.** Every new feature of a page has an off switch in a Preferences section at the bottom of the sidebar, with the theme (system, light, dark). One capital key flips the whole page back to its plain look.

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

**Use a gradient wherever a quantity is ranked or compared.** For example, in a table of apps by time spent, mark each row's time with a **value bar**: a small vertical bar, inline, just after the number. Height and colour both encode the value, so the 1st percentile and the 99th differ at a glance. The smallest value gets a bar as thin as an underscore (2px) in the faint end of a sequential map; the largest gets a bar as tall as the digits (0.68em) in the strong end. Not an underline, and not a fill:

```html
<span class="q" style="--q:#420a68; --qt:1">5h 32m</span>     <!-- largest: inferno at 0.2, digit height -->
<span class="q" style="--q:#f98e09; --qt:0.1">2m 30s</span>   <!-- small: inferno at 0.75, near underscore height -->
```
```css
.q::after { content:""; display:inline-block; width:4px; margin-left:0.35em; vertical-align:baseline;
            height:calc(2px + var(--qt) * (0.68em - 2px)); background:var(--q); }
```

- **Clip the ends.** On white, keep `t` in about [0.1, 0.85] for inferno and magma, and [0, 0.9] for viridis. The palest end vanishes against white, and the darkest end looks like text.
- **Scale it the way the data spreads.** Durations and counts are heavy-tailed, so map them on a log scale or by rank. Otherwise one large value makes every other row the same colour.
- **The strong end means "more"** (more time, more change, a higher score). Reverse the map when needed; the explorer names the reversed form `<map>-reversed`.
- **Diverging maps sit their midpoint on the real middle**: zero change, the baseline or the score's midpoint. Never the data's mean.
- **Every gradient gets a key.** Put a small ramp (`.sw .ramp`, 11px high) with its end values in the card subtitle: "bar: time spent, 2m ▭▭▭ 5h 32m". For value bars in a table, the column header carries a wedge: an 18px ramp clipped to a triangle that rises from left to right.
- **One encoding per colour per view.** If the timeline colours apps by identity (categorical), the same colours mean the same apps in the tables. In that case, a time gradient goes on a different element, such as the value bar, never on the swatch.
- **One colour, one kind, everywhere.** Define each categorical palette once, in one module, and import it into every view: message borders, timeline spans, table strips and keys. Two views that give "tool call" different colours teach the reader nothing.
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
- **Type scale.** 21px for page headings, 19–20px at weight 500 for card and chart titles, 15–16px for body and subtitles, 13–14px for secondary labels. Nothing below 12px, axis ticks and chart gutters included: tiny text is the complaint that comes first. Use `font-variant-numeric:tabular-nums` for every column of numbers.
- **Dark mode is designed, not inverted.** Inverting the light palette gives muddy brown and purple fills. Use near-black surfaces (page `#141416`, cards `#1b1b1e`), light grey text (`#d9d9de`), hairlines at `#33333a`, a light chip for "on", and recheck every data colour for contrast. Give the favicon a fill for each colour scheme (a `prefers-color-scheme` rule inside the SVG), or it vanishes on a dark tab strip.
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
- **Copy icon**: a discreet two-squares SVG at the top right of any block the user may want verbatim (a message, a command, a record). Faint `#a0a0a8`, darker on hover, shown on hover or keyboard focus. It copies the text exactly as sent, not as rendered, and shows a check and "copied" in the same spot for 900ms without moving.
- **Peek-or-dock button**: see Panels and toggles.

## Content

**Tables.**
- Resizing one column never moves or resizes the others.
- A column with no values in any row goes last, 28px wide.
- A column whose every value is the same is shown once, above the table, and its space goes to something that varies. The same holds for a prefix every id shares: strip it from each row and state it once.
- A soft-wrap preference shows whole cells, with rows growing to fit.
- Make the row as useful as its width allows. When the input column only repeats, a per-row strip of coloured spans (one per message or step, coloured by kind, on one x scale for the whole table) says more.

**Structured text.** JSON and XML render as foldable, coloured trees, fully open by default, with a depth stepper and a "raw" toggle. Parse tolerantly: strict, then lenient, then repaired (trailing text dropped, unclosed tags closed). Say what was repaired, and fall back to the raw text with the error. A JSON value in a table cell shows a one-line summary (`{monitor_model, trajectories, +2}`) that opens into the tree.

**Show the payload in its natural form.** Render what something means, not how it was serialised. A simple shell command reads as a terminal icon and the command, `[>_] cat app.py`, not `bash_session action: "type_submit", input: "cat app.py"`. Fall back to the full argument list only when the call is complicated. The user should never hunt for the one thing they came to read.

**No empty containers.** A header over nothing (an "assistant" block whose only content moved elsewhere) goes.

**Paths and breadcrumbs.** Never clip the last segment, the name of the open thing. Shrink the middle segments with an ellipsis and their full name in a hint, and fold the rest into a "…" that lists them. Each separator `›` opens a menu of that folder's other entries, so the user can step sideways.

**Timelines.** A timeline shows spans, not ticks: each stretch coloured by what it was (user turn, reasoning, response, tool call, scoring, error), with a key listing only the kinds present. An unlabelled marker explains nothing. When time positions collapse (a replay where every event starts within milliseconds), lay the spans out by order or by size and say which in the key. Never print the same axis label twice.

## Keyboard conventions

- Single keys, no modifiers. Ignore keys while focus is in an input, textarea, select or contenteditable element, and when Cmd, Ctrl or Alt is held. A web component hides its real text box inside a shadow root, so `document.activeElement` reports the wrapper: walk `shadowRoot.activeElement`, or check `event.composedPath()`, before deciding nobody is typing.
- Never take Cmd-F or Ctrl-F from the browser. If a virtualised list hides off-screen text from the browser's find, provide a find bar that searches it, styled like the page.
- A search field runs about 500ms after typing pauses, with no Run button. Enter runs it at once. A search that costs money (a model call) waits for Enter.
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
- Hover follows the Hover section: a pointer ring on the nearest point, the series promoted, the rest at 0.2, and a readout in the card header. Add the static data card with a zoom inset only where marks are too thin or crowded to read.
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

- **A hover card on every row.** It repeats what the row already shows and covers the rows below. Show detail in the page or in the card header's readout; use a data card only when it adds what cannot fit and covers nothing.
- **The data tooltip follows the cursor** and covers the bars next to it. Pin it to a fixed side of the screen.
- **Data details go into the dark hint** as plain lines of text after a 600ms delay. Data goes in the page, the header readout or the white card, instantly.
- **Toggles jump away.** "more…" vanishes after a click, an expander slides down with what it expands, show and close sit at opposite ends. Keep each toggle under the cursor in both states.
- **Panels always open or always shut.** An outline or item list fixed open wastes a third of the screen; one only reachable from a menu is never used. Hide it behind a peek-or-dock button.
- **Explanations as captions.** An italic sentence on every model call about how the log works. Move it to the hint of the tab or heading.
- **Raw argument dumps.** `bash_session action: "type_submit", input: "cat app.py"` where `[>_] cat app.py` would do.
- **The same value in every row.** An input column that repeats one prompt eighteen times. Say it once and use the column for what differs.
- **Shortcuts fire while typing.** A key handler that checks only `document.activeElement` misses text boxes inside web components.
- **Hover highlights nothing.** Only a crosshair or a background tint moves, and the rest of the chart stays at full strength. Promote the hovered entity and dim the others.
- **Views are not linked.** Hovering a table row leaves the chart unchanged, so the user must click (pin) to find where it is. Hover should already show it.
- **Thin slivers stay unreadable.** A dense timeline needs the zoom inset in the data card.
- **Cards are fixed.** No grip, no rename, no minimise, no resize, no delete with undo, and no tabs. Every card needs the full header.
- **Minimise only hides.** A minimised card that collapses to its title throws away the overview. It should shrink to the glance-sized charts.
- **Ranked lists have no gradient.** A table sorted by time spent shows every row in the same black. Give each value a value bar, its height and sequential colour set by the value, with a wedge key in the header.
- **Gradients are splattered.** Colour that encodes nothing, or a categorical map used for an ordered quantity.

## Checklist before showing it

- Every control has a key, and the key is printed on the control.
- Every non-obvious control has a `data-hint`.
- Hover any data: its detail appears at once, in the page or the card header's readout, covering nothing. Any data card shows something the page cannot, at a fixed side of the screen, with a swatch, bold name, table and click note.
- Click every layout toggle, then click the same spot again: the toggle was still under the cursor and the page is back where it started.
- Hover each panel button: the panel floats. Click: it docks. Click again: it floats. The button never moved.
- No column repeats one value in every row, no text is below 12px, and no explanatory caption sits in the content.
- Type in every text field, web components included: no shortcut fires. Cmd-F finds text that is scrolled out of view.
- Hover any entity in one view: it is highlighted and the rest dimmed in every view that shows it.
- Hover a view-changing control: the result previews, and leaving reverts it.
- Drag a card by its grip, double-click its title, click its header, drag its resize handle, delete it and undo. Do the same for a tab.
- Minimise every card: the page becomes a readable overview of small charts with the same lines and colours. Expand one: it has the full title, subtitle, legend and axis labels.
- Every number column uses tabular numbers, and every chart states n and the interval kind.
- Every colour on the page encodes something you can name. Every ranked list and comparison uses a sequential or diverging gradient with a key.
- Reload the page: the view and layout come back.
- It works at phone width without sideways scrolling.
