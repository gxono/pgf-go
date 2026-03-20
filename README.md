# pgf-go— for drawing go games.

Release 0.2025.03.10 2025/03/10

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


## Installation

You can use the `pgf-go` package by placing all of the
distribution files in the directory containing your current tex file.

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

You can find examples on doc directory.

## History
   - version 0.2025.03.10 : added features to system coordinates and rounded corners.
   - version 0.2025.03.07 : partial realease.

## Author

Jonatán Perren, jonatan (dot) perren (at) gmail (dot) com
