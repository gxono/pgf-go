"""Agrega analisis a la linea principal de un SGF, en el formato de KaTrain, Lizzie, q5Go o Sabaki.

uso: python -I make_analysis.py partida.sgf formato salida.sgf [katago.json]

formato: katrain, lizzie, q5go, sabaki. Sin katago.json (la salida de katago_analyze.py), los valores son
sinteticos (deterministas): sirven para probar la lectura, no dicen nada de la partida.
Con katago.json, es el analisis real de KataGo.
"""
import base64, gzip, json, math, random, re, struct, sys

LETTERS = "ABCDEFGHJKLMNOPQRSTUVWXYZ"

def tokenize(text):
    # nodos de la linea principal, con sus propiedades (lista de (ident, [valores])) y el texto original
    i, depth, out = 0, 0, []
    taken = []  # por profundidad: si ya se tomo la primera rama
    keep = True
    stack = []
    nodes = []
    while i < len(text):
        c = text[i]
        if c == "(":
            first = not (stack and stack[-1]["seen"])
            if stack: stack[-1]["seen"] = True
            stack.append({"seen": False, "keep": (stack[-1]["keep"] if stack else True) and first})
            i += 1
        elif c == ")":
            stack.pop(); i += 1
        elif c == ";":
            i += 1
            props = []
            while True:
                m = re.compile(r"\s*([A-Za-z]+)").match(text, i)
                if not m or text[m.end():].lstrip()[:1] != "[":
                    break
                ident = re.sub("[a-z]", "", m.group(1)); i = m.end()
                vals = []
                while True:
                    m2 = re.compile(r"\s*\[").match(text, i)
                    if not m2: break
                    j = m2.end(); v = []
                    while text[j] != "]":
                        if text[j] == "\\": v.append(text[j:j + 2]); j += 2
                        else: v.append(text[j]); j += 1
                    vals.append("".join(v)); i = j + 1
                props.append([ident, vals])
            if stack[-1]["keep"]:
                nodes.append(props)
        else:
            i += 1
    return nodes

def gtp(v, size):
    # size: el alto del tablero (las filas)
    if v == "" or (v == "tt" and size <= 19): return "pass"
    return LETTERS[ord(v[0]) - 97] + str(size - (ord(v[1]) - 97))

def sgfpt(g, size):
    if g == "pass": return ""
    return chr(97 + LETTERS.index(g[0])) + chr(97 + size - int(g[1:]))

def esc(s):
    return s.replace("\\", "\\\\").replace("]", "\\]")

def synthetic(nodes, sx, sy, komi):
    """Respuestas con la forma de las de KataGo (desde Negro), con valores inventados."""
    rnd = random.Random(7)
    board = {}
    moves = []
    for props in nodes:
        for ident, vals in props:
            if ident in ("AB", "AW"):
                for v in vals: board[v] = ident[1]
    turns = []
    wr, lead = 0.5, 0.5 * (7.5 - komi)
    positions = [dict(board)]
    colors = []
    for props in nodes:
        for ident, vals in props:
            if ident in ("B", "W"):
                v = vals[0]
                if v and not (v == "tt" and sx <= 19 and sy <= 19): board[v] = ident
                positions.append(dict(board)); colors.append(ident)
    for t, pos in enumerate(positions):
        to_move = "W" if (t > 0 and colors[t - 1] == "B") else "B"
        if t > 0:
            # cada jugada pierde algo (a veces mucho)
            loss = rnd.choice([0.2, 0.5, 0.8, 1.5, 0.3, 4.0, 0.1, 7.0])
            lead += -loss if colors[t - 1] == "B" else loss
            wr = 1 / (1 + math.exp(-lead / 6))
        empty = [chr(97 + x) + chr(97 + y) for x in range(sx) for y in range(sy)
                 if chr(97 + x) + chr(97 + y) not in pos]
        rnd.shuffle(empty)
        infos = []
        sign = 1 if to_move == "B" else -1
        for o, p in enumerate(empty[:4]):
            g = gtp(p, sy)
            pv = [g] + [gtp(q, sy) for q in empty[4 + 3 * o: 7 + 3 * o]]
            l = lead + sign * (0.3 - 0.6 * o)
            infos.append({"move": g, "order": o, "visits": 400 // (o + 1), "winrate": 1 / (1 + math.exp(-l / 6)),
                          "scoreLead": l, "prior": 0.4 / (o + 1), "pv": pv})
        own = []
        for y in range(sy):
            for x in range(sx):
                best, dist = 0, 99
                for p, c in pos.items():
                    d = abs(ord(p[0]) - 97 - x) + abs(ord(p[1]) - 97 - y)
                    if d < dist: best, dist = (1 if c == "B" else -1), d
                own.append(round(best * max(0.0, 1 - 0.25 * dist), 3) if dist < 99 else 0.0)
        turns.append({"turnNumber": t, "rootInfo": {"winrate": wr, "scoreLead": lead, "visits": 500,
                      "currentPlayer": to_move}, "moveInfos": infos, "ownership": own,
                      "policy": [0.0] * (sx * sy) + [0.0]})
    return {"size": sx, "turns": turns}

