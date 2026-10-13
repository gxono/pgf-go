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
python tests/run_tests.py --manuals     # also the Spanish and English manuals (about 1 minute more)
```

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

- `cases/*.tex`: one document per area (stones, moves, marks, coordinates,
  board, profiles, remember/resume). `keys.tex` uses every option with a
  value that is not the default. Each case says what it should show.
  Some documents are only compiled, not rendered:
  - `warnings.tex` and `errors.tex` check that invalid input produces the
    expected number of warnings and errors.
  - `declarations.tex` runs with expl3's `check-declarations`, so an
    undeclared variable is an error.
  - `primitives.tex` checks that `\mark` and `\marks` still work as TeX
    primitives outside `goban`.
  - `kernel.tex` calls every function of the compute kernel interface
    (`latex/pgf-go-kernel.sty`) and raises an error for each wrong result.
    Every kernel must pass it.
  - `kernel-lua.tex` checks that `kernel = lua` falls back to `expl3` with a
    warning while the Lua kernel is not available, and that features that
    need it raise an error.
- `doc/examples/example-*.tex`: the examples shipped with the package.
- With `--manuals`: `doc/es/pgfgo-es.tex` and `doc/en/pgfgo-en.tex`.

## Writing a test document

Put a `.tex` file in `tests/cases/` and load the package with
`\usepackage{../../latex/pgf-go}`. Optional comment lines at the top
configure the test:

```
% engines: lualatex, pdflatex   engines to compile with (default: lualatex)
% expect-warnings: 0            number of "Package pgfgo Warning" lines (default 0)
% expect-errors: 0              number of errors in the log (default 0)
% render: no                    only compile and check the log
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
