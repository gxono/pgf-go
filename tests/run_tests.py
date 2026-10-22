#!/usr/bin/env python3
"""Regression tests for pgf-go.

Compiles the test documents in tests/cases and the examples in doc/examples,
checks the number of errors and pgf-go warnings in each log, renders every
page to PNG and compares it pixel by pixel with tests/reference.

Usage:
    python tests/run_tests.py              run all tests
    python tests/run_tests.py marks moves  run only the documents whose name
                                           contains one of these words
    python tests/run_tests.py --update     accept the current output as the
                                           new reference images
    python tests/run_tests.py --manuals    also compare the manuals (for now only
                                           the Spanish one: see MANUALS in
                                           check_docs.py)
    python tests/run_tests.py --kernel expl3
                                           compile everything with lualatex and
                                           kernel = expl3 (lualatex uses lua by
                                           default) and compare with the same
                                           references; --kernel lua also works

Requirements: lualatex and pdflatex, pdftoppm (Poppler, included in MiKTeX
and TeX Live), Python 3.8+ and Pillow.
"""

import argparse
import concurrent.futures
import os
import re
import shutil
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path

try:
    from PIL import Image, ImageChops
except ImportError:
    sys.exit("Pillow is required: python -m pip install pillow")

ROOT = Path(__file__).resolve().parent.parent
TESTS = ROOT / "tests"
BUILD = TESTS / "_build"
REFERENCE = TESTS / "reference"

# High enough to notice changes of a fraction of a point or of an opacity.
DPI = 150
# A pixel counts as different when its grey level changes by more than this
# (out of 255).
PIXEL_THRESHOLD = 4
TIMEOUT = 900

WARNING_RE = re.compile(r"^Package pgfgo Warning:", re.MULTILINE)
ERROR_RE = re.compile(r"^! ", re.MULTILINE)
CHOOSES_KERNEL_RE = re.compile(r"\\usepackage\[[^\]]*kernel")


@dataclass
class Document:
    name: str            # unique name, also used for the reference folder
    source: Path         # .tex file
    engines: list = field(default_factory=lambda: ["lualatex"])
    expect_warnings: int = None   # None: do not check
    expect_errors: int = 0
    render: bool = True
    passes: int = 1
    kernel: str = None   # compile with \usepackage[kernel = ...]{pgf-go}
    jobname: str = None  # None: the name of the .tex file
    installed: bool = False  # the package is found in the TeX path

    def job(self):
        return self.jobname or self.source.stem


@dataclass
class Result:
    name: str
    ok: bool
    messages: list


def read_header(path):
    """Read '% key: value' lines at the top of a test document."""
    options = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        match = re.match(r"%\s*([a-z-]+):\s*(.*)$", line)
        if match:
            options[match.group(1)] = match.group(2).strip()
        elif line.strip() and not line.startswith("%"):
            break
    return options


def collect_documents(include_manuals, kernel=None):
    documents = []
    for path in sorted((TESTS / "cases").glob("*.tex")):
        header = read_header(path)
        documents.append(Document(
            name="cases/" + path.stem,
            source=path,
            engines=[e.strip() for e in header.get("engines", "lualatex").split(",")],
            expect_warnings=int(header.get("expect-warnings", 0)),
            expect_errors=int(header.get("expect-errors", 0)),
            render=header.get("render", "yes") != "no",
            passes=int(header.get("passes", 1)),
            jobname=header.get("jobname"),
            installed=header.get("installed", "no") == "yes",
        ))
    for path in sorted((ROOT / "doc" / "examples").glob("example-*.tex")):
        header = read_header(path)
        documents.append(Document(name="examples/" + path.stem, source=path,
                                  expect_warnings=0,
                                  passes=int(header.get("passes", 1))))
    if include_manuals:
        # The same manuals that check_docs.py checks.
        sys.path.insert(0, str(TESTS))
        from check_docs import MANUALS
        for lang in MANUALS:
            path = ROOT / "doc" / lang / f"pgfgo-{lang}.tex"
            # The manuals contain one example that warns on purpose.
            documents.append(Document(name=f"manuals/{lang}", source=path,
                                      expect_warnings=1, passes=2))
    if kernel:
        # Another kernel must give exactly the same output, so it is compared
        # with the references of the first engine (lualatex). Documents that
        # choose their kernel themselves are left out.
        documents = [d for d in documents
                     if not CHOOSES_KERNEL_RE.search(d.source.read_text(encoding="utf-8"))
                     and d.engines[0] == "lualatex"]
        for doc in documents:
            doc.engines = ["lualatex"]
            doc.kernel = kernel
    return documents


