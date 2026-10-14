# Changelog

All notable changes to `pgf-go` are listed here.

## 0.2026.10.13 — 2026/10/13

### New

- Compute kernel: the calculations are now separate from the drawing. New
  package option `kernel = expl3 | lua` (by default `lua` with LuaLaTeX and
  `expl3` with other engines). Both kernels draw the same diagrams.
- Captures: `goban/captures` (captured stones are removed or faded),
  `goban/captured marks` and `\pgfgoprisoners`. Lua kernel only.
- SGF games: `\sgf` inside `goban` (variations, marks and labels of the file,
  move numbers), `\sgfinfo` and `goban/sgf size`. Lua kernel only.
- `\sgfanimation`: steps through an SGF game with the `animate` package. It is
  drawn by layers, so long games stay small.
- `\sgfdiagrams`: an SGF game as a series of diagrams, as in books.
- `goban/notes` and `\pgfgomovenotes`: notes such as "3 at 1".
- `\territory` (with a polygon, or `auto` with the Lua kernel) and
  `\pgfgoscore`.

### Documentation

- Both manuals document every key and command, and the English manual is now
  complete. Fixed profile definitions, initial values and typos.

### Tests

- Tests for every new feature, with both kernels, and a check that the manuals
  document every key and command.

## 0.2025.10.13 — 2025/10/13

Bug-fix release. The user-level syntax is unchanged, but some diagrams render
differently because behaviour that used to depend on earlier diagrams in the
document is now fixed. See *Behaviour changes* below.

### Behaviour changes

- **Every `goban` starts at move 1 with Black.** Before, the move number and
  the side to play carried over from the previous `goban` in the document, so
  the same code could produce different numbers and colours depending on what
  came before it. Use `from = <n>` and `b`/`w` on `\moves` to continue a game
  on purpose. `resume` still restores remembered moves with their original
  numbers and colours.
- **Default colours no longer depend on earlier commands.**
  - `\stones` without `b`, `w` or `n` always draws black stones. Before, it
    used the colour of the next move from `\moves`.
  - `\stone` without a player always draws a neutral stone, as before. It no
    longer leaks its colour into later commands.
  - `\marks` without a player always uses the neutral player. Before, it could
    pick up the black or white mark style. To mark a stone, give its colour,
    for example `\marks[b, triangle]{C3}`.
- **`goban/forget` now clears the remembered diagram**, as the manual
  describes. Before, it only stopped recording, and a later `resume` still
  showed elements from older diagrams.
- **`\mark` and `\marks` are only defined inside `goban`.** Outside it they are
  the TeX primitives again, so page marks and running heads are not affected.
- **Partial boards only show what is inside the window.** Stones, marks and
  move numbers outside the `partial` region are no longer drawn around the
  board. Moves outside the window still count for numbering and turn. The
  window is also clipped to the board size.
- **Misspelled mark options now raise an error.** Before, an unknown option
  such as `\marks[trinagle]` was silently ignored and the default shape was
  drawn.
- **Unknown profile names now raise an error** in `\pgfgouseprofile`,
  `\pgfgousegoban`, `\pgfgouseplayers` and the `from` option of
  `\pgfgodefinegoban`/`\pgfgodefineplayer`. Before, they were silently
  ignored.

### Remember / resume

- Remembered moves now store their colour and first move number, so `resume`
  replays them with the right colours. Before, the colours could come out
  swapped.
- `\moves[forget]` and `\moves[remember]` now work. Before, they were
  ignored.
- `\stone[forget]` and `\stone[remember]` (and the player key) now apply only
  to that stone. Before, they also affected the commands after it.
- Options are stored unexpanded, so fragile values such as
  `custom = \textbf{A}` survive `resume`.
- Remembered `\marks[sequence]` restart their numbering when replayed.
- New key `goban/add to remember`, documented in the manual but missing from
  the code. It is an alias of `goban/remember`.

### Stones, moves and marks

- `move/label/font size` had no effect. It now sets the size of the move
  numbers. Without it, the size still adapts to the number of digits.
- `stone/drop shine = true` stopped compilation with the default profile,
  because the shine colour had no initial value. It now defaults to
  `gray!50!white`.
- `stone/prisoner = {<options>}` now applies its options, as documented.
  Before, the value was ignored.
- New key `/pgfgo/prisoner = {<options>}` (documented but missing). It sets
  options for every `\prisoner` and `\prisoners`, for example
  `\pgfgoset{prisoner = {fill = {color = red}}}`.
- New key `players/<player>/mark/sequence/format` (documented but missing).
  It is an alias of `mark/label/format` that also turns the sequence on.
- Mark sequences turned on with `sequence = {true}`, `sequence = {use}` or
  `sequence = {format = …}` started at 0 instead of 1. Only `sequence` without
  a value started at 1.
- A misspelled mark option raised the same error twice. It now raises it once.
- New mark shape aliases `tcircle` and `tsquare` for `t-circle` and
  `t-square`. The manual's catalogue uses them.
