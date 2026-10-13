-- pgf-go.lua: kernel de calculo en Lua de pgf-go (kernel = lua).
-- LA INTERFAZ ESTA DESCRIPTA EN pgf-go-kernel.sty. EL PEGAMENTO CON TeX ESTA EN pgf-go-kernel-lua.sty:
-- ESE ARCHIVO PASA LAS ENTRADAS COMO ARGUMENTOS Y ESTE DEVUELVE LOS RESULTADOS EN LAS VARIABLES DE
-- TeX DEL CONTRATO. EL ESTADO LOCAL (TAMANO, VENTANA) VIVE EN REGISTROS DE TeX PARA RESPETAR LOS
-- GRUPOS; EL ESTADO GLOBAL (JUGADA, TURNO, SECUENCIA, MEMORIA) VIVE ACA.

local pgfgo = {}

local concat, insert = table.concat, table.insert
local floor = math.floor

-- CATCODES DE expl3 PARA EL CODIGO QUE SE DEVUELVE A TeX.
local code_cctab = luatexbase.registernumber("c_code_cctab")

local function tex_code(s)
	tex.sprint(code_cctab, s)
end

-- MENSAJE DE pgf-go. EL ARGUMENTO VA COMO TEXTO (CATCODES 12 Y ESPACIOS).
local function message(kind, name, ...)
	tex_code("\\msg_" .. kind .. ":nn" .. string.rep("n", select("#", ...)) .. "{pgfgo}{" .. name .. "}")
	for i = 1, select("#", ...) do
		tex_code("{")
		tex.sprint(-2, tostring((select(i, ...))))
		tex_code("}")
	end
end

local function count(name)
	return tex.getcount(name)
end


---------------------------------------------------------------------------------------------------
-- COLUMNAS
---------------------------------------------------------------------------------------------------

-- LETRA -> NUMERO DE COLUMNA. SIN use i, J ES 9 (Y I TAMBIEN, POR LAS DUDAS).
local function column_number(letter, use_i)
	local n = letter:byte() - 64
	if not use_i and n > 9 then
		n = n - 1
	end
	return n
end

-- NUMERO -> LETRAS, COMO \int_to_Alph:n (27 ES AA).
local function alph(n)
	local s = ""
	while n > 0 do
		local r = (n - 1) % 26
		s = string.char(65 + r) .. s
		n = (n - 1 - r) // 26
	end
	return s
end

function pgfgo.column_name(x, use_i)
	if not use_i and x > 8 then
		x = x + 1
	end
	tex.sprint(alph(x))
end


---------------------------------------------------------------------------------------------------
-- TABLERO
---------------------------------------------------------------------------------------------------

function pgfgo.board_size(spec)
	local x, y = spec:match("^(%d%d?)%s*x%s*(%d%d?)$")
	if not x then
		x = spec:match("^(%d%d?)$")
		y = x
	end
	if x then
		tex.setcount("l_pgfgo_goban_size_x_int", tonumber(x))
		tex.setcount("l_pgfgo_goban_size_y_int", tonumber(y))
	else
		message("error", "unknown-goban-key", spec)
	end
end

-- COLUMNA (SIN DISTINGUIR MAYUSCULAS) Y FILA DE UNA COORDENADA COMO C3. LA FILA QUEDA COMO TEXTO.
local function parse_window_corner(s, use_i)
	local letters, digits = s:match("^([A-Za-z]*)%s*(%d*)")
	local x = 0
	for c in letters:upper():gmatch(".") do
		x = 26 * x + c:byte() - 64
	end
	if not use_i and x > 9 then
		x = x - 1
	end
	return x, digits
end