def compile_document(doc, engine, outdir):
    outdir.mkdir(parents=True, exist_ok=True)
    # TeX reads a file name up to the first space unless it is quoted.
    source = f'"{doc.source.name}"' if " " in doc.source.name else doc.source.name
    if doc.kernel:
        # The documents load the package as ../../latex/pgf-go, but
        # \ProcessKeyOptions looks the options up by its base name.
        source = (f"\\PassOptionsToPackage{{kernel={doc.kernel}}}{{pgf-go}}"
                  f"\\input{{{doc.source.name}}}")
    command = [engine, "-interaction=nonstopmode", f"-jobname={doc.job()}",
               f"-output-directory={outdir}", source]
    env = None
    if doc.installed:
        # The files of an installation (the modules, the Lua files and the
        # images of the profiles) in one folder, first in the TeX path.
        texmf = outdir / "texmf"
        texmf.mkdir()
        for file in [*(ROOT / "latex").iterdir(), *(ROOT / "img").glob("pgfgo-*")]:
            shutil.copy2(file, texmf / file.name)
        env = dict(os.environ, TEXINPUTS=str(texmf) + os.pathsep)
    for _ in range(doc.passes):
        subprocess.run(command, cwd=doc.source.parent, stdout=subprocess.DEVNULL,
                       stderr=subprocess.DEVNULL, timeout=TIMEOUT, env=env)
    log = outdir / (doc.job() + ".log")
    pdf = outdir / (doc.job() + ".pdf")
    text = log.read_text(encoding="latin-1") if log.exists() else ""
    return text, pdf


def render(pdf, outdir):
    """Render every page and return the PNG files in page order."""
    for old in outdir.glob("page-*.png"):
        old.unlink()
    subprocess.run(["pdftoppm", "-r", str(DPI), "-png", str(pdf), str(outdir / "page")],
                   check=True, timeout=TIMEOUT)
    pages = sorted(outdir.glob("page-*.png"),
                   key=lambda p: int(re.search(r"-(\d+)\.png$", p.name).group(1)))
    renamed = []
    for number, page in enumerate(pages, start=1):
        target = outdir / f"p{number:03d}.png"
        page.replace(target)
        renamed.append(target)
    return renamed


def compare(current, reference, diff_path):
    """Return the number of different pixels; save a side-by-side image if any."""
    a = Image.open(reference).convert("RGB")
    b = Image.open(current).convert("RGB")
    if a.size != b.size:
        changed = max(a.width * a.height, b.width * b.height)
    else:
        difference = ImageChops.difference(a.convert("L"), b.convert("L"))
        changed = sum(1 for value in difference.getdata() if value > PIXEL_THRESHOLD)
    if changed:
        width = a.width + b.width + 10
        side = Image.new("RGB", (width, max(a.height, b.height)), "red")
        side.paste(a, (0, 0))
        side.paste(b, (a.width + 10, 0))
        diff_path.parent.mkdir(parents=True, exist_ok=True)
        side.save(diff_path)
    return changed


def clear_dir(path):
    """Empty a directory without removing it (Windows refuses to delete a
    directory that is open in a shell or file explorer)."""
    path.mkdir(parents=True, exist_ok=True)
    for child in path.iterdir():
        if child.is_dir():
            shutil.rmtree(child, ignore_errors=True)
        else:
            child.unlink()


