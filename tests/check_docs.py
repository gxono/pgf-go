#!/usr/bin/env python3
"""Check that the manuals document every key and command of the package.

Reads the keys defined with \\keys_define in latex/*.sty and the user
commands, and compares them with the key, stylekey, command and environment
entries of each manual (doc/es and doc/en). It reports keys or commands that
are not documented, and documented ones that do not exist.

In the paths of \\keys_define, "players/#1" (or ##1) and \\l__pgfgo_item_tl
stand for any player: they are read as "players/<player>". Keys defined by a
helper or a loop (a path or a key name with any other #) are skipped; list
them in a comment line of the .sty that starts with "%CLAVES:", with commas
between the keys and {a, b} for alternatives:

    %CLAVES: /pgfgo/{arrow, line}/{color, width}, /pgfgo/mark/circle

Usage:
    python tests/check_docs.py

run_tests.py also runs it, as the test "docs/keys".
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BS = "\\"

# Not documented on purpose.
UNDOCUMENTED = {
    "pgfgonewplayers",                      # internal: creates the three players
}

# Documented paths that are other names for keys of the code. The manuals
# document the options of \stone, \moves and \marks as /pgfgo/stone/...,
# /pgfgo/move/... and /pgfgo/mark/...; they are keys of each player.
ALIASES = [
    ("/pgfgo/stone/", "/pgfgo/players/<player>/stone/"),
    ("/pgfgo/move/", "/pgfgo/players/<player>/move/"),
    ("/pgfgo/mark/", "/pgfgo/players/<player>/mark/"),
    ("/pgfgo/prisoner", "/pgfgo/players/<player>/stone/prisoner"),
]


def braced(s, i):
    """s[i] is '{': return the contents and the index after the closing brace."""
    depth = 0
    for j in range(i, len(s)):
        if s[j] == "{":
            depth += 1
        elif s[j] == "}":
            depth -= 1
            if depth == 0:
                return s[i + 1:j], j + 1
    raise ValueError("unbalanced braces")


def split_top(body):
    """Split at the commas that are not inside braces."""
    parts, depth, current = [], 0, []
    for ch in body:
        depth += (ch == "{") - (ch == "}")
        if ch == "," and depth == 0:
            parts.append("".join(current))
            current = []
        else:
            current.append(ch)
    parts.append("".join(current))
    return parts


def clean_path(text):
    text = text.replace(BS + "l__pgfgo_item_tl", "<player>").replace("~", " ")
    text = re.sub(r"\s*/\s*", "/", text.strip())
    return re.sub(r"(^|/)players/#+1(?=/|$)", r"\1players/<player>", text)


def expand_braces(path):
    """'a/{b, c}/d' -> ['a/b/d', 'a/c/d']."""
    m = re.search(r"\{([^{}]*)\}", path)
    if not m:
        return [path]
    return [p for alt in m.group(1).split(",")
            for p in expand_braces(path[:m.start()] + alt.strip() + path[m.end():])]


def marked_keys(text):
    """The keys listed in the %CLAVES: comment lines."""
    keys = set()
    for line in re.findall(r"^[ \t]*%CLAVES:(.*)$", text, re.M):
        for entry in split_top(line):
            if entry.strip():
                keys.update("/" + clean_path(p).strip("/") for p in expand_braces(entry.strip()))
    return keys


def code_keys():
    """Return the keys and the choices of .choices keys (path -> parent key)."""
    keys, choices = set(), {}
    for sty in sorted((ROOT / "latex").glob("*.sty")):
        text = sty.read_text(encoding="utf-8")
        keys |= marked_keys(text)
        source = re.sub(r"(?<!\\)%.*", "", text)
        for m in re.finditer(re.escape(BS) + r"keys_define:(?:nn|ee|en|ne)\s*", source):
            i = source.index("{", m.end())
            module, i = braced(source, i)
            body, _ = braced(source, source.index("{", i))
            module = clean_path(module)
            if "#" in module:
                continue        # defined by a helper: see %CLAVES:
            for entry in split_top(body):
                m2 = re.match(r"\s*(.+?)\s*\.([a-z_]+:[a-zA-Z]*)\s*(?:=\s*(.*))?$", entry, re.S)
                if not m2:
                    continue
                name, prop, value = clean_path(m2.group(1)), m2.group(2), m2.group(3) or ""
                if name == "unknown" or "#" in name or prop in ("groups:n", "default:n", "initial:n"):
                    continue
                path = "/" + module + "/" + name
                keys.add(path)
                if prop == "choices:nn":
                    values, _ = braced(value.strip(), 0)
                    choices.update({path + "/" + c.strip(): path for c in values.split(",")})
    return keys, choices


def code_commands():
    commands = set()
    for sty in sorted((ROOT / "latex").glob("*.sty")):
        source = sty.read_text(encoding="utf-8")
        commands.update(re.findall(r"(?:New|Declare)(?:Expandable)?DocumentCommand\s*\{?\s*\\([A-Za-z]+)", source))
        commands.update(re.findall(r"\\def\\(pgfgo[A-Za-z]+)", source))
        commands.update(re.findall(r"\\let\\(pgfgo[A-Za-z]+)", source))
        commands.update(re.findall(r"\\cs_(?:new|g?set)_eq:N[Nc]\s*\\(pgfgo[A-Za-z]+)(?![A-Za-z_:@])", source))
        commands.update("env:" + e for e in re.findall(r"NewDocumentEnvironment\s*\{(\w+)\}", source))
        # \mark, \marks and \sgf exist inside goban; \move is \let to \moves.
        commands.update(re.findall(r"\\cs_set_eq:NN\s*\\([A-Za-z]+)\s*\\__pgfgo", source))
        commands.update(re.findall(r"\\let\\([A-Za-z]+)\\[A-Za-z]+\s*$", source, re.M))
    return commands


def doc_entries(lang_dir):
    """Return the documented keys, the keys they cover and the commands.

    A key documented with \\meta{boolean} also covers its true and false keys."""
    keys, covered, commands = set(), set(), set()
    for tex in sorted(lang_dir.glob("*.tex")):
        source = tex.read_text(encoding="utf-8")
        for m in re.finditer(r"\\begin\{(?:key|stylekey)\}\{(/pgfgo[^=}(]*)(.*)", source):
            path = re.sub(r"\s+", " ", m.group(1).strip())
            path = re.sub(r"/players/(black|white|neutral)(?=/|$)", "/players/<player>", path)
            keys.add(path)
            covered.add(path)
            if BS + "meta{boolean}" in m.group(2):
                covered.update({path + "/true", path + "/false"})
        commands.update(re.findall(r"\\begin\{command\}\{\\([A-Za-z]+)", source))
        commands.update("env:" + e for e in re.findall(r"\\begin\{environment\}\{\{(\w+)\}", source))
    return keys, expand_aliases(covered), commands


def expand_aliases(paths):
    out = set(paths)
    for path in paths:
        for short, full in ALIASES:
            if path.startswith(short):
                out.add(full + path[len(short):])
    return out


def check():
    """Return a list of problems (empty if the manuals are complete)."""
    problems = []
    (keys, choices), commands = code_keys(), code_commands()
    for lang in ("es", "en"):
        doc_keys, covered, doc_commands = doc_entries(ROOT / "doc" / lang)
        # The values of a .choices key are covered by the key itself.
        covered |= {choice for choice, parent in choices.items() if parent in covered}
        for key in sorted(keys - covered - UNDOCUMENTED):
            problems.append(f"{lang}: key {key} is not documented")
        for key in sorted(doc_keys):
            if not expand_aliases({key}) & (keys | set(choices)):
                problems.append(f"{lang}: documented key {key} does not exist")
        for command in sorted(commands - doc_commands - UNDOCUMENTED):
            problems.append(f"{lang}: command {command} is not documented")
        for command in sorted(doc_commands - commands):
            problems.append(f"{lang}: documented command {command} does not exist")
    return problems


def main():
    problems = check()
    for problem in problems:
        print(problem)
    print(f"{len(problems)} problems")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
