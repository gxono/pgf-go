# Changelog

All notable changes to `pgf-go` are listed here.

## Unreleased

### New

- `shift = {columns, rows}` in `\stones`, `\stone`, `\moves` and `\marks`:
  moves the coordinates of the command (to the right and up, whatever the
  labels of the border); points off the board are dropped with a warning.
  With a pattern in a macro, the same shape goes anywhere.
- `fill/pattern = {name, color}` in `stone/fill`, `mark/fill`,
  `territory/fill` and `goban/background/fill`: a TikZ pattern (of
  `patterns` or `patterns.meta`, now loaded too) over the fill color, with
  its opacity; `pattern/color` is initially `black`, and `pattern = false`
  removes it. `fill/color = none` leaves only the pattern (not in the
  background). The marks `t-circle` and `t-square` use the pattern of the
  stone; the marks on empty points and `dim` repeat the pattern of the
  background.
- `layout/valign` (`top` or `bottom`, initially `top`): with `bottom`, the
  boards of a row of the grid end at the same height, and their captions and
  notes start on the same line.
- `goban/label/letter case` (`upper` or `lower`, initially `upper`): the
  letters of the coordinates on the border, in upper or lower case. The
  coordinates of the commands are read as before.
- The profile `draft`: black and white, with thin lines, no border on the
  background, and lines where there is a fill (black stones, filled marks and
  territory, a direction for each player).
- `goban/arrow` and `goban/line`: the style of the arrows and lines of the
  board, with the keys of `\arrow` and `\line` (except `forget`). Profiles
  set it, and using a profile resets it, as the rest of the board. Every
  profile now defines it: `pgfgo` and `pgfgosmooth` draw them in
  `red!80!black`, `wain` in the color of its grid, `simple` and `draft`
  thinner, and `shell`, `yunzi` and `baduktv` without a halo.
- `partial` of `\sgfdiagrams`, `\sgfproblem` and `\sgfanimation` also
  takes two corners, as in `goban/partial` (`partial = K10:T19`): every board
  shows that part, even if the file has a view (`VW`).
- `goban/scale line width` (initially `false`): `scale` also multiplies the
  width of the lines (grid, border, stones, marks, arrows, lines and
  territory). Without it, as before, `scale` changes only the sizes. With
  `layout/fit`, which chooses the scale to fill the column, the widths do not
  change.
- `origin` (`top left`, `top right`, `bottom left` or `bottom right`,
  initially `top left`) and `transpose` (initially `false`) in
  `\pgfgodefinesgf`: the corner where the point `aa` of the file goes, and
  whether the first letter of each point is the row (the size is turned
  too). Together, the eight symmetries of the board. Everything read from the
  file follows them, and so does `partial = auto`; the coordinates written in
  the commands (`variation = {R16, P17}`) are those of the board.
- `name` in `\sgfdiagrams` and `\sgfproblem`: each diagram is a named
  `goban`, for `resume` and `\pgfgoview`. In `\sgfdiagrams`, the name
  followed by the number of the caption (`var1`, `var2a`); in `\sgfproblem`,
  the statement is `name` and the variations `name1`, `name2`... (with
  several games, `name3` and `name3-1`). Each one keeps the whole position,
  with the captures resolved.
- Columns of two capital letters after `Z`, for boards of more than 25
  columns: `AA5`, `AA:AC 3`, `partial = AZ5:BG8`, `variation = {AB29}`,
  `(go cs:AA5)`. Without `use i`, the I is skipped only between `A` and `Z`:
  `AI` is a column, as in the labels on the border.
- `links` in `\sgfproblem` (initially `false`): with `hyperref`, the caption
  of the statement links to its first solution, and the caption of each
  solution links back to the statement, also across two `\sgfproblem`
  (`solutions = false` and `statement = false`). The targets are written to
  the `.aux`, so it takes two compilations; a link whose target is missing is
  not set.
- The package option `pages` (LuaLaTeX and `kernel = lua`): the document
  comes out with one `goban` per page, each one the size of its board, and
  nothing else (no text, captions, views or animations). At the end, the
  package writes `<document>-pages.lua`: `texlua <document>-pages.lua
  [svg | png | pdf] [resolution]` turns each page into a file named after the
  `goban` (or `diagram-<page>`) in the folder `<document>-pages`, with
  `pdftocairo`, `dvisvgm`, `pdftoppm` or `pdfseparate`. New files:
  `pgf-go-pages.sty` and `pgf-go-pages.lua`.
- Sensei's Library diagrams (`$$` lines, also between `[go]` and `[/go]` of
  L19): a file with them and no SGF nodes is read as a collection, one game
  per diagram, by every SGF command. The title is the name of the game and
  of its figure; the numbers are moves (`m` and missing numbers keep the
  numbering); marks, letters, `AR` and `LN` go on the last move; the edges
  place the diagram on the board, and what is drawn is its view; `_` is
  `goban/blank`. New warnings `sensei-line` and `sensei-size`.
- Syntaxes of the files: `sgf syntax = auto | sgf | sensei`, and `syntax` in
  `\pgfgodefinesgf`. `auto` (the default) reads Sensei's Library diagrams if
  the file has no SGF nodes and has `$$` lines, and SGF otherwise. Every
  syntax is read as an SGF game. New warning `sgf-syntax`.
- The environment `pgfgosgf[options]{name}`: a file written in the document,
  in any syntax, which every SGF command reads as the file `name`. Its options
  are those of `\pgfgodefinesgf`.
- `goban/blank = {coordinates}`: intersections that are not part of the
  board, without lines or star points. A line joins only two neighbouring
  intersections of the board, so next to a blank point it ends as at the
  edge. With `grid/image`, the image is cut to the cells of the board. The
  SGF commands, `sgf size` and `sgf view` take them from the `_` of a
  Sensei's Library diagram.
- `goban/grid/edge = {width, color, opacity}`: the four outer lines of the
  grid, thicker or in another color than the rest; what is not given is as in
  the grid.
- `layout/align captions` (initially `false`): with `valign = top`, the
  captions, notes and comments of a row of the grid start on the same line,
  below the tallest board, and the boards stay at the top.
- `notes/font`: the font of `\pgfgomovenotes` (without it, that of the text;
  in `\sgfdiagrams` and `\sgfproblem`, that of the caption).
- `\pgfgostone[options]`: a single stone in the text, without a board, with
  the style of that moment and, on top, `view/profile`, `view/raise` and the
  `goban` options of `view` (such as `scale`). It takes the options of
  `\stone` (`b`, `w`, `n`, `prisoner`, `mark`, the style of the stone) and
  `number = N`, which draws it with the number and the style of a move of its
  color. It changes nothing of what the last `goban` keeps.
- `\pgfgoview` with several parts separated by commas
  (`\pgfgoview{name}{F15, G15, C3:E5}`): one view per part, joined with
  `view/separator` (initially a comma and a space) and `view/last` (before
  the last one; initially `and` between spaces, translated as the rest of the
  texts: new text `and` of `\pgfgotext`).

