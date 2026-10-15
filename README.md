# pgf-go— for drawing go games.

Release 0.2026.10.13 2026/10/13

## Description

pgf-go is a package for diagramming and commenting on Go games. It is currently not a definitive version, but the syntax will remain consistent.

## Licence

This package may be modified and distributed under the terms and
conditions of the [LaTeX Project Public License](https://www.latex-project.org/lppl/), version 1.3 or greater.


## Requirements

The package compiles with UTF-8, LaTeX and LuaLaTeX. The following dependencies are required, but they are loaded automatically:

- [tikz](https://ctan.org/pkg/tikz)  
  (including `\usetikzlibrary{patterns}`)
- [xparse](https://ctan.org/pkg/xparse)

With LuaLaTeX, the package also captures stones, reads SGF games (in UTF-8, Latin-1, GBK, Big5, Shift_JIS, EUC-JP or EUC-KR) and finds the territory. `\sgfanimation` needs the [animate](https://ctan.org/pkg/animate) package.


## Installation

You can use the `pgf-go` package by placing all of the
distribution files (`pgf-go.sty`, the `pgf-go-*.sty` modules, `pgf-go.lua` and `pgf-go-charsets.lua`) in the directory containing your current tex file.

## How to use it

To use the package `pgf-go`, place the following lines in the preamble of
your LaTeX document:

```
\usepackage{pgf-go}

\begin{document}
\begin{goban}

\end{goban}
```


## Examples

You can find examples in the `doc/examples` directory:

- `example-0` to `example-7`: stones, marks, sequences, moves, territory marks, profiles and `remember`/`resume`.
- `example-8`: an SGF game with `\sgf`: marks of the file, variations as letters and a variation.
- `example-9`: a commented game with `\sgfdiagrams`: comments, annotations, result and score.
- `example-10`: an animated game in the PDF with `\sgfanimation` (needs `animate`).
- `example-11`: a game in a `beamer` presentation, one move per slide, and with `animate`.
- `example-12`: a problem (tsumego) with `\sgfproblem`.
- `example-13`: the commented game in Spanish (`babel` and translated texts).
- `example-14`: the commented game in Japanese (`luatexja`, kanji coordinates).
- `example-15`: captures, a ko, "7 at 1" notes and prisoners.
- `example-16`: territory found by `\territory{auto}`, a dead stone and the score.
- `example-17`: arrows, lines, a dimmed stone and labels.
- `example-18`: the commented game in Chinese (`ctex`), read from a GB2312 file.
- `example-19`: the commented game in Korean (`luatexko`), read from an EUC-KR file.

The last page of each example shows its code. The SGF examples need LuaLaTeX.

## History
   - version 0.2026.10.13 : Lua compute kernel, captures, SGF games (`\sgf`, `\sgfanimation`, `\sgfdiagrams`), star points, arrows and lines, "3 at 1" notes, territory and score. Both manuals are complete.
   - version 0.2025.10.13 : bug fixes. `remember`/`resume` now restore moves with their original colors and numbers, `forget` clears the memory, and `add to remember` is available. Every `goban` starts at move 1 with black. `\mark`/`\marks` only exist inside `goban`. Fixed the `n` (neutral) alias, `use i = false` with `\stone`, `A:B` ranges on non-square partial boards, and `sequence = false`.
   - version 0.2025.03.10 : added features to system coordinates and rounded corners.
   - version 0.2025.03.07 : partial realease.

## Author

Jonatán Perren, jonatan (dot) perren (at) gmail (dot) com