def run_document(doc, update):
    messages = []
    ok = True
    for index, engine in enumerate(doc.engines):
        outdir = BUILD / doc.name / engine
        if doc.kernel:
            outdir = BUILD / f"kernel-{doc.kernel}" / doc.name / engine
        clear_dir(outdir)
        try:
            log, pdf = compile_document(doc, engine, outdir)
        except subprocess.TimeoutExpired:
            return Result(doc.name, False, [f"{engine}: timed out"])

        if doc.kernel and f"pgf-go-kernel-{doc.kernel}.sty" not in log:
            return Result(doc.name, False, [f"{engine}: kernel = {doc.kernel} was not loaded"])

        errors = len(ERROR_RE.findall(log))
        warnings = len(WARNING_RE.findall(log))
        if errors != doc.expect_errors:
            ok = False
            messages.append(f"{engine}: {errors} errors, expected {doc.expect_errors}")
        if doc.expect_warnings is not None and warnings != doc.expect_warnings:
            ok = False
            messages.append(f"{engine}: {warnings} pgfgo warnings, expected {doc.expect_warnings}")

        if not doc.render:
            continue
        if not pdf.exists():
            ok = False
            messages.append(f"{engine}: no PDF produced")
            continue

        try:
            pages = render(pdf, outdir)
        except subprocess.CalledProcessError:
            ok = False
            messages.append(f"{engine}: pdftoppm could not read the PDF")
            continue
        # Fonts differ slightly between engines, so each engine after the
        # first one has its own references in a subfolder.
        reference_dir = REFERENCE / doc.name
        if index > 0:
            reference_dir = reference_dir / engine
        if update:
            clear_dir(reference_dir)
            for page in pages:
                shutil.copy2(page, reference_dir / page.name)
            messages.append(f"{engine}: reference updated ({len(pages)} pages)")
            continue

        references = sorted(reference_dir.glob("p*.png")) if reference_dir.exists() else []
        if not references:
            ok = False
            messages.append(f"{engine}: no reference images (run with --update)")
            continue
        if len(references) != len(pages):
            ok = False
            messages.append(f"{engine}: {len(pages)} pages, reference has {len(references)}")
        for page in pages:
            reference = reference_dir / page.name
            if not reference.exists():
                continue
            diff = BUILD / "diffs" / doc.name / (f"kernel-{doc.kernel}" if doc.kernel else engine) / page.name
            changed = compare(page, reference, diff)
            if changed:
                ok = False
                messages.append(f"{engine}: page {page.stem[1:]}: {changed} pixels differ")
    return Result(doc.name, ok, messages)


def main():
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("filters", nargs="*",
                        help="run only the documents whose name contains one of these words")
    parser.add_argument("--update", action="store_true",
                        help="replace the reference images with the current output")
    parser.add_argument("--manuals", action="store_true",
                        help="also compile and compare the manuals (for now only the Spanish one)")
    parser.add_argument("--kernel", choices=["expl3", "lua"],
                        help="compile with this compute kernel (lualatex only) and "
                             "compare with the same references")
    # Parallel lualatex runs can corrupt each other's font cache
    # (luaotfload), so the default is to compile one document at a time.
    parser.add_argument("--jobs", type=int, default=1,
                        help="number of documents compiled in parallel (default 1)")
    args = parser.parse_args()
    if args.kernel and args.update:
        sys.exit("--kernel compares with the existing references; it cannot be used with --update")

    for tool in ("lualatex", "pdftoppm"):
        if shutil.which(tool) is None:
            sys.exit(f"'{tool}' was not found in the PATH")

    documents = collect_documents(args.manuals, args.kernel)
    check_keys = not args.filters or any(f in "docs/keys" for f in args.filters)
    if args.filters:
        documents = [d for d in documents if any(f in d.name for f in args.filters)]
    if not documents and not check_keys:
        sys.exit("no documents match")

    if (BUILD / "diffs").exists():
        clear_dir(BUILD / "diffs")

    results = []
    # The manuals must document every key and command (see check_docs.py).
    if check_keys:
        sys.path.insert(0, str(TESTS))
        import check_docs
        problems = check_docs.check()
        results.append(Result("docs/keys", not problems, problems))
        print(f"{'ok  ' if not problems else 'FAIL'} docs/keys", flush=True)
        for problem in problems:
            print(f"       {problem}", flush=True)

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        futures = [pool.submit(run_document, doc, args.update) for doc in documents]
        for future in concurrent.futures.as_completed(futures):
            result = future.result()
            results.append(result)
            status = "ok  " if result.ok else "FAIL"
            print(f"{status} {result.name}", flush=True)
            for message in result.messages:
                print(f"       {message}", flush=True)

    failed = [r for r in results if not r.ok]
    print()
    print(f"{len(results) - len(failed)} passed, {len(failed)} failed")
    if failed and (BUILD / "diffs").exists():
        print(f"Side-by-side images (reference | current): {BUILD / 'diffs'}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
