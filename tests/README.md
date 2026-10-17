# Regression tests

These tests check that changes to the package do not change its output by
accident. They compile a set of documents, check the errors and warnings in
each log, render every page to PNG and compare it pixel by pixel with a
reference image.

## Requirements

- `lualatex` and `pdflatex` (MiKTeX or TeX Live).
- `pdftoppm`, from Poppler. MiKTeX and TeX Live already include it.
- Python 3.8 or later with Pillow (`python -m pip install pillow`).

## Running

From the repository root:

```
python tests/run_tests.py               # all tests (about 40 seconds)
python tests/run_tests.py marks moves   # only documents whose name contains "marks" or "moves"
python tests/run_tests.py --manuals     # also the manuals (about 1 minute more)
python tests/run_tests.py --kernel expl3  # everything again with kernel = expl3 under lualatex
```

By default, the package uses the Lua compute kernel with LuaLaTeX and the
expl3 kernel with pdfLaTeX. With `--kernel expl3` (or `--kernel lua`), every
document is compiled with lualatex and that kernel, and compared with the same
references, so both kernels must give exactly the same output, warnings and
errors. Documents that choose their kernel in `\usepackage` are left out. It
cannot be combined with `--update`. It can be combined with `--manuals`.

The script ends with `N passed, M failed` and returns a non-zero exit code if
something failed. For every page that changed, it saves an image with the
reference on the left and the current output on the right in
`tests/_build/diffs/`.

## Accepting a change

When a change in the output is intended, check the images in
`tests/_build/diffs/` and then replace the references:

```
python tests/run_tests.py --update            # all documents
python tests/run_tests.py --update marks      # only some of them
```

Commit the new images in `tests/reference/` together with the change.

The references of the manuals (`--manuals`) are not committed, because they
change every time the documentation is edited and take about 25 MB. Before a change that should
not affect the manuals, create them locally with
`python tests/run_tests.py --manuals --update manuals`.

## What is tested

- `docs/keys` (`check_docs.py`): every key and command defined in
  `latex/*.sty` must be documented in the manuals listed in `MANUALS` in
  `check_docs.py` (for now only the Spanish one), and every key and command
  documented in a manual must exist. Keys that are not documented on purpose
  are listed in `UNDOCUMENTED` in `check_docs.py`. It can also be run alone:
  `python tests/check_docs.py`. It reads the keys written in `\keys_define`
  (`players/#1` in a path means any player) and the commands defined with
  `\let`, `\def` or `\cs_new_eq:NN`. Keys made by a helper or a loop must be
  listed in a comment line of the `.sty` that starts with `%CLAVES:`, for
  example `%CLAVES: /pgfgo/{arrow, line}/{color, width}`.

- `cases/*.tex`: one document per area (stones, moves, marks, coordinates,
  board, profiles, name/resume). `keys.tex` uses every option with a
  value that is not the default. Each case says what it should show.
  Some documents are only compiled, not rendered:
  - `warnings.tex` and `errors.tex` check that invalid input produces the
    expected number of warnings and errors.
  - `declarations.tex` runs with expl3's `check-declarations`, so an
    undeclared variable is an error.
  - `primitives.tex` checks that `\mark` and `\marks` still work as TeX
    primitives outside `goban`.
  - `kernel.tex` and `kernel-lua.tex` call every function of the compute
    kernel interface (`latex/pgf-go-kernel.sty`) with the expl3 and the Lua
    kernel, and raise an error for each wrong result. The checks themselves
    are in `tests/kernel-checks.tex`.
  - `kernel-fallback.tex` checks that `kernel = lua` falls back to `expl3`
    with a warning under pdfLaTeX, and that `captures` and `\sgf`, which need
    the Lua kernel, raise an error.
- `captures.tex` and `sgf.tex` (with `game.sgf`) render captures and SGF
  games. They use `kernel = lua`, so they only run with LuaLaTeX.
- `doc/examples/example-*.tex`: the examples shipped with the package. They
  can use the `% passes:` header line.
- With `--manuals`: the manuals in `MANUALS` (for now only
  `doc/es/pgfgo-es.tex`).

## Writing a test document

Put a `.tex` file in `tests/cases/` and load the package with
`\usepackage{../../latex/pgf-go}`. Optional comment lines at the top
configure the test:

```
% engines: lualatex, pdflatex   engines to compile with (default: lualatex)
% expect-warnings: 0            number of "Package pgfgo Warning" lines (default 0)
% expect-errors: 0              number of errors in the log (default 0)
% render: no                    only compile and check the log
% passes: 2                     number of runs (default 1; animate needs 2)
% jobname: a b, c=d             compile with this job name (default: the file name)
```

Fonts differ slightly between engines, so each engine has its own reference
images: those of the first engine are in `tests/reference/cases/<name>/`, and
those of the others are in a subfolder named after the engine. Then run
`python tests/run_tests.py --update <name>`, check the images in
`tests/_build/cases/<name>/<engine>/` and commit the references.

## Sensitivity

Pages are rendered at 150 dpi, and a pixel counts as changed when its grey
level moves by more than 4 out of 255. That is enough to catch, for example, a
line that is 0.05pt thicker, a mark that is 5% larger, a vertex of a triangle
that moved, or an opacity that changed from 0.5 to 0.45. The rendering is
deterministic, so this does not produce false alarms. However, updating
MiKTeX/TeX Live or Poppler can change the rendering slightly. In that case,
check the differences once and run `--update`.

Documents are compiled one at a time by default. Running several `lualatex`
processes in parallel (`--jobs`) can corrupt the font cache.