function pgfgo.board_window(spec, use_i)
	local from, to = spec:match("^%s*([a-zA-Z]%s*%d%d?)%s*to%s*([a-zA-Z]%s*%d%d?)%s*$")
	local fx, fy = parse_window_corner(from or "", use_i)
	local tx, ty = parse_window_corner(to or "", use_i)
	-- LAS FILAS PASAN POR \int_set:Nn COMO EN EL KERNEL expl3 (UNA VENTANA MAL ESCRITA DA EL MISMO ERROR).
	tex_code("\\int_set:Nn\\l__pgfgo_kernel_window_from_x_int{" .. fx .. "}"
		.. "\\int_set:Nn\\l__pgfgo_kernel_window_from_y_int{" .. fy .. "}"
		.. "\\int_set:Nn\\l__pgfgo_kernel_window_to_x_int{" .. tx .. "}"
		.. "\\int_set:Nn\\l__pgfgo_kernel_window_to_y_int{" .. ty .. "}")
end

function pgfgo.board_init(partial)
	local sx, sy = count("l_pgfgo_goban_size_x_int"), count("l_pgfgo_goban_size_y_int")
	local fx, fy, tx, ty = 1, 1, sx, sy
	if partial then
		local wfx, wfy = count("l__pgfgo_kernel_window_from_x_int"), count("l__pgfgo_kernel_window_from_y_int")
		local wtx, wty = count("l__pgfgo_kernel_window_to_x_int"), count("l__pgfgo_kernel_window_to_y_int")
		fx = math.max(1, math.min(wfx, wtx))
		fy = math.max(1, math.min(wfy, wty))
		tx = math.min(sx, math.max(wfx, wtx))
		ty = math.min(sy, math.max(wfy, wty))
	end
	tex.setcount("l_pgfgo_goban_from_x_int", fx)
	tex.setcount("l_pgfgo_goban_from_y_int", fy)
	tex.setcount("l_pgfgo_goban_to_x_int", tx)
	tex.setcount("l_pgfgo_goban_to_y_int", ty)
end

local function window()
	return count("l_pgfgo_goban_from_x_int"), count("l_pgfgo_goban_to_x_int"),
		count("l_pgfgo_goban_from_y_int"), count("l_pgfgo_goban_to_y_int")
end

function pgfgo.if_visible(x, y)
	if x >= 1 and x <= count("l_pgfgo_goban_size_x_int") and y >= 1 and y <= count("l_pgfgo_goban_size_y_int") then
		local fx, tx, fy, ty = window()
		if x >= fx and x <= tx and y >= fy and y <= ty then
			tex_code("\\prg_return_true:")
		else
			tex_code("\\prg_return_false:")
		end
	else
		message("warning", "outside-board", x, y)
		tex_code("\\prg_return_false:")
	end
end


---------------------------------------------------------------------------------------------------
-- COORDENADAS
---------------------------------------------------------------------------------------------------

-- LISTA SIN REPETIDOS QUE CONSERVA EL ORDEN DE LA PRIMERA APARICION.
local function add_unique(list, seen, item)
	if not seen[item] then
		seen[item] = true
		insert(list, item)
	end
end

local function point(x, y)
	return "{" .. x .. "}{" .. y .. "}"
end

-- RECORRE DE a A b EN ORDEN CRECIENTE, SIN IMPORTAR CUAL ES MAYOR.
local function sorted_range(a, b)
	a, b = tonumber(a), tonumber(b)
	if a > b then
		a, b = b, a
	end
	local i = a - 1
	return function()
		i = i + 1
		if i <= b then
			return i
		end
	end
end

