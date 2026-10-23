# pgf-go — for drawing go games

Release 0.2026.10.23 2026/10/23

## Description

pgf-go draws and comments on Go games with PGF/TikZ: boards, stones, moves,
marks, arrows and territory. With LuaLaTeX it also reads SGF files (a game on a
board, diagrams as in books, animations and problems), removes captured stones
and finds the territory.

## License

The code may be distributed and/or modified under the terms of the
[LaTeX Project Public License](https://www.latex-project.org/lppl/), version
1.3c or later. The manuals may be distributed and/or modified under the LaTeX
Project Public License and/or the GNU Free Documentation License.

## Requirements

LuaLaTeX is recommended (the compute kernel in Lua); with pdfLaTeX the package
works, but it cannot read SGF files, remove captured stones or find the
territory by itself. It loads TikZ and xparse; `\sgfanimation` needs
[animate](https://ctan.org/pkg/animate).

## Installation

pgf-go comes with TeX Live and MiKTeX. Otherwise, copy the files of the folder
`latex/` to the folder of your document or to your TeX tree.

## Usage

```latex
\documentclass{article}
\usepackage{pgf-go}

\begin{document}
\begin{goban}
	\stones[b]{C3}
	\stones[w]{E5}
\end{goban}
\end{document}
```

## Documentation

The manuals `pgf-go-es.pdf` (Spanish) and `pgf-go-en.pdf` (English), and the
examples in `doc/examples`.

## Changes

See `CHANGELOG.md`.

## Author

Jonatán Perren, jonatan (dot) perren (at) gmail (dot) com
