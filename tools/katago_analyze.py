"""Analiza la linea principal de un SGF con KataGo y guarda las respuestas en JSON (para make_analysis.py).

uso: python -I katago_analyze.py partida.sgf salida.json visitas

KATAGO (variable de entorno): la carpeta con katago.exe, analysis_example.cfg y la red (net.bin.gz).
"""
import json, re, subprocess, sys, os

KATAGO = os.environ.get("KATAGO", os.path.join(os.path.dirname(__file__), "katago"))

def main_line(text):
    # Nodos de la linea principal: en cada '(' se sigue la primera rama.
    nodes, i, depth, skip = [], 0, 0, 0
    props_re = re.compile(r"([A-Z]+)((?:\s*\[(?:\\.|[^\]\\])*\])+)", re.S)
    out = []
    # Simplificacion: quitar ramas que no son la primera.
    def strip(s):
        res, stack, i = [], [], 0
        level_seen = {}
        while i < len(s):
            c = s[i]
            if c == "[":
                j = i + 1
                while s[j] != "]":
                    j += 2 if s[j] == "\\" else 1
                res.append(s[i:j + 1]); i = j + 1; continue
            if c == "(":
                d = len(stack)
                n = level_seen.get(d, 0)
                level_seen[d] = n + 1
                stack.append(n == 0)
                for k in list(level_seen):
                    if k > d: del level_seen[k]
                i += 1; continue
            if c == ")":
                stack.pop(); i += 1; continue
            if all(stack):
                res.append(c)
            i += 1
        return "".join(res)
    body = strip(text)
    for chunk in body.split(";")[1:]:
        node = {}
        for m in props_re.finditer(chunk):
            node[m.group(1)] = re.findall(r"\[((?:\\.|[^\]\\])*)\]", m.group(2), re.S)
        out.append(node)
    return out

def gtp(v, size):
    if v == "" or (v == "tt" and size <= 19):
        return "pass"
    x = ord(v[0]) - 97
    y = ord(v[1]) - 97
    letters = "ABCDEFGHJKLMNOPQRSTUVWXYZ"
    return letters[x] + str(size - y)

def main():
    sgf, out, visits = sys.argv[1], sys.argv[2], int(sys.argv[3])
    nodes = main_line(open(sgf, encoding="utf-8").read())
    root = nodes[0]
    size = int(root.get("SZ", ["19"])[0])
    komi = float(root.get("KM", ["7.5"])[0])
    stones = [["B", gtp(v, size)] for v in root.get("AB", [])] + [["W", gtp(v, size)] for v in root.get("AW", [])]
    moves = []
    for n in nodes:
        for c in ("B", "W"):
            if c in n:
                moves.append([c, gtp(n[c][0], size)])
    query = {
        "id": "g", "moves": moves, "initialStones": stones, "rules": root.get("RU", ["chinese"])[0].lower(),
        "komi": komi, "boardXSize": size, "boardYSize": size, "analyzeTurns": list(range(len(moves) + 1)),
        "maxVisits": visits, "includeOwnership": True, "includePolicy": True,
    }
    if query["rules"] not in ("chinese", "japanese", "korean", "aga", "tromp-taylor", "new-zealand"):
        query["rules"] = "chinese"
    p = subprocess.Popen([os.path.join(KATAGO, "katago.exe"), "analysis", "-config",
                          os.path.join(KATAGO, "analysis_example.cfg"), "-model", os.path.join(KATAGO, "net.bin.gz"),
                          "-override-config", "nnRandomize=false,logDir="],
                         stdin=subprocess.PIPE, stdout=subprocess.PIPE, text=True)
    p.stdin.write(json.dumps(query) + "\n"); p.stdin.close()
    results = {}
    for line in p.stdout:
        r = json.loads(line)
        if "error" in r:
            print(r, file=sys.stderr); break
        if "turnNumber" in r:
            results[r["turnNumber"]] = r
            print(r["turnNumber"], end=" ", flush=True, file=sys.stderr)
    p.wait()
    json.dump({"size": size, "moves": moves, "turns": [results[k] for k in sorted(results)]}, open(out, "w"))

if __name__ == "__main__":
    main()