-- CADA FORMA DE SUBCONJUNTO, EN EL ORDEN EN QUE SE PRUEBAN. c ES LA COLUMNA (LETRA -> NUMERO) Y w
-- LA PARTE VISIBLE. LAS FILAS QUE SE ESCRIBEN TAL CUAL (C05) QUEDAN COMO TEXTO, COMO EN expl3.
local subsets = {
	{"^([A-Z])(%d%d?)$", function(out, c, w, l, n)
		out(c(l), n)
	end},
	{"^([A-Z]):([A-Z])%s*(%d%d?)$", function(out, c, w, l1, l2, n)
		for x in sorted_range(c(l1), c(l2)) do out(x, n) end
	end},
	{"^([A-Z])%s*(%d%d?):(%d%d?)$", function(out, c, w, l, n1, n2)
		for y in sorted_range(n1, n2) do out(c(l), y) end
	end},
	{"^([A-Z]):([A-Z])%s*(%d%d?):(%d%d?)$", function(out, c, w, l1, l2, n1, n2)
		for x in sorted_range(c(l1), c(l2)) do
			for y in sorted_range(n1, n2) do out(x, y) end
		end
	end},
	{"^([A-Z])(%d%d?)%s*%-|%s*([A-Z])(%d%d?)$", function(out, c, w, l1, n1, l2, n2)
		for x in sorted_range(c(l1), c(l2)) do out(x, n1) end
		for y in sorted_range(n1, n2) do out(c(l2), y) end
	end},
	{"^([A-Z])(%d%d?)%s*|%-%s*([A-Z])(%d%d?)$", function(out, c, w, l1, n1, l2, n2)
		for y in sorted_range(n1, n2) do out(c(l1), y) end
		for x in sorted_range(c(l1), c(l2)) do out(x, n2) end
	end},
	{"^([A-Z])(%d%d?)%s*%-%-%s*([A-Z])(%d%d?)$", function(out, c, w, l1, n1, l2, n2)
		if tonumber(n1) == tonumber(n2) then
			for x in sorted_range(c(l1), c(l2)) do out(x, n1) end
		elseif c(l1) == c(l2) then
			for y in sorted_range(n1, n2) do out(c(l1), y) end
		else
			message("warning", "diagonal-line", l1 .. n1 .. " -- " .. l2 .. n2)
		end
	end},
	{"^([A-Z])(%d%d?)%s*R%s*([A-Z])(%d%d?)$", function(out, c, w, l1, n1, l2, n2)
		for x in sorted_range(c(l1), c(l2)) do
			for y in sorted_range(n1, n2) do out(x, y) end
		end
	end},
	{"^([A-Z])(%d%d?)%s*r%s*([A-Z])(%d%d?)$", function(out, c, w, l1, n1, l2, n2)
		for x in sorted_range(c(l1), c(l2)) do
			out(x, n1)
			out(x, n2)
		end
		for y in sorted_range(n1, n2) do
			out(c(l1), y)
			out(c(l2), y)
		end
	end},
	{"^([A-Z])$", function(out, c, w, l)
		for y in sorted_range(w.fy, w.ty) do out(c(l), y) end
	end},
	{"^(%d%d?)$", function(out, c, w, n)
		for x in sorted_range(w.fx, w.tx) do out(x, n) end
	end},
	{"^([A-Z]):([A-Z])$", function(out, c, w, l1, l2)
		for x in sorted_range(c(l1), c(l2)) do
			for y in sorted_range(w.fy, w.ty) do out(x, y) end
		end
	end},
	{"^(%d%d?):(%d%d?)$", function(out, c, w, n1, n2)
		for x in sorted_range(w.fx, w.tx) do
			for y in sorted_range(n1, n2) do out(x, y) end
		end
	end},
	{"^%*$", function(out, c, w)
		for x in sorted_range(w.fx, w.tx) do
			for y in sorted_range(w.fy, w.ty) do out(x, y) end
		end
	end},
}

-- INTERSECCIONES DE UN SUBCONJUNTO (A3, A:C, A3 -| B5, ...), SIN REPETIR.
local function expand_subset(subset, c, w)
	local list, seen = {}, {}
	local function out(x, y)
		add_unique(list, seen, point(x, y))
	end
	for _, rule in ipairs(subsets) do
		local captures = {subset:match(rule[1])}
		if captures[1] then
			rule[2](out, c, w, table.unpack(captures))
			return list
		end
	end
	if subset:find("%S") then
		message("warning", "unknown-coordinate", subset)
	end
	return list
end