def main():
    src, fmt, dst = sys.argv[1:4]
    text = open(src, encoding="utf-8").read()
    nodes = tokenize(text)
    root = dict((k, v) for k, v in nodes[0])
    sz = root.get("SZ", ["19"])[0].split(":")
    sx, sy = int(sz[0]), int(sz[-1]); komi = float(root.get("KM", ["7.5"])[0])
    data = json.load(open(sys.argv[4])) if len(sys.argv) > 4 else synthetic(nodes, sx, sy, komi)
    turns = data["turns"]
    out = ["(;"]
    t = 0
    for n, props in enumerate(nodes):
        if n > 0: out.append("\n;")
        has_move = any(i in ("B", "W") for i, _ in props)
        if has_move: t += 1
        for ident, vals in props:
            out.append(ident + "".join("[" + v + "]" for v in vals))
        if n == 0 and fmt == "katrain": out.append("KTV[1.0]")
        if n > 0 and not has_move: continue
        r = turns[t]
        root_info, infos = r["rootInfo"], r["moveInfos"]
        to_move_black = r["rootInfo"].get("currentPlayer", "B") == "B"
        if fmt == "katrain":
            main_json = {"root": root_info, "moves": {m["move"]: {k: m[k] for k in m if k != "move"} for m in infos},
                         "completed": True}
            parts = [struct.pack(f"{len(r['ownership'])}e", *r["ownership"]),
                     struct.pack(f"{len(r['policy'])}e", *r["policy"]), json.dumps(main_json).encode()]
            out.append("KT" + "".join("[" + base64.standard_b64encode(gzip.compress(p)).decode() + "]" for p in parts))
        elif fmt == "lizzie":
            s = 1 if to_move_black else -1
            wr_tomove = root_info["winrate"] if to_move_black else 1 - root_info["winrate"]
            visits = root_info["visits"]
            line1 = "KataGo-test %.1f %s %.1f %.1f" % (100 - 100 * wr_tomove, visits, s * root_info["scoreLead"], 12.5)
            moves = []
            for m in infos:
                w = m["winrate"] if to_move_black else 1 - m["winrate"]
                moves.append("move %s visits %d winrate %d prior %d scoreMean %.2f pv %s" % (
                    m["move"], m["visits"], int(w * 10000), int(m["prior"] * 10000), s * m["scoreLead"], " ".join(m["pv"])))
            body = " info ".join(moves) + " ownership " + " ".join("%.3f" % (s * v) for v in r["ownership"])
            out.append("LZ[" + esc(line1 + "\n" + body) + "]")
        elif fmt == "q5go":
            out.append("QKGV[%d:%f:%f:%f::KataGo-test]" % (root_info["visits"], root_info["winrate"],
                                                           root_info["scoreLead"], 12.5))
        elif fmt == "sabaki":
            out.append("SBKV[%.2f]SBKS[%.2f]" % (100 * root_info["winrate"], root_info["scoreLead"]))
    out.append(")\n")
    open(dst, "w", encoding="utf-8", newline="\n").write("".join(out))

if __name__ == "__main__":
    main()