- The `n` shorthand selected the white player for stones and marks. It now
  selects the neutral player.
- `\stone` ignored `use i = false`, so `J` was placed one column too far to
  the right.
- `players/<player>/mark/sequence/false` turned the sequence on instead of off.
- `\pgfgocopyplayer` copied the stone line setting of the target player onto
  itself instead of copying it from the source player.
- `stone/drop shine/angle` stored the value with the wrong variable type. It
  is now a floating-point value, as the other angles are.
- The `custom` mark shape is now in the same key group as the other shapes.

### Coordinates

- `A:B` column ranges used the wrong axis bounds and gave wrong results on
  partial boards that are not square.
- Row (`3`), row range (`3:5`) and `*` selections could include coordinates
  left over from the previous command, for example from a `\stone` drawn just
  before.
- Coordinates that are not recognized (for example `c3` or `B 3`) and
  `--` lines that are neither horizontal nor vertical now produce a warning
  instead of being silently ignored.
- Points outside the board (for example `E9` on a 5×5 board) produce a warning
  and are not drawn. Before, they were drawn far away from the board and
  could push the diagram onto the next page.

### Board options

- New key `goban/label/font size` (documented but missing). The existing
  `goban/label/font` key is now applied; it defaults to `\sffamily`, as before.
- New keys `goban/grid/true` and `goban/background/true`, to switch the grid or
  the background back on after a global `false`.
- An unknown `goban` key or an invalid size, such as `\begin{goban}[19x]`, now
  raises a LaTeX error. Before, it printed the message as text inside the
  document.

### Profiles

- `\pgfgodefinegoban` and `\pgfgodefineplayer` reused the `from` option of the
  previous definition when none was given. For example, after
  `\pgfgodefinegoban[from = wain]{a}{...}`, a later `\pgfgodefinegoban{b}{...}`
  also inherited from `wain`. Each definition now starts without `from`.
- `\pgfgosetallplayers` raised an "unknown key" error and did nothing. It now
  applies its options to the neutral, black and white players.
- Removed leftover debug output (`\seq_log`, `\int_log`) that filled the
  `.log` file.

### Packaging

- `pgf-go.sty` now has `\NeedsTeXFormat{LaTeX2e}[2020/10/01]` and
  `\ProvidesPackage`, and it loads `tikz` and `xparse` with `\RequirePackage`.
- The modules (`pgf-go-*.sty`) are now looked up next to `pgf-go.sty` through
  `\CurrentFilePath`, then in the TeX path. This replaces the hard-coded
  `../../latex/` lookup. Each module has a `\ProvidesFile` line.
- About 45 internal variables are now declared before use. The package
  compiles cleanly with `\debug_on:n {check-declarations}`.
- Internal loop variables (`\variable`, `\variableA`, `\variableN`,
  `\elemento`) were renamed to private expl3 names, so they no longer overwrite
  user macros with those names.
- Variables that are assigned globally now use `\g_` names, and the constant
  coordinate regexes now use `\c_` names.
- Removed build artefacts (`.aux`, `.log`, `.synctex.gz`) from the repository
  and extended `.gitignore`.
- Added regression tests (`tests/`). They compile test documents and the
  examples, check errors and warnings, and compare every page with reference
  images. See `tests/README.md`.

### Documentation

These changes apply to both manuals (Spanish and English).

- The manuals now compile without errors. A missing space in the entry for
  `mark/sequence` (`\meta{options}(default …)`) caused three errors and broke
  the layout of the entries after it.
- `\stone` and `\stones` now state their default player: `\stone` draws a
  neutral stone and `\stones` draws black stones. Before, the manual said that
  black was the default for every stone.
- The manual now explains that each `goban` starts at move 1 with Black. It
  also says that elements outside a partial board are not drawn, and that
  points outside the board produce a warning.
- Corrected initial values to match the default profile:
  - `goban/label/sep`: 0.35cm
  - `goban/background/sep`: 0.825em
  - `stone/line/width`: 0.7pt
  - `stone/radius`: 5.5pt
  - `goban/label/font size`: the current font size
  - `move/label/font size`: automatic
  - `mark/sequence`: its default is `from = 1`
- Documented `goban/label/font`, `goban/grid/true` and
  `goban/background/true`. The English manual now also documents
  `goban/label/font size` and `move/label/font size`, which were commented
  out.
- The `move/label/font size` example now uses `0.5em`. The old value
  (`0.125em`) was unreadable once the key started to work.
- Fixed the "all stones" (`*`) example. It drew a 3×3 board inside a B2–D4
  partial window, which does not fit on a 3×3 board.
- Removed stray `;` after `\marks` in the examples. They produced "Missing
  character" messages in the log.
- Rebuilt the PDF manuals and the example PDFs with this version.

## 0.2025.03.10 — 2025/03/10

- Added features to the coordinate system and rounded corners.

## 0.2025.03.07 — 2025/03/07

- Partial release.