-- CADENAS DE OPERADORES: A2 -| A3 -| A5 SE PARTE EN A2 -| A3, A3 -| A5. REPRODUCE LA EXPRESION
-- REGULAR (--|\|-|-\||r|R)\s*(\w+\d+)\s*(--|\|-|-\||r|R) DEL KERNEL expl3, CON SU BACKTRACKING.
local operators = {"--", "|-", "-|", "r", "R"}

local function operators_at(s, i)
	local found = {}
	for _, op in ipairs(operators) do
		if s:sub(i, i + #op - 1) == op then
			insert(found, {i + #op, op})
		end
	end
	return found
end

local function run_end(s, i, class)
	while i <= #s and s:sub(i, i):find(class) do
		i = i + 1
	end
	return i
end

local function chain_match(s, i)
	for _, first in ipairs(operators_at(s, i)) do
		local j = first[1]
		for k = run_end(s, j, "%s"), j, -1 do
			for word_end = run_end(s, k, "[%w_]") - 1, k, -1 do
				for digits_end = run_end(s, word_end + 1, "%d") - 1, word_end + 1, -1 do
					for t = run_end(s, digits_end + 1, "%s"), digits_end + 1, -1 do
						local last = operators_at(s, t)[1]
						if last then
							return last[1], first[2], s:sub(k, digits_end), last[2]
						end
					end
				end
			end
		end
	end
end

local function expand_chains(s)
	repeat
		local out, i, replaced = {}, 1, false
		while i <= #s do
			local stop, op1, coordinate, op2 = chain_match(s, i)
			if stop then
				insert(out, op1 .. " " .. coordinate .. ", " .. coordinate .. " " .. op2)
				i, replaced = stop, true
			else
				insert(out, s:sub(i, i))
				i = i + 1
			end
		end
		s = concat(out)
	until not replaced
	return s
end


-- ELEMENTOS DE UNA LISTA SEPARADA POR COMAS, SIN ESPACIOS EN LOS EXTREMOS Y SIN ELEMENTOS VACIOS.
local function clist(s)
	local items = {}
	for item in (s .. ","):gmatch("([^,]*),") do
		item = item:match("^%s*(.-)%s*$")
		if item ~= "" then
			insert(items, item)
		end
	end
	return items
end

-- INTERSECCIONES DE UN GRUPO (LO QUE ESTA ENTRE DOS ;).
local function expand_group(group, c, w)
	group = expand_chains(group)

	-- LAS FORMAS CON CORCHETES TIENEN COMAS ADENTRO: SE SACAN ANTES DE PARTIR EL GRUPO.
	local bracketed = {}
	group = group:gsub("%[([^%]]*)%]%[([^%]]*)%]", function(letters, numbers)
		for _, l in ipairs(clist(letters)) do
			for _, n in ipairs(clist(numbers)) do insert(bracketed, l .. n) end
		end
		return ""
	end)
	local by_letter = {}
	group = group:gsub("([A-Z])%[([^%]]*)%]", function(l, numbers)
		for _, n in ipairs(clist(numbers)) do insert(by_letter, l .. n) end
		return ""
	end)
	local by_number = {}
	group = group:gsub("%[([^%]]*)%](%d%d?)", function(letters, n)
		for _, l in ipairs(clist(letters)) do insert(by_number, l .. n) end
		return ""
	end)

	local subsets_list = clist(group)
	for _, more in ipairs({bracketed, by_letter, by_number}) do
		for _, s in ipairs(more) do insert(subsets_list, s) end
	end

	local list, seen = {}, {}
	for _, subset in ipairs(subsets_list) do
		for _, item in ipairs(expand_subset(subset, c, w)) do
			add_unique(list, seen, item)
		end
	end
	return list
end

local function column_function(use_i)
	return function(letter)
		return column_number(letter, use_i)
	end
end

-- TODA LA SINTAXIS DE \stones: LOS GRUPOS SEPARADOS POR ; SE SUMAN Y SE RESTAN ALTERNADAMENTE.
function pgfgo.points(spec, use_i)
	local fx, tx, fy, ty = window()
	local w = {fx = fx, tx = tx, fy = fy, ty = ty}
	local c = column_function(use_i)
	local list = {}
	local add = true
	for group in (spec .. ";"):gmatch("([^;]*);") do
		local items = expand_group(group:match("^%s*(.-)%s*$"), c, w)
		if add then
			for _, item in ipairs(items) do insert(list, item) end
		else
			local removed = {}
			for _, item in ipairs(items) do removed[item] = true end
			local kept = {}
			for _, item in ipairs(list) do
				if not removed[item] then insert(kept, item) end
			end
			list = kept
		end
		add = not add
	end
	local unique, seen = {}, {}
	for _, item in ipairs(list) do add_unique(unique, seen, item) end
	token.set_macro("l__pgfgo_kernel_points_clist", concat(unique, ","))
end

function pgfgo.point(spec, use_i)
	local l, n = spec:match("^([A-Z])(%d%d?)$")
	if l then
		token.set_macro("l_pgfgo_kernel_point_tl", point(column_number(l, use_i), n))
		tex_code("\\prg_return_true:")
	else
		tex_code("\\prg_return_false:")
	end
end


---------------------------------------------------------------------------------------------------
-- PIEDRAS EN EL TABLERO (CAPTURAS)
---------------------------------------------------------------------------------------------------

-- stones["x,y"] = "black" | "white".
local stones = {}

local function on_board(x, y)
	return x and y and x >= 1 and y >= 1
		and x <= count("l_pgfgo_goban_size_x_int") and y <= count("l_pgfgo_goban_size_y_int")
end

local function key(x, y)
	return x .. "," .. y
end

local function neighbours(x, y)
	local list = {}
	for _, d in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
		local nx, ny = x + d[1], y + d[2]
		if on_board(nx, ny) then
			insert(list, {nx, ny})
		end
	end
	return list
end

-- GRUPO DE LA PIEDRA EN (x,y) Y SI TIENE ALGUNA LIBERTAD.
local function group(x, y)
	local color = stones[key(x, y)]
	local members, seen, free = {}, {[key(x, y)] = true}, false
	local pending = {{x, y}}
	while #pending > 0 do
		local p = table.remove(pending)
		insert(members, p)
		for _, n in ipairs(neighbours(p[1], p[2])) do
			local k = key(n[1], n[2])
			local there = stones[k]
			if there == nil then
				free = true
			elseif there == color and not seen[k] then
				seen[k] = true
				insert(pending, n)
			end
		end
	end
	return members, free
end

local function remove_group(members, captured)
	for _, p in ipairs(members) do
		stones[key(p[1], p[2])] = nil
		insert(captured, point(p[1], p[2]))
	end
end

-- PONE UNA PIEDRA Y DEVUELVE LAS QUE SALEN DEL TABLERO.
local function play(color, x, y)
	local captured = {}
	stones[key(x, y)] = color
	for _, n in ipairs(neighbours(x, y)) do
		local there = stones[key(n[1], n[2])]
		if there and there ~= color then
			local members, free = group(n[1], n[2])
			if not free then
				remove_group(members, captured)
			end
		end
	end
	local members, free = group(x, y)
	if not free then
		remove_group(members, captured)
	end
	return captured
end

function pgfgo.board_clear()
	stones = {}
end

function pgfgo.board_put(color, x, y)
	x, y = tonumber(x), tonumber(y)
	if on_board(x, y) then
		stones[key(x, y)] = color
	end
end


---------------------------------------------------------------------------------------------------
-- JUGADAS
---------------------------------------------------------------------------------------------------

local move_number, black_turn = 1, true

function pgfgo.move_reset()
	move_number, black_turn = 1, true
end

function pgfgo.move_set_number(n)
	move_number = n
end

function pgfgo.move_set_player(player)
	black_turn = player == "black"
end

function pgfgo.move_number()
	tex.sprint(tostring(move_number))
end

function pgfgo.move_if_black()
	tex.sprint(black_turn and "1" or "0")
end

function pgfgo.move_play(x, y)
	x, y = tonumber(x), tonumber(y)
	local captured = {}
	if on_board(x, y) then
		captured = play(black_turn and "black" or "white", x, y)
	end
	token.set_macro("l__pgfgo_kernel_captured_clist", concat(captured, ","))
	move_number = move_number + 1
	black_turn = not black_turn
end


---------------------------------------------------------------------------------------------------
-- SECUENCIAS DE MARCAS
---------------------------------------------------------------------------------------------------

local sequence_number = 1

function pgfgo.sequence_reset(n)
	sequence_number = n
end

function pgfgo.sequence_number()
	tex.sprint(tostring(sequence_number))
end

function pgfgo.sequence_step()
	sequence_number = sequence_number + 1
end


---------------------------------------------------------------------------------------------------
-- SGF
---------------------------------------------------------------------------------------------------

-- ARBOL DE UNA PARTIDA: {nodes = {{PROPIEDAD = {valores}}, ...}, children = {arboles}}.
local function parse_sgf(s)
	local i = 1
	local function skip()
		i = s:find("%S", i) or #s + 1
	end
	local function value()
		-- i ESTA EN [. \] NO CIERRA EL VALOR.
		local out = {}
		i = i + 1
		while i <= #s do
			local c = s:sub(i, i)
			if c == "\\" then
				insert(out, s:sub(i + 1, i + 1))
				i = i + 2
			elseif c == "]" then
				i = i + 1
				break
			else
				insert(out, c)
				i = i + 1
			end
		end
		return concat(out)
	end
	local function node()
		local properties = {}
		while true do
			skip()
			local ident = s:match("^%a+", i)
			if not ident then
				return properties
			end
			i = i + #ident
			-- LOS NOMBRES VIEJOS (AddBlack) SE QUEDAN CON LAS MAYUSCULAS (AB).
			ident = ident:gsub("%l", "")
			local values = properties[ident] or {}
			skip()
			while s:sub(i, i) == "[" do
				insert(values, value())
				skip()
			end
			properties[ident] = values
		end
	end
	local function tree()
		local t = {nodes = {}, children = {}}
		i = i + 1
		while true do
			skip()
			local c = s:sub(i, i)
			if c == ";" then
				i = i + 1
				insert(t.nodes, node())
			elseif c == "(" then
				insert(t.children, tree())
			else
				i = i + 1
				return t
			end
		end
	end
	local start = s:find("(", 1, true)
	if not start then
		return {nodes = {}, children = {}}
	end
	i = start
	return tree()
end

-- NODOS DE LA LINEA PRINCIPAL (SIEMPRE LA PRIMERA VARIANTE).
local function main_line(t)
	local nodes = {}
	while t do
		for _, n in ipairs(t.nodes) do insert(nodes, n) end
		t = t.children[1]
	end
	return nodes
end

-- a..z SON 1..26 Y A..Z SON 27..52.
local function sgf_number(c)
	local b = c:byte()
	if b >= 97 then
		return b - 96
	end
	return b - 64 + 26
end

-- PUNTOS DE UN VALOR: "pd" O UN RECTANGULO "aa:cc". LA FILA 1 DE pgf-go ES LA DE ABAJO.
local function sgf_points(v, size_y)
	local list = {}
	local a, b = v:match("^(%a%a):(%a%a)$")
	a = a or v:match("^(%a%a)$")
	b = b or a
	if a then
		for x in sorted_range(sgf_number(a:sub(1, 1)), sgf_number(b:sub(1, 1))) do
			for y in sorted_range(sgf_number(a:sub(2, 2)), sgf_number(b:sub(2, 2))) do
				insert(list, point(x, size_y - y + 1))
			end
		end
	end
	return list
end

local function find_file(name)
	local f = io.open(name, "r")
	if f then
		f:close()
		return name
	end
	return kpse.find_file(name, "other text files") or kpse.find_file(name, "tex")
end

-- COMENTARIOS (C) DE LA ULTIMA PARTIDA LEIDA. sgf_comments[k] ES EL DE LA JUGADA k; sgf_comments[0], EL
-- DE LOS NODOS ANTERIORES A LA PRIMERA JUGADA. UN NODO SIN JUGADA SE SUMA AL COMENTARIO DE LA ANTERIOR.
local sgf_comments = {}

function pgfgo.sgf_comment(k)
	tex.sprint(-2, sgf_comments[k] or "")
end

function pgfgo.sgf_read(name)
	local black, white, moves = {}, {}, {}
	sgf_comments = {}
	local size_x, size_y = 19, 19
	local path = find_file(name)
	if not path then
		message("error", "sgf-not-found", name)
	else
		local f = io.open(path, "rb")
		local nodes = main_line(parse_sgf(f:read("a")))
		f:close()
		local root = nodes[1] or {}
		if root.SZ then
			local x, y = root.SZ[1]:match("^%s*(%d+)%s*:%s*(%d+)%s*$")
			size_x = tonumber(x or root.SZ[1]) or 19
			size_y = tonumber(y or root.SZ[1]) or 19
		end
		local started = false
		for _, n in ipairs(nodes) do
			-- LAS PIEDRAS INICIALES SON LAS DE LOS NODOS ANTERIORES A LA PRIMERA JUGADA.
			if not started then
				for _, v in ipairs(n.AB or {}) do
					for _, p in ipairs(sgf_points(v, size_y)) do insert(black, p) end
				end
				for _, v in ipairs(n.AW or {}) do
					for _, p in ipairs(sgf_points(v, size_y)) do insert(white, p) end
				end
			end
			for _, player in ipairs({{"B", "black"}, {"W", "white"}}) do
				local values = n[player[1]]
				if values then
					started = true
					local v = values[1] or ""
					-- [] Y, HASTA 19x19, [tt] SON PASES.
					local p = sgf_points(v, size_y)[1]
					if not p or (v == "tt" and size_x <= 19 and size_y <= 19) then
						p = "{}{}"
					end
					insert(moves, "{" .. player[2] .. "}" .. p)
				end
			end
			if n.C then
				local text = concat(n.C, " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
				local k = #moves
				if text ~= "" then
					sgf_comments[k] = sgf_comments[k] and (sgf_comments[k] .. " " .. text) or text
				end
			end
		end
	end
	tex.setcount("l_pgfgo_kernel_sgf_size_x_int", size_x)
	tex.setcount("l_pgfgo_kernel_sgf_size_y_int", size_y)
	token.set_macro("l__pgfgo_kernel_sgf_black_clist", concat(black, ","))
	token.set_macro("l__pgfgo_kernel_sgf_white_clist", concat(white, ","))
	token.set_macro("l__pgfgo_kernel_sgf_moves_clist", concat(moves, ","))
end


---------------------------------------------------------------------------------------------------
-- MEMORIA
---------------------------------------------------------------------------------------------------

-- CADA ELEMENTO ES LA LISTA DE TOKENS QUE VUELVE A DIBUJARLO (SE GUARDAN TOKENS, NO TEXTO, PARA NO
-- DEPENDER DE LOS CATCODES).
local remembered = {}

-- LEE EL GRUPO {...} QUE SIGUE.
function pgfgo.remember_push()
	insert(remembered, token.scan_toks())
end

function pgfgo.remember_clear()
	remembered = {}
end

function pgfgo.remember_replay()
	local all = {}
	for _, toks in ipairs(remembered) do
		for _, t in ipairs(toks) do insert(all, t) end
	end
	if #all > 0 then
		token.put_next(all)
	end
end

return pgfgo