### Behaviour changes

- In `\pgfgoview`, a comma separates parts: `{A1, C3}` is two views, not the
  rectangle between them (a rectangle is written `A1:C3`).

- The sizes of the board no longer depend on the font: `grid/sep` is
  initially `12.5pt` (was `1.25em`), `background/sep` `8.25pt` (was
  `0.825em`), `label/font size` `10pt` (was the current font) and the
  automatic sizes of the numbers of `\moves` and of the text of the marks
  `10pt`, `6.5pt` and `4.5pt` (were `1em`, `0.65em` and `0.45em`). With
  `10pt` text nothing changes; with a bigger or smaller font, or with a
  profile set inside `\small` or `\Large`, the grid grew or shrank and the
  stones did not.
- `layout/align` is now `layout/halign` (`align` is removed).
- Views (`\pgfgoview`) draw the background without border, even if the
  original goban or its profile has one: `view` now brings
  `background = {line = false}` besides `scale = 0.8`.
  `\pgfgoset{view = {background = {line = true}}}` brings the border back.
- Spanish texts name the colors in the singular ("Negro", "Blanco", "Juega
  Negro", "Bueno para Blanco") and the results say "Gana Negro" and "Gana Ana
  por abandono": "Ganan" did not agree with a name. Portuguese results say
  "Vitória de Ana por desistência" ("vencem" did not agree either).

### Fixed

- The definition of `draft` in the catalog of the manuals had no closing
  brace.
- One character of `mark/sequence` was smaller (`0.7em`) than one of
  `mark/custom` (`1em`); both are `10pt` now.
- `game = 1:100` in `\sgfproblem` with a file of fewer games drew the first
  game again for each missing one, with a warning each time; now the missing
  games are left out, with one warning (`sgf-games`).

- `\sgfdiagrams` drew nothing for a game without moves; now it draws one
  diagram of its position, with the name of its figure and no range.
- The range in the caption of `\sgfdiagrams` gave the positions of the moves
  in the file; now it gives their numbers, which follow `MN`.
- A named `goban` in `\sgfdiagrams` or `\sgfanimation` (`goban = {name =
  x}`) kept only the stones of its own diagram (from the second one on): the
  position continued from a copy of the previous board. Now a named board
  plays the whole game.
- The mark `dim` left its opacity (0.6) to the filled marks drawn after it,
  and `t-circle` and `t-square` on a translucent grid left its opacity to the
  marks after them; now each one keeps its opacity to itself.
- A shape key of the marks after `t-circle`, `t-square`, `dim` or `hatched
  lines` (`\marks[t-circle, circle]`) kept part of the previous shape: no
  shadow, or the shadow of `hatched lines`.
- A stone, a mark or a line set the line width of the drawing around it to
  0.4pt: in a `goban`, `\begin{scope}[line width = 3pt]` drew with 0.4pt
  after `\stones`. Now the width stays as it was.

### Performance

- Loading the package takes about a third of the time it took (about 2
  seconds less with LuaLaTeX and with pdfLaTeX): saving the initial style
  of the profiles compiled a regular expression for each variable. A short
  document now compiles in about half the time.
- Smaller PDF files, with the same output: the marks `t-circle` and
  `t-square` fill and stroke one path (before, the path went twice); a
  partial board draws only the lines of the grid that can be seen.
- In PDF output each look of a stone is drawn once and every stone with that
  look refers to it (a Form XObject): a full game is about 30% smaller, the
  manual about 8%. Stones with an image or a pattern, and DVI output, are
  drawn as before. Each stone also goes into its layer in one piece, without
  a graphics state of its own, and the colors of the stone (and the
  opacities, if it is opaque) go inside the Form.
- Long games in `\sgf` and `\sgfdiagrams`, animations with many frames, and
  coordinates with pdfLaTeX (most items without regular expressions) are a
  little faster.

### Documentation

- `goban/scale` said that it also changes the width of the lines; it changes
  only the sizes (for the widths, `scale line width`).
- New examples in `doc/examples`: problems written in the syntax of Sensei's
  Library in `pgfgosgf`, with `align captions` (`example-35`), shapes placed
  with `shift` (`example-36`), a joseki in the four corners with `origin` and
  `transpose` (`example-37`), and boards with `blank`, `grid/edge`,
  `letter case` and columns of two letters (`example-38`).
- `example-6` shows every profile, also `simple` and `draft`; `example-21`
  links the problem and its solutions (`links`) and scales the lines of the
  big board (`scale line width`); `example-23` uses `\pgfgostone` and a view
  of several parts; the profile of `example-24` sets `goban/arrow`.

## 0.2026.10.23 — 2026/10/23

### New

- The TikZ coordinate system `go`: inside a `goban`, `(go cs:C3)` is the
  intersection C3, for `\draw`, `\node` and the other commands of TikZ
  (`\draw (go cs:B2) rectangle (go cs:D6);`). It can be outside the board
  (`C0`); a coordinate that is not recognized is the origin, with the
  warning `go-coordinate`.
- `view/arrows` and `view/lines` (initially `true`): `\pgfgoview[arrows = false]`
  does not draw the arrows (`\arrow`, `AR`), and `lines = false` the lines
  (`\line`, `LN`).
- `variation` (in `\sgf`, `\sgfcomment`, `\sgfinfo`, `\sgfanimation` and
  `\sgfdiagrams`) can also be the moves of the line from the first one, with
  commas or spaces: `variation = {R16, P17, Q15}`; at each branch, the
  variation that plays the next move is taken, and `pass` is a pass. Also in
  the list of `sgf diagrams/variations`, in braces: `variations = {{R16 P17}}`.
  Useful for files with many branches, such as a joseki dictionary.
- `goban/partial = auto`: the board shows only the part that is used by the
  stones, moves, marks, arrows, lines and territory drawn on it, with
  `goban/partial margin` (initially 1) more lines; a side two lines or less
  from the edge reaches the edge, and an empty board is whole. The board is
  drawn when the `goban` ends, under what is on it. `\sgfdiagrams` and
  `\sgfanimation` have `partial = auto` too (initially `false`): every
  diagram or frame shows the same part, the one that the lines that are
  drawn use (the one of `variation` and those of `variations`; also in the
  diagrams of the variations), unless the file has a view (`VW`).
- `sgf diagrams/variations` also works with `variation`: the variations are
  the lines that leave that line (the main line too), and `depth` counts from
  it. `sgf diagrams/variations/from` (initially 1): `commented` and `all`
  draw only the variations born at that move or later. For example, the
  answers to a position of a joseki dictionary:
  `\sgfdiagrams[variation = {R16, P17}, variations = {commented, from = 3}]{josekis}`.
- `sgf diagrams/marks` (initially `true`): like `sgf/marks`, in every
  diagram; `marks = false` draws no marks, arrows or lines of the file.
- The part of a SGF tree that `\sgfproblem` shows also counts its arrows and
  lines (`AR`, `LN`).

- `layout/width = natural`: the columns of the grid are as wide as the widest
  diagram (with its caption, cut as without grid), so `column sep` is the
  real space between boards of the same width; the grid is centered and the
  diagrams are drawn at the end (or at the end of each `per page` or
  `per frame` group). `fit` does nothing with it (warning `layout-fit-natural`).
- `\pgfgoview` can come before the `goban` it shows, as `\ref`: the
  `goban` goes to the `.aux` and the view uses it in the next compilation
  (the first time it is `??`, with a warning; if the `goban` changes, a
  warning asks to compile again).
- `goban/export = <file>` writes a named `goban` to a file (`.pgfgo` if it
  has no extension), and `\pgfgoimport[name = <name>]{<file>}` brings it to
  another document, for `\pgfgoview` and `resume`, with its stones, numbers,
  marks, territory and style.

- Numbers in kanji: `format = kanji` in `move/label` and `mark/label` (and
  `mark/sequence = {format = kanji}`) writes 一, 二, ..., 十, 十一, ..., 百, ...
  (〇 for 0), as the kanji of `goban/label/columns = kanji`. They need a
  font family that has them (`label/font`). A kanji counts as two figures
  when the size of the number is chosen.
- Several files in a mark of your own: `\pgfgodefinemark[image = {file = {a.png,
  b.png, c.png}}]{name}` draws each point with one of them, chosen at random
  as in `stone/image/file` (a point always gets the same file).
- Lines in any direction and stairs in the coordinates: `A1 -- E6` puts
  one stone per row (or per column) on the stone nearest to the straight line
  between the two ends (when the ends are in a row or a column it is the
  straight line, as before); `A1 -|- E6` and `A1 |-| E6` fill each step with
  the corner of `-|` or `|-`, so the stones make a connected staircase. When
  the line passes exactly between two points, the stone goes to the side of
  the nearest end (in the exact middle, to the smaller column or row): the
  line does not depend on the order of its ends. The points come in the order
  of the path, and the operators chain with the others. Both kernels.
- Rectangles as `A1:C3`, the same writing as `partial`.
- Ranges and rectangles chain with the operators: `A2 -| B5:7` is
  `A2 -| B5` and then `B5:7`, `B7 -| A:B3` is `B7 -| A3 -- B3`, and
  `A1:C3 r A6` goes on from C3. Each operator goes from the last point of
  what comes before to the first point of what comes after.
- `\marks[sequence]` and `\moves` warn (`unordered-coordinate`) when the
  coordinates have no fixed order: rectangles (`A1:C3`, `A:C 1:3`, `r`),
  whole columns and rows, and `*`. New kernel function `\pgfgo_kernel_moves:n`
  and boolean `\l_pgfgo_kernel_points_ordered_bool`.
- Names for SGF files: `\pgfgodefinesgf[game = 2, charset = GBK]{lee}{games/lee.sgf}`
  and then `lee` goes wherever a file goes (`\sgf`, `\sgfinfo`,
  `\sgfcomment`, `\sgfdiagrams`, `\sgfproblem`, `\sgfanimation`, `sgf size`
  and `sgf view`). The path, the game and the charset are written once; the
  options of each command win over those of the name. A name that is not
  defined is a file, as before. New kernel function
  `\pgfgo_kernel_sgf_define:nn`.
- Two profiles drawn with images: `shell` (a wooden board, slate and shell
  stones, five white stones with their own stripes, turned a little at
  random, and a soft shadow) and `yunzi` (the same board with matte stones).
  As every profile, they also define the players `shell-black`, ...: with
  `players profile = shell` the stones go on any board. The images come with
  the package, next to `pgf-go.sty` (`pgfgo-board.jpg`, `pgfgo-shell-black.png`,
  ...), and can be used by name in your own profiles.
- An image that is not found (in the folder of the document or in the TeX
  path) is looked for among the images of the package, next to `pgf-go.sty`.
- Shadows of your own: `stone/shadow/image = {file, width, rotate, false}`
  draws an image (a soft shadow, for example) under the stone instead of its
  silhouette, moved by `angle` and `offset` like the silhouette.
  `stone/shadow/scale` (initially 1) makes the shadow bigger or smaller than
  the stone, also the image. `silhouette` in `stone/shadow/image` and in
  `stone/shine/image` uses only the shape of the image, in the colour of the
  shadow or of the shine (pdfLaTeX or LuaLaTeX).
- Several files in the tiles of the board: `goban/background/fill/image/file`
  and `goban/grid/image/file` take a list, like `stone/image/file`; with
  `fit = tile` each tile uses one of them, always the same in each place of
  the mesh (also with `partial`), so that the board does not look repeated.
  `stretch` and `cover` use the first file.
- `comments/position = after` writes the comments of `\sgfdiagrams` and
  `\sgfproblem` after the diagrams, full width, each group with the caption
  of its diagram; `comments/height` (initially `none`) sends there what does
  not fit below or beside a diagram.
- `\sgfproblem[verdict]`: the caption of each solution says whether it is
  correct or wrong (new texts `correct` and `wrong`), from the `GB`/`GW`,
  `TE`/`BM` or "RIGHT" of the line.
- Sheets of problems: `\sgfproblem[game = 1:20]` (numbers and ranges, as in the
  coordinates: `{1:4, 9}`) draws the statements of several problems of a
  collection, numbered ("Problem 7", new text `problem` in every language, or
  `title`), and then the solutions. `to play = auto | black | white | none`
  says who plays when the file does not.
- Variations as diagrams: `\sgfdiagrams[variations]` draws the variations of
  the game too, each one after the diagram where its first move is (diagram
  3a, 3b...), numbered from 1, with its comments; the caption says which
  move it replaces (`variation title`, `\pgfgovariationmove`, new text
  `variation at` in every language). `variations = commented` (the default
  value), `all`, `none`, `depth = n` (initially 1) and paths of variations
  (`2`, `2.3.1`), which can be added: `variations = {commented, 5}`.
- `\sgfinfo[move = n]` writes a property of a move (`BL` and `WL`, the time
  left on KGS and OGS), and `variation` its line.
- A warning when the font of an SGF text (comments, `\sgfinfo`) has no glyph
  for its Chinese, Japanese or Korean characters, once per font: LaTeX only
  writes them in the `.log`. Not with luatexja, ctex, luatexko or xeCJK,
  which write them with another font.
- Options for the comments of `\sgfdiagrams` and `\sgfproblem`:
  `comments/font` (initially the font of the caption), `comments/align`
  (`left`, `right`, `center` or `justify`) and, in `\sgfdiagrams`,
  `comments/root`, the comment of the root before the others. As in
  `\sgfanimation`, these options do not turn the comments on:
  `comments = {true, align = justify}`.
- `comments/number` (what goes before each comment, `#1` is the number;
  initially in bold with a colon) and `comments/separator` (between the
  comments, initially `\par`) in `\sgfdiagrams` and `\sgfproblem`.
- Comments beside the diagrams: `comments/position = right` or `left` puts
  the comments of `\sgfdiagrams` and `\sgfproblem` beside the board, from
  its top, as in books of commented games. `comments/width` (initially
  `auto`: the rest of the line, or of the cell of the grid; with `fit`,
  half of it) and `comments/sep` (initially `1em`).
- Comments without chat: `chat = false` in `\sgfcomment`, `\sgfdiagrams`,
  `\sgfproblem` and `\sgfanimation` removes the chat of the servers from
  the comments: on OGS, everything after a line "-- chat --"; on KGS, the
  lines "name [rank]: ..." and, if there is one, also the lines
  "name: ..." of the same comment.
- Passes in the notes: with `goban/notes`, a numbered pass of an SGF file
  is noted as "N: pass" (new text `pass` in every language, and key
  `notes/pass`), in order with the "N at M" notes. The passes that end the
  game are not noted. `\sgfdiagrams` and
  `\sgfproblem` write them under each diagram, so a missing number is
  no longer silent.
- Views in the text: `goban/name = <name>` stores everything that `goban`
  draws, and `\pgfgoview[<options>]{<name>}{<part>}` draws a point
  (`D4`) or a rectangle (`B2:E5`) of that board as it was at the end,
  with the captures done, in the middle of a paragraph. Everything that
  board drew there is shown (marks, move numbers, territory), with its
  background and coordinates; `view/marks`, `view/numbers` and
  `view/territory` `= false` remove them, `view/raise` sets the height, and
  any `goban` option (`background = false`, `label = false`, `grid = false`,
  `scale`, ...) can be given too, or for all views with
  `\pgfgoset{view = {...}}`. What was drawn with `forget` is only shown
  with `view/forgotten`. A view keeps the style the board had when it was
  drawn (profile, `\pgfgoset` and its options), even if it changes later;
  `\pgfgoset{view = {...}}` and the options of the view (`players`, `stone`,
  `mark`, ...) go on top.
- Profiles for views: `view/profile = <name>` goes after the style of the
  named board and before the other options of the view; initially `false`,
  the style of the original board. New profile `simple` (no frame, thin
  lines), in the catalog.
- Shines of your own: `stone/shine` takes
  `image = {file, width, rotate, false}`, an image with transparency centered
  on the stone instead of the drawn shine. The shine is drawn on top of any
  stone, also of a stone image, and does not turn with `stone/image/rotate`:
  stones with their grain turned at random keep the light on the same side.
  The drawn shine now grows with the radius and the scale of the stone.
- One rule for every key that turns something on or off: the key alone (or
  with `true`) turns it on, `false` turns it off, and options alone do not
  turn it on. New `true`/`false` keys where they were missing:
  `goban/label = true` (letters below and numbers on the left),
  `goban/grid/line = false` (no lines, but the star points stay) and
  `players/<player>/territory/fill = false`.
- The options of a `goban` accept those of `\pgfgoset` (`stone`, `move`,
  `mark`, `players`, `notes`, ...), only for that board:
  `\begin{goban}[9, stone = {radius = 4pt}]`.
- `\pgfgoset{mark = {...}}` also sets the style of the marks of the three
  players (`line`, `fill`, `label`, `sequence`, `scale`).
- `\moves` accepts the options of the style of the stone (`fill`, `line`,
  `radius`, `shine`, `image`, ...) and `mark`, like `\stones`.
- `mark/scale` changes the size of the marks (shapes, images and text).
- Opacity: `mark/line/opacity`, `mark/fill/opacity`, `move/label/opacity`,
  `stone/image/opacity` and `goban/hoshi/opacity`.
- `stone/shadow/color`, `move/label/font` (initially `\bfseries`),
  `mark/label/font size`, `goban/label/color`, and
  `goban/hoshi/image/width` and `rotate` (like
  `stone/image/rotate`).
- `\arrow` and `\line`: `dash` (`solid`, `dashed`, `dotted`), `shorten`
  (both ends), `bend = <angle>` (an arc instead of a straight line, like
  `bend left` in TikZ; a negative angle bends it to the right) and, for
  arrows, `tips = both`.
- `goban/grid/image/rotate` and `goban/background/fill/image/rotate`, like
  `stone/image/rotate` but in quarter turns, so that the turned image still
  fills its place: with `random` or a range, each tile has its own turn.
- Nested keys for the options of the SGF commands, like `halo`:
  `\sgfanimation[comments = {true, height = 6em, font = \itshape}]`,
  `\sgfdiagrams[result = {title = .., format = raw}, caption = {font = ..}]`
  and `\sgfproblem[caption = {font = ..}]`.
- `\sgf` and `\sgfanimation` number the moves like `\sgfdiagrams`: `step`
  (a number or a list) gives the size of the stretches, and
  `restart = {true, false, auto, from = <n>}` restarts the numbering in each
  stretch (`auto`, the initial value, follows `PM`).
- `\sgfdiagrams`: `step` takes a list, and the last number is repeated
  (`step = {5, 10, 3}`: diagrams of 5, 10, 3, 3, 3... moves), and
  `restart = {from = <n>}` numbers each diagram from `<n>` (from the second
  one on: with `step = 99` and `restart = {from = 0}`, move 100 is shown as
  0). `restart` alone is `from = 1`. The first diagram now always keeps the
  numbers of the game, and `restart` works with figures (`FG`).
- `\pgfgodefineprofile[from = <profile>]{<name>}{goban = .., all = ..,
  neutral = .., black = .., white = ..}` defines a whole profile at once.
- `\pgfgodefinemark[image = {file = <file>, width = <dimension>}]{<name>}`.
- `\sgf` and `\sgfdiagrams`: `last mark` marks the last move shown.
  `\sgfdiagrams`: `numbers = false`. `to = last` in `\sgf`, `\sgfanimation`
  and `\sgfdiagrams` (a negative number means the same).
- `\pgfgoset{sgf comment = {...}}` and `\pgfgoset{sgf info = {...}}`.
- Layout of the diagrams: `layout = {columns = <n>}` puts the diagrams of
  `\sgfdiagrams` and `\sgfproblem` in a grid of columns of the same width
  (one row per line, so the page can break between rows; the boards of a row
  are aligned at the top). `fit` scales the boards to fill their column,
  `width`, `column sep`, `row sep` and `align` set the rest. It can be set for
  the whole document (`\pgfgoset{layout = {...}}`), for each command
  (`\pgfgoset{sgf diagrams = {layout = {...}}}`) or in each call. The
  environment `pgfgolayout` puts in one grid the `goban`s, `\sgfdiagrams` and
  `\sgfproblem` inside it. Without `columns` (`columns = auto`), the diagrams
  stay in the paragraph as before.
- `layout/per page = <n>` starts a new page every `<n>` diagrams, and
  `layout/per frame = <n>` (alone, 1) puts every `<n>` diagrams on the next
  slide of a `beamer` frame, with `\only<+>`. Both work with
  `\sgfdiagrams`, `\sgfproblem` and `pgfgolayout`, in the grid or in the
  paragraph.
- `\sgfdiagrams`: `from` draws the diagrams from a move on, with the same
  numbers as the whole series.
- `\sgfproblem`: `statement = alone` puts the statement alone in its row,
  above the variations.
- Languages: the texts the package writes (captions of `\sgfdiagrams` and
  `\sgfproblem`, the result, the SGF annotations and the word of the
  "N at M" notes) are translated into English, Spanish, French, German,
  Portuguese, Italian, Japanese, Chinese and Korean. By default they follow
  the language of babel or polyglossia, also when it changes within the
  document; `\pgfgoset{lang = <code or babel name>}` and the package option
  `lang` choose one. Every text can still be set with its own key, in any
  language. `\pgfgotext{<text>}` writes one of the texts,
  `\pgfgodefinelanguage{<language>}{<texts>}` adds or changes a language and
  `\pgfgolanguagealias{<name>}{<language>}` gives it another name.
- `\sgfdiagrams` writes the result in words ("Black wins by resignation"),
  in the language of the document; `result format = raw` keeps it as it is in
  the file ("B+R"). `\pgfgowinner` and `\pgfgopoints` are the winner and the
  difference in the texts of the result.
- Images (PNG, JPG or PDF): `stone/image` (`file`, `width`, `false`) draws
  the stones with an image; with several files, each point always uses the
  same one. `shadow` has the shape of the image (pdfLaTeX or LuaLaTeX).
  `goban/background/fill/image` (`file`, `fit = stretch | cover | tile`,
  `width`, `from`, `tiles`, `false`) puts an image on the background of the
  board, placed according to the whole board (tiles start from the corner,
  side or center given by `from`, or fill a mesh of `tiles`); marks on empty
  points show the image under them. `goban/grid/image` (`file`,
  `fit = stretch | tile`, `tiles`, `false`) replaces the lines of the grid,
  stretched, once on each square or on a mesh of `tiles`
  (`<columns>x<rows>`), and `goban/hoshi/image` (`file`, `false`) the star
  points. Each file is stored once in the PDF.
- `\pgfgodefinemark{<name>}{<pgf code>}` and
  `\pgfgodefinemark{<name>}[image = <file>, width = <dimension>]` define new
  marks, used like the others (`\marks`, `mark`, `territory/mark`).
- `\sgfproblem`: draws a problem (tsumego) from an SGF file: the statement
  (initial position, marks, who plays, comment) and one diagram for each line
  of the tree, with its notes, comments and annotations. Without `VW`, the
  board is cropped to the part the problem uses (`crop`, `margin`). Options for
  the whole document with `\pgfgoset{sgf problem = {...}}`.
- SGF print mode (`PM`): `sgf/restart = auto` (the new initial value) restarts
  the numbering every 100 moves with `PM[2]`, and `sgf/numbers` (`true`,
  `false` or `auto`, the initial value) draws no numbers with `PM[0]`.
  `\sgfdiagrams` and `\sgfproblem` always number the moves.
- The view (`VW`) can change during the game. `goban/sgf view move` chooses
  the move whose view `sgf view` uses. Each diagram of `\sgfdiagrams` covers
  the views of its moves, and `\sgfanimation` uses one board that covers the
  views of all its frames.
- `\sgfdiagrams` writes the result (`RE`) below the last diagram and, if the
  file marks the territory (`TB`, `TW`), the score of each player with the
  komi of the file (`KM`). Keys `result`, `result title`, `black name` and
  `white name`.
- Coordinate styles on the border: `goban/label/columns` and `goban/label/rows`
  (`letters`, `numbers` or `kanji`), `columns direction` (`left to right`,
  `right to left`), `rows direction` (`bottom to top`, `top to bottom`), and
  `style` (`western`, `japanese`, `chinese`). Kanji need a font that has them.
- SGF files in GBK (and GB2312), Big5, Shift_JIS, EUC-JP and EUC-KR are
  converted to UTF-8, following `CA` or the new key `sgf charset` (for files
  that do not say their charset). The tables are in `pgf-go-charsets.lua`,
  generated by `tools/make_charsets.py` and loaded only when needed.
- `\territory[draw = region]` draws the territory of each color as a single
  polygon: every square of the grid with a corner in the territory is painted,
  and areas that touch at a corner are kept apart. It works with polygons,
  `auto` and the `TB`/`TW` of `\sgf`, with both kernels. The outline
  (`players/<player>/territory/line`) and its vertices (`.../vertices`) can be
  drawn on top, and `\pgfgoregion{<player>}{<property>}` (expandable) gives
  the number of polygons, holes and vertices, the area, the perimeter and the
  vertices of each polygon as coordinates.
- Compute kernel: `\pgfgo_kernel_sgf_view:nn` and `\pgfgo_kernel_sgf_tree:n`;
  `\pgfgo_kernel_sgf_read:nn` also leaves the print mode and the komi;
  `\pgfgo_kernel_region:n` (both kernels) traces the outlines of a territory.
- Compute kernel: the memory has one list per name
  (`\pgfgo_kernel_remember_push:nn`, `clear:n`, `replay:n`, and
  `\pgfgo_kernel_remember_append:nn` to copy one into another); the list of
  `remember` and `resume` is the one with the empty name.

### Fixed

- A `goban` with some 2600 marks or more (for example `\territory{auto}` on a
  board of 52) made LuaLaTeX crash with no message when it shipped out the
  page: PGF puts each `\pgfonlayer` around what the layer already had, and
  the boxes were too deeply nested. In a `goban`, each one now goes in its own
  box, next to the others; the drawing is the same.
- `\pgfgoscore{n}` was always 0; it is `\pgfgoscore{neutral}`, the number of
  neutral points, as `n` in `\territory` and `\pgfgoregion`.
- With `resume`, a `\territory` came back without its options (for example
  `\territory[w, mark = cross]`): it is drawn with them.

- Installed in the TeX tree (`\usepackage{pgf-go}`), LuaLaTeX did not load
  the Lua kernel: `pgf-go.lua` was looked for in the folder of the document.
  Now it is found with `kpse` (first as a TeX file, the search that found
  `pgf-go.sty`). The images of the profiles `shell` and `yunzi` are found in
  the TeX path with both engines.
- A mark on a background image had a thin ring of the fill colour of the
  background around it (the soft edge of the colour under the image). The
  colour now goes in a circle 1pt smaller.
- With `fit = tile`, each mark on a background image drew again every tile of
  the visible part (361 marks on `tiles = 19`: 3.5 MB without compression);
  now only the tiles under the mark (190 KB). Also under `dim`.
- The points of a range go from its first end to the second:
  `\marks[sequence]{N10:7}` numbered N7 to N10, and `E:A2`, `C5 -- C1` and
  the vertical part of `A9 -| C7` went up or right whatever the order of the
  ends. Brackets (`A[1:3]`, `[A, C]5`) also keep their place in the list
  (they went to the end). Both kernels.
- A row written with a zero (`C03`) is the same point as `C3`.
- A mark with `sequence` outside the visible part of the board (`partial`, or
  a `\pgfgoview`) did not advance the sequence, so the view `{A10}` of
  `\marks[sequence = {format = Alph}]{N10, ..., A10}` showed `A` instead of
  `K`. Hidden marks now advance it too: the labels are those of the whole
  board.
- `resume` started the board with the default size (9) instead of the size
  of the named board, so its stones outside a 9x9 board were lost. Now it
  takes the size of that board, unless the `goban` gives its own (`size`, a
  number, `sgf size` or `sgf view`).
- The profile `baduktv` did not compile (its board image had no extension
  and was not found). An image without extension is now also looked for
  among the images of the package with the extensions `.pdf`, `.png`, `.jpg`
  and `.jpeg`.
- `\pgfgodefinemark[image = {width = ...}]` with `em`: the width was measured
  inside the picture, where the font is `\nullfont` and `1em` is 0, so the
  image did not show. Now it is measured when the mark is defined, with the
  font of the text.
- `\sgfdiagrams` and `\sgfproblem` with `layout/columns = auto`: a caption
  wider than its board (as "Problem 3: White to play" under a small corner)
  made the whole diagram that wide, and fewer diagrams fitted in a line. Now
  the caption is broken into lines at the width of the board, as in the grid,
  but never narrower than its longest word nor than the new key
  `caption/min width` (initially `8em`, in `\sgfdiagrams` and `\sgfproblem`).
- Smaller PDF files: every stone was drawn in its own transparency group,
  one more object in the PDF for each stone (a sheet of 900 problems weighed
  9 MB). Now only a translucent stone (a prisoner, `opacity` below 1) uses
  one; the others look the same and the sheet is about 15 times smaller.
- With `layout = {fit}`, all the boards of `\sgfdiagrams` and `\sgfproblem`
  take the scale that fills the column with the first one; a wider board
  (another problem of a sheet, for example) came out of its column. Now
  only that board is made smaller, to fill the column.
- With `restart`, the comments of `\sgfdiagrams` had the number of the
  move in the game, not the one shown on the board.
- `annotations` of `\sgfdiagrams`, `\sgfanimation`, `\sgfproblem` and
  `\sgfcomment` changed all of them at once; now each command has its own.
- The expl3 kernel expands the coordinates before reading them, as the Lua
  kernel already did.
- The halo of `\arrow` (and of `AR` in `\sgf`) now surrounds the tip evenly.
  Before, the halo was the same arrow with a thicker line, and its tip grew
  forward along the line.
- SGF file names can have the special characters of TeX written with a
  backslash (`\sgf{a\&b.sgf}`; also `\#`, `\%`, `\$`, `\{` and `\}`).
- `\sgfanimation` works in documents whose name has spaces, commas or `=`.
- A background of tiles (`background/fill/image = {fit = tile}`) no longer
  makes the board take more room: the tiles that are cut off on the edges
  left a blank margin above and to the right.
- `players/<player>/mark/sequence/from` was ignored: `\marks` started the
  sequence at the `from` of the neutral player. Now it starts at the `from`
  of the player of the marks.
- SGF files in UTF-16 (with a byte order mark) and files whose root node has
  no `;` (`(SZ[19]...`, written by some old programs) gave an empty board
  without a warning; now they are read.
- A file that is not UTF-8 and has no `CA` is still read as Latin-1, but if
  it looks like GBK, Big5, Shift_JIS or EUC-KR there is a warning that says
  to set `sgf charset`; before, the comments and names came out garbled
  without a warning.
- The `sgf-charset` and `\moves` messages lost some spaces.

### Behaviour changes

- The territory is drawn when the `goban` ends. Each point is drawn with the
  last `\territory` that marked it (with its player and options), so
  `\territory[n]{A1}` after `\territory{auto}` makes A1 neutral (in the
  drawing too, and the eyes of a seki can be made neutral that way), and a
  point with a living stone at the end is neither drawn nor counted. Before,
  each `\territory` was drawn at once: a stone put later kept its mark and
  was counted, and two `\territory` on a point drew both. The owner of each
  point and `\pgfgoregion` are still known at once, inside the `goban`.
  The records of named gobans (`.aux`, `export`) are version 2: older ones
  are not used (warning `store-version`).
- `\pgfgoscore` and `\pgfgoprisoners` with an unknown player (for example
  `\pgfgoscore{Black}`) are an error (`unknown-score-player`,
  `unknown-prisoners-player`); they still write 0.
- `view/marks = false` hides only the marks; the arrows and the lines have
  their own keys (`view/arrows`, `view/lines`). `resume` with `marks` still
  brings the three.

- `sgf problem/crop` and `sgf problem/margin` are removed. `\sgfproblem`
  has `partial = auto` (initially) or `false` instead, and the lines around
  the problem are `goban = {partial margin = <n>}`.

- `\moves` numbers its moves: the starred versions `\moves*` and `\move*`
  are removed, and so is `\move` (`\moves{C3}` plays one move). The new key
  `move/numbers` (initially `true`) says whether the moves get their number:
  `\moves[numbers = false]{...}` is the old `\moves{...}`, and
  `\pgfgoset{move = {numbers = false}}` (or `move = {numbers = false}` in
  a `goban`) is for all the moves that follow.
- Coordinates: the operator `R` is removed (`A1 R C3` is now `A1:C3`), and so
  are `:--:`, `:-|:` and `:|-:` (now `--`, `-|-` and `|-|`). `A1 -- C3`
  between two points that are not in a row or a column draws the line
  instead of the warning `diagonal-line`, which is removed.
- `\moves` takes all the coordinates of `\stones` (rectangles, `*`, brackets)
  and plays each one in its order; the ones with no fixed order give a
  warning, not an error. Groups that subtract (`;`) give the error
  `moves-subtract` (the error `moves-coordinate` is removed).
- `\pgfgoview` with a name that does not exist gives a warning and `??`
  (it was an error), because the `goban` may come later.
- `goban/use i` is now `false` by default, as usual in go: the columns go
  from `H` to `J`, and `I` in a coordinate is read as `J`. `use i` (or
  `use i = true`) brings the `I` back.
- `stone/shadow/offset` is initially 1pt (it was 0pt, so `shadow` alone
  drew the shadow under the stone, where it could not be seen).
- With several files in `stone/image/file`, the file of each point is chosen
  in a new way, the same as the tiles of the board: with two files the old
  choice made a regular pattern (three points of four used the second one).
  Each point still shows always the same file, but not the same as before.
- **A move number is never covered.** In `\sgf`, `\sgfdiagrams` and
  `\sgfanimation`, a label of the file (`LB`) on a numbered stone is not
  drawn (the number stays), and `last mark` does not mark a move with a
  number; before, the label replaced the number and the last mark was drawn
  over it. Shapes of the file (`TR`, `SQ`, `CR`, `MA`, `SL`) still replace
  the number.
- **Profiles are keys.** `profile = <name>` (the board `<name>` and the
  players `<name>-neutral`, `<name>-black`, `<name>-white`),
  `goban profile = <name>`, `players profile = <name>` and
  `players/<player>/profile = <player name>` work in `\pgfgoset`, in the
  options of a `goban` and in those of a view. Before applying a profile, the
  board and the players go back to the initial style (that of `default`), so
  a profile no longer inherits what it does not define (a shadow, an image,
  ...); the size, `partial`, `scale`, the coordinates, `hoshi/at`, the
  captures and the notes stay. Removed: `\pgfgouseprofile`,
  `\pgfgousegoban`, `\pgfgouseplayers`, `\pgfgouseneutral`,
  `\pgfgouseblack` and `\pgfgousewhite` (`\pgfgouseprofile{wain}` is now
  `\pgfgoset{profile = wain}`). The profile `default` no longer sets
  `size`, `partial`, `use i`, `scale` or `label = false`: they are initial
  values.
- **One way to remember a board: `name` and `resume = <name>`.** A `goban`
  with `name = <name>` stores everything it draws, and another one starts
  with that board as it was at the end with `resume = <name>` (numbering and
  turn continue). `resume` brings only the stones; ask for the rest with
  `resume = {<name>, numbers, marks, territory}`. With `name` and `resume`
  in the same `goban`, the new name stores what it brought plus its own, and
  the old board does not change (variations); `name = a, resume = a` keeps
  adding to `a`. `resume` with a name that does not exist is an error.
  Removed: `goban/new remember`, `goban/remember`, `goban/forget` and
  `resume` without a name, and the `remember` keys of `stone`, `move`,
  `move/label`, `players/<player>/move/label`, `mark`, `arrow`, `line` and
  `territory` (they only undid `goban/forget`). `forget` stays: what is drawn
  with it is not brought by `resume`, and `move/label/forget` leaves the
  number out even with `numbers`.
- **Keys and commands with new names; the old names were removed.**
  `partial = B2:D4` (or `{B2, D4}`, `{B2 to D4}`) instead of
  `partial = {from = B2 to D4}`; `stone/shine` instead of `drop shine`;
  `stone/shadow` and `goban/background/shadow` instead of `drop shadow`;
  `goban/label/color` instead of `text color`;
  `goban/background/fill/image/anchor` instead of `from`;
  `goban/label/columns direction = right to left` and
  `rows direction = top to bottom` instead of `columns from = right` and
  `rows from = top`;
  `\pgfgocopyplayers` instead of `\pgfgochooseplayers`;
  `\sgf[step = 100, restart]` instead of `\sgf[restart = 100]`, and
  `restart = false` instead of `restart = 0` (also in `\sgfanimation`);
  `\sgfanimation[comments = {true, height = .., font = ..}]` instead of
  `comment height` and `comment font`; `\sgfdiagrams[result = {title = ..,
  format = ..}, caption = {font = ..}]` instead of `result title`,
  `result format` and `caption font` (also `caption` in `\sgfproblem`);
  `\pgfgoset{goban = {use i = false}}` instead of `\pgfgoset{use i = false}`;
  `\pgfgodefinemark[image = {file = ..}]{<name>}` instead of
  `\pgfgodefinemark{<name>}[image = ..]`.
- Removed, because they repeated other keys: `goban/border` (use
  `goban/background`), `goban/add to remember` (use `name` and `resume`),
  `mark/sequence/use` (use `sequence` or `sequence = true`) and the mark
  shapes `tcircle` and `tsquare` (use `t-circle` and `t-square`).
- **`\stones` without `b`, `w` or `n` draws neutral stones**, like `\stone`
  and `\marks`. Before, it drew black stones. Write `\stones[b]{...}` for
  black stones.
- **Options alone no longer turn on `territory/line` and
  `territory/vertices`.** Write `line = {true, color = red}`, or `line`
  alone.
- `mark/fill = false` leaves the filled marks without fill. Before, it filled
  them in gray, and `mark/fill/color` was only used with `true`. Now the fill
  is on by default and its initial color is gray, so the marks look as
  before. The profiles that said `fill = false` no longer say it.
- With an image stone, the shine is drawn on top if it is on (before, image
  stones had no shine).
- Without a player, the style options of `\territory` (`mark`, `fill`, ...)
  now apply to the three players. Before, with `auto` they only changed the
  neutral points.
- `\sgf` and `\sgfanimation` follow `PM` by default: files with `PM[2]`
  restart at 101, and files with `PM[0]` are drawn without numbers by `\sgf`.
  Use `restart = false` or `numbers` to get the old behaviour.
- `\sgfdiagrams` writes the result below the last diagram when the file has
  `RE` or territory. Use `result = false` to leave it out.
- A wrong option in `\marks` (or in `\territory` with `draw = marks`) gives
  one error for the whole command, instead of one error for each point.
- `\moves` reads its list as a sequence, not as a set: the moves are
  played in the order in which they are written, and a repeated intersection
  is played again (a ko can be retaken in one `\moves`). A path goes from
  its first point to the second (`B1 -| D3` is B1, C1, D1, D2, D3), and a
  part of a row or a column goes in the order in which it is written
  (`C:A 4` is C4, B4, A4). Rectangles, `*`, brackets and `;` give an error
  in `\moves`, because they have no clear order.
- `players/<player>/stone/prisoner` is the style of the prisoners of that
  player, and only of them. Before, setting it in `\pgfgoset` turned every
  stone of the player into a prisoner. The style of a prisoner is: fill
  opacity 0.5, then `/pgfgo/prisoner`, then the player's style, then the
  value of `prisoner` in the stone. `\stones[prisoner]` now also uses
  `/pgfgo/prisoner`, like `\prisoners`.
- `players/<player>/mark/custom` was removed: it changed the mark of the
  three players. The shape of a mark (`custom`, `triangle`, ...) is not part
  of the style of a player: it goes in the options of each mark
  (`\marks[w, custom = ?]`) or in `/pgfgo/mark`; in
  `\pgfgoset{players = ...}` it gives an error.
- The package no longer defines the colors `tablero2`, `tablero3` and
  `tablero4`, which no profile used. Define them in the document if needed.

### Documentation

- `\territory{auto}`: what it cannot know (open positions, gaps in a border,
  dead stones that are not prisoners, eyes in seki, neutral stones) and that
  `partial = auto` grows to the territory. When the territory is drawn.
  `\pgfgoscore{neutral}`, `view/arrows`, `view/lines`. New section "Dibujar
  con TikZ" (`go cs`).
- New examples in `doc/examples`: the count of a game with a seki
  (`example-33`, the eyes made neutral with `\territory[n]`) and TikZ on the
  board with `go cs`, and views without arrows and lines (`example-34`).

- New examples in `doc/examples`: a sheet of problems from a collection
  (`example-20`, with problems of the Igo Hatsuyoron), a lesson in `beamer`
  (`example-21`), a game of 1940 in diagrams (`example-22`), views in the
  text and a grid of diagrams (`example-23`), a profile and marks of your
  own (`example-24`) and the variations of a file as diagrams
  (`example-25`).
- The examples and the Spanish manual give their SGF files a name with
  `\pgfgodefinesgf` and use the name; the first tutorial explains why.
- New examples: a sequence in several diagrams with `resume` and a
  variation (`example-26`), the count of a finished game (`example-27`)
  and frameworks as regions (`example-28`).
- New example: a ladder (`example-29`), drawn with lines and stairs.
- The examples have only the code they need: `example-0` and `example-4`
  set a background that their profile replaced, and `example-1` and
  `example-6` place the boards with `pgfgolayout` instead of boxes and
  tables.
- `example-5` and `example-7` drew the same boards as `example-0` and
  `example-1` with another profile; now they show the styles of the
  coordinates and a collection of games (`games.sgf`).
- The images of the profiles are next to the `.sty` files, in `latex/`, and
  those of the manual in `doc/img/`; the manual and the tests no longer have
  their own copies. The folder `img` was removed. All of them start with
  `pgfgo-`: `baduktv-black.png`, `baduktv-white.png` and `baduktv-goban.png`
  are now `pgfgo-baduktv-black.png`, `pgfgo-baduktv-white.png` and
  `pgfgo-baduktv-goban.png` (a document that used them by name has to change
  it), and those of the manual are `pgfgo-cell.png`, `pgfgo-star.pdf` and
  so on. The test image `stone-oval.png` is in `tests/cases/`.
  `wood.jpg` was removed: where it was used, the examples use
  `pgfgo-board.jpg`.
- The Spanish manual explains when an image is kept only once in the PDF
  (engine, size, rotation) and suggests PDF images for elaborate vector
  stones.
- New examples in `doc/examples` (8 to 19): `\sgf`, a commented game,
  animations in the PDF and in `beamer`, a problem, Spanish, Japanese, Chinese
  and Korean texts, captures and ko, territory and score, and arrows and lines.
- Every example in `doc/examples` ends with a page that shows its code.
- More drawn examples in the manuals: the keys whose effect is seen in the
  drawing and had none got one, usually shared by sibling keys (the line
  of an arrow, the label of the moves of a player, the result of
  `\sgfdiagrams`, the layout of the diagrams, ...).
- `variantes.sgf` (Spanish manual) has a standard result, `RE[B+R]`.
- New examples: a page of a joseki dictionary (`example-30`, with its own
  `joseki.sgf`), problems drawn by hand with `partial = auto`
  (`example-31`) and their answers, with views before the boards
  (`example-32`).
- Spanish manual: a new tutorial, a joseki dictionary (`josekis.sgf`:
  `variation` by moves, `variations` with `from`, `partial = auto`), and
  the other tutorials show `partial = auto`, a view before its `goban`,
  `export` and `\pgfgoimport` for slides, and lines and stairs
  (`--`, `-|-`) in the coordinates.

### Tests

- New cases `territory-auto` (the scope and limits of `\territory{auto}`, with
  the expected scores; replacing points, stones after it, `resume` with
  options, unknown players) and `many-marks` (2703 and 2600 marks in one
  `goban`). New cases `views-arrows-lines` and `go-coordinates` (both
  engines).

- New cases `partial-auto` (`goban`, both kernels) and `partial-auto-sgf`
  (with captures, `\sgf`, `\sgfdiagrams`, `\sgfanimation` and a view; fixture
  `joseki.sgf`). `sgf-problem` uses `partial` and `partial margin`.

- New case `installed`: the package loaded as `\usepackage{pgf-go}` from
  the TeX path, with the profiles `shell` and `yunzi`. `run_tests.py` has the
  header `% installed: yes` (the files of `latex/`, with the images of the
  profiles, in one folder, first in `TEXINPUTS`).
- `images`: marks on a background image, with tiles and with `dim`.
- New case `move-numbers` (`numbers` in `\moves`, `\pgfgoset` and `goban`,
  with `resume` and `notes`).
- New case `sequence-order` (the order of ranges, chains with ranges and
  rectangles, brackets, and the warning of `sequence` and `\moves`), with
  both kernels. `tests/kernel-checks.tex` checks the order of every form,
  `\l_pgfgo_kernel_points_ordered_bool` and `\pgfgo_kernel_moves:n`.
- New case `layout-natural` (`layout/width = natural` in `pgfgolayout`,
  `\sgfdiagrams` and `\sgfproblem`, with `align`, `per page` and `fit`).
- `docs/keys` and `--manuals` only look at the Spanish manual for now
  (`MANUALS` in `tests/check_docs.py`).
- New case `real-games`: an extract of Lee Sedol - AlphaGo (many root
  properties, labels on every commented node, variations) and a synthetic
  game of 320 moves with passes and `BL`/`WL`.
- New cases for `\moves` as a sequence (`moves`, and a ko in one `\moves`
  in `captures`), the prisoner style of one player (`stones`), `custom`
  for one player (`marks`) and their errors (`errors`).
- New cases for views in the text (`views`, and `views-captures` with
  captures, SGF and the score); `kernel-checks` tests named memories.
- New cases for the rules of the keys and the new keys (`key-rules`) and for
  the new keys of the SGF commands (`sgf-keys`); `images` draws a shine image
  over stones turned at random.
- New cases for problems, print modes, views during the game, results,
  coordinate styles and charsets.
- The examples can ask for two runs (`% passes: 2`).
- New case `stairs`: lines and stairs, their ties in both orders, the order
  of the points, chains and subtraction (the same with `--kernel expl3`).
- New case `sgf-names`: names for SGF files, their game and charset, and the
  options of a command over them.
- New case for unusual file names (`file-names`); a test can choose its job
  name (`% jobname:`).
- `run_tests.py` compiles files whose name has spaces, and a PDF that
  pdftoppm cannot read fails that document instead of stopping the run.

## 0.2026.10.13 — 2026/10/13

### New

- SGF collections (`game`), the view (`VW`, `goban/sgf view`), figures (`FG`) in
  `\sgfdiagrams`, variations as letters (`sgf/variations`, `ST`), `PL`, and
  Latin-1 files (`CA`).
- SGF annotations (`N`, `TE`, `BM`, `DO`, `IT`, `GB`, `GW`, `DM`, `UC`) are written
  with the comments. New `\sgfcomment` and `sgf diagrams/comments`; the
  texts are set with `\pgfgoset{sgf annotations = {...}}`.
- Arrows and lines: `\arrow` and `\line` inside `goban`, and the `dim` mark.
  `\sgf` also draws `AR`, `LN`, `SL` and `DD`.
- Star points: `goban/hoshi` (on by default; `radius`, `color`, `at`).
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
  `\pgfgoscore`. `\sgf` draws the territory of the file (`TB`, `TW`).

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

- `goban/use i` is now `false` by default, as usual in go: the columns go
  from `H` to `J`, and `I` in a coordinate is read as `J`. `use i` (or
  `use i = true`) brings the `I` back.
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
