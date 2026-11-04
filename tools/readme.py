"""Renders the images of the GitHub README: each latex block followed by an image readme/readme-N.png
is compiled with LuaLaTeX into that image.

    python tools/readme.py

The README of GitHub is .github/README.md (GitHub shows it instead of README.md, which is the one of
CTAN), and its images are in .github/readme. The blocks are compiled with the package of the repository
in tests/_build/readme, next to copies of the SGF files of doc/examples, in the class standalone: the
line \\documentclass of a block is replaced, and a block without \\begin{document} is the body of a
document. The width of each <img> becomes the natural one of its image. Deletes the images that the
README no longer uses.
"""

import re
import shutil
import subprocess
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
README = ROOT / ".github" / "README.md"
IMAGES = ROOT / ".github" / "readme"
BUILD = ROOT / "tests" / "_build" / "readme"
PPI = 192  # twice 96: the image is shown at half its width in pixels
BLOCK = re.compile(r"```latex\n(.*?)```\s*\n\s*<img ([^>]*?)src=\"(readme/readme-\d+\.png)\"([^>]*)>", re.S)
CLASS = r"\documentclass[border = 10pt, varwidth = 17cm]{standalone}"
PACKAGE = re.compile(r"\\usepackage(\[[^]]*\])?\{pgf-go\}")


def source(code):
    if r"\begin{document}" not in code:
        code = "\\begin{document}\n" + code + "\\end{document}\n"
    if not PACKAGE.search(code):
        code = "\\usepackage{pgf-go}\n" + code
    code = PACKAGE.sub(lambda m: r"\usepackage" + (m.group(1) or "") + "{../../../latex/pgf-go}", code)
    if r"\documentclass" in code:
        code = re.sub(r"\\documentclass(\[[^]]*\])?\{[^}]*\}", lambda m: CLASS, code, count=1)
    else:
        code = CLASS + "\n" + code
    return code


def compile_block(code, image):
    (BUILD / "readme.tex").write_text(source(code), encoding="utf-8")
    for _ in range(3):
        result = subprocess.run(["lualatex", "-interaction=nonstopmode", "-halt-on-error", "readme.tex"],
                                cwd=BUILD, capture_output=True, text=True, encoding="utf-8", errors="replace")
        if result.returncode != 0:
            sys.exit(f"{image}:\n{result.stdout[-3000:]}")
        log = (BUILD / "readme.log").read_text(encoding="utf-8", errors="replace")
        if "Rerun" not in log:
            break
    target = ROOT / ".github" / image
    subprocess.run(["pdftocairo", "-png", "-r", str(PPI), "-singlefile", "-f", "1", "-l", "1",
                    str(BUILD / "readme.pdf"), str(target.with_suffix(""))], check=True)
    return Image.open(target).width * 96 // PPI


def main():
    text = README.read_text(encoding="utf-8")
    shutil.rmtree(BUILD, ignore_errors=True)
    BUILD.mkdir(parents=True)
    IMAGES.mkdir(exist_ok=True)
    for sgf in (ROOT / "doc" / "examples").glob("*.sgf"):
        shutil.copy(sgf, BUILD)
    used = set()

    def render(match):
        code, before, image, after = match.groups()
        width = compile_block(code, image)
        used.add(image)
        print(image, width)
        attributes = re.sub(r'\s*width="\d+"', "", before + after).strip()
        return match.group(0)[:match.start(2) - match.start(0)] + f'{attributes} src="{image}" width="{width}">'

    text = BLOCK.sub(render, text)
    README.write_text(text, encoding="utf-8", newline="\n")
    for old in IMAGES.glob("readme-*.png"):
        if f"readme/{old.name}" not in used:
            old.unlink()
    print(f"{len(used)} images")


if __name__ == "__main__":
    main()
