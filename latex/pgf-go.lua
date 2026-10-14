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

-- PUNTOS DE ESTRELLA (VER pgf-go-kernel.sty).
function pgfgo.hoshi()
	local sx, sy = count("l_pgfgo_goban_size_x_int"), count("l_pgfgo_goban_size_y_int")
	local function axis(s)
		if s < 7 then return nil end
		local near = s >= 13 and 4 or 3
		return {near, s - near + 1}, (s % 2 == 1) and (s + 1) // 2 or nil
	end
	local xs, mx = axis(sx)
	local ys, my = axis(sy)
	local list = {}
	if xs and ys then
		local all = {}
		for _, x in ipairs(xs) do
			for _, y in ipairs(ys) do insert(all, {x, y}) end
		end
		if mx and my then
			insert(all, {mx, my})
			if sx >= 15 and sy >= 15 then
				for _, y in ipairs(ys) do insert(all, {mx, y}) end
				for _, x in ipairs(xs) do insert(all, {x, my}) end
			end
		end
		table.sort(all, function(a, b) return a[2] < b[2] or (a[2] == b[2] and a[1] < b[1]) end)
		for _, p in ipairs(all) do insert(list, "{" .. p[1] .. "}{" .. p[2] .. "}") end
	end
	token.set_macro("l__pgfgo_kernel_points_clist", concat(list, ","))
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

-- PUNTOS DE UN POLIGONO: LAS INTERSECCIONES DEL TABLERO DENTRO DEL POLIGONO CERRADO O SOBRE SU BORDE,
-- FILA POR FILA DESDE ABAJO. LA CUENTA ES CON ENTEROS (SIN REDONDEOS).
local function on_segment(px, py, a, b)
	local cross = (b[1] - a[1]) * (py - a[2]) - (b[2] - a[2]) * (px - a[1])
	return cross == 0
		and px >= math.min(a[1], b[1]) and px <= math.max(a[1], b[1])
		and py >= math.min(a[2], b[2]) and py <= math.max(a[2], b[2])
end

local function in_polygon(px, py, v)
	local n, inside_ = #v, false
	for i = 1, n do
		local a, b = v[i], v[i % n + 1]
		if on_segment(px, py, a, b) then return true end
		if (a[2] > py) ~= (b[2] > py) then
			-- px < x DEL CRUCE, MULTIPLICANDO POR dy (CON SU SIGNO).
			local dy = b[2] - a[2]
			local lhs = (px - a[1]) * dy
			local rhs = (py - a[2]) * (b[1] - a[1])
			if (dy > 0 and lhs < rhs) or (dy < 0 and lhs > rhs) then
				inside_ = not inside_
			end
		end
	end
	return inside_
end

function pgfgo.polygon(text)
	local v = {}
	for x, y in text:gmatch("{(%-?%d+)}{(%-?%d+)}") do
		insert(v, {tonumber(x), tonumber(y)})
	end
	local list = {}
	if #v > 0 then
		local sx, sy = count("l_pgfgo_goban_size_x_int"), count("l_pgfgo_goban_size_y_int")
		local fx, tx, fy, ty = sx, 1, sy, 1
		for _, p in ipairs(v) do
			fx, tx = math.min(fx, p[1]), math.max(tx, p[1])
			fy, ty = math.min(fy, p[2]), math.max(ty, p[2])
		end
		for y = math.max(1, fy), math.min(sy, ty) do
			for x = math.max(1, fx), math.min(sx, tx) do
				if in_polygon(x, y, v) then insert(list, point(x, y)) end
			end
		end
	end
	token.set_macro("l__pgfgo_kernel_points_clist", concat(list, ","))
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

-- UN TABLERO ES {stones = {["x,y"] = "black" | "white"}, sx = ancho, sy = alto}. EL DEL goban LEE SU
-- TAMANO DE TeX; LA LECTURA DE UN SGF USA OTRO PARA SIMULAR LA PARTIDA.
local stones = {}

local function goban_board()
	return {stones = stones, sx = count("l_pgfgo_goban_size_x_int"), sy = count("l_pgfgo_goban_size_y_int")}
end

local function inside(b, x, y)
	return x and y and x >= 1 and y >= 1 and x <= b.sx and y <= b.sy
end

local function on_board(x, y)
	return inside(goban_board(), x, y)
end

local function key(x, y)
	return x .. "," .. y
end

local function neighbours(b, x, y)
	local list = {}
	for _, d in ipairs({{-1, 0}, {1, 0}, {0, -1}, {0, 1}}) do
		local nx, ny = x + d[1], y + d[2]
		if inside(b, nx, ny) then
			insert(list, {nx, ny})
		end
	end
	return list
end

-- GRUPO DE LA PIEDRA EN (x,y) Y SI TIENE ALGUNA LIBERTAD.
local function group(b, x, y)
	local color = b.stones[key(x, y)]
	local members, seen, free = {}, {[key(x, y)] = true}, false
	local pending = {{x, y}}
	while #pending > 0 do
		local p = table.remove(pending)
		insert(members, p)
		for _, n in ipairs(neighbours(b, p[1], p[2])) do
			local k = key(n[1], n[2])
			local there = b.stones[k]
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

-- removed CUENTA LAS PIEDRAS QUITADAS DE CADA COLOR.
local function remove_group(b, members, captured, removed)
	for _, p in ipairs(members) do
		local color = b.stones[key(p[1], p[2])]
		removed[color] = (removed[color] or 0) + 1
		b.stones[key(p[1], p[2])] = nil
		insert(captured, point(p[1], p[2]))
	end
end

-- PONE UNA PIEDRA Y DEVUELVE LAS QUE SALEN DEL TABLERO, Y CUANTAS DE CADA COLOR.
local function play(b, color, x, y)
	local captured, removed = {}, {}
	b.stones[key(x, y)] = color
	for _, n in ipairs(neighbours(b, x, y)) do
		local there = b.stones[key(n[1], n[2])]
		if there and there ~= color then
			local members, free = group(b, n[1], n[2])
			if not free then
				remove_group(b, members, captured, removed)
			end
		end
	end
	local members, free = group(b, x, y)
	if not free then
		remove_group(b, members, captured, removed)
	end
	return captured, removed
end

-- PRISIONEROS DE CADA JUGADOR EN EL goban: LAS PIEDRAS DEL OTRO COLOR QUE SALIERON DEL TABLERO.
local prisoners = {black = 0, white = 0}

function pgfgo.board_clear()
	stones = {}
	prisoners = {black = 0, white = 0}
end

function pgfgo.prisoners(player)
	tex.sprint(tostring(prisoners[player] or 0))
end

-- color = "empty" QUITA LA PIEDRA.
function pgfgo.board_put(color, x, y)
	x, y = tonumber(x), tonumber(y)
	if on_board(x, y) then
		stones[key(x, y)] = color ~= "empty" and color or nil
	end
end

function pgfgo.board_if_occupied(x, y)
	x, y = tonumber(x), tonumber(y)
	if on_board(x, y) and stones[key(x, y)] then
		tex_code("\\prg_return_true:")
	else
		tex_code("\\prg_return_false:")
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
		local removed
		captured, removed = play(goban_board(), black_turn and "black" or "white", x, y)
		prisoners.black = prisoners.black + (removed.white or 0)
		prisoners.white = prisoners.white + (removed.black or 0)
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
	-- UN ARCHIVO PUEDE TENER VARIAS PARTIDAS (UNA COLECCION).
	local games = {}
	while true do
		local start = s:find("(", i, true)
		if not start then break end
		i = start
		insert(games, tree())
	end
	return games
end

-- NODOS DE UNA LINEA DE LA PARTIDA. path ES UNA LISTA DE NUMEROS: EN CADA BIFURCACION SE TOMA LA
-- VARIANTE path[i] (1 ES LA PRINCIPAL). CUANDO path SE TERMINA, SE SIGUE POR LA PRIMERA.
-- DEVUELVE TAMBIEN SI path PIDE UNA VARIANTE QUE NO EXISTE.
-- DEVUELVE ADEMAS, POR NODO, SUS HIJOS (LOS NODOS QUE PUEDEN SEGUIR) Y SUS HERMANOS (LAS ALTERNATIVAS
-- A ESE NODO, EL INCLUIDO).
local function game_line(t, path)
	local nodes, kids, sibs, i, missing = {}, {}, {}, 1, false
	local siblings
	local function firsts(tree)
		local list = {}
		for _, c in ipairs(tree.children) do
			if c.nodes[1] then insert(list, c.nodes[1]) end
		end
		return list
	end
	while t do
		for j, n in ipairs(t.nodes) do
			insert(nodes, n)
			sibs[#nodes] = (j == 1 and siblings) or {n}
			kids[#nodes] = j < #t.nodes and {t.nodes[j + 1]} or firsts(t)
		end
		local choice = 1
		if #t.children > 1 then
			choice = path[i] or 1
			i = i + 1
			if choice < 1 or choice > #t.children then
				missing, choice = true, 1
			end
		end
		siblings = firsts(t)
		t = t.children[choice]
	end
	return nodes, missing or i <= #path, kids, sibs
end

-- a..z SON 1..26 Y A..Z SON 27..52.
local function sgf_number(c)
	local b = c:byte()
	if b >= 97 then
		return b - 96
	end
	return b - 64 + 26
end

-- PUNTOS DE UN VALOR: "pd" O UN RECTANGULO "aa:cc", COMO {x, y}. LA FILA 1 DE pgf-go ES LA DE ABAJO.
local function sgf_coords(v, size_y)
	local list = {}
	local a, b = v:match("^(%a%a):(%a%a)$")
	a = a or v:match("^(%a%a)$")
	b = b or a
	if a then
		for x in sorted_range(sgf_number(a:sub(1, 1)), sgf_number(b:sub(1, 1))) do
			for y in sorted_range(sgf_number(a:sub(2, 2)), sgf_number(b:sub(2, 2))) do
				insert(list, {x, size_y - y + 1})
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

-- LOS ARCHIVOS QUE NO SON UTF-8 VALIDO SE LEEN COMO Latin-1 (LA CODIFICACION POR DEFECTO DE SGF). UNA
-- CODIFICACION (CA) QUE NO ES NINGUNA DE LAS DOS PRODUCE UN AVISO.
local latin = {["iso-8859-1"] = true, ["iso8859-1"] = true, latin1 = true, ["latin-1"] = true,
	["windows-1252"] = true, cp1252 = true, ascii = true, ["us-ascii"] = true, ["utf-8"] = true, utf8 = true}

local function to_utf8(name, s)
	local ca = s:match("CA%s*%[([^%]]*)%]")
	if ca and not latin[ca:lower():gsub("%s", "")] then
		message("warning", "sgf-charset", name, ca)
	end
	if not utf8.len(s) then
		s = s:gsub("[\128-\255]", function(c) return utf8.char(c:byte()) end)
	end
	return s
end

-- LA PARTIDA \l_pgfgo_kernel_sgf_game_int DEL ARCHIVO. AVISA SI NO EXISTE Y USA LA PRIMERA.
local function read_tree(name)
	local path = find_file(name)
	if not path then
		message("error", "sgf-not-found", name)
		return nil
	end
	local f = io.open(path, "rb")
	local games = parse_sgf(to_utf8(name, f:read("a")))
	f:close()
	local n = count("l_pgfgo_kernel_sgf_game_int")
	if not games[n] then
		if n ~= 1 then message("warning", "sgf-game", name, n) end
		n = 1
	end
	return games[n] or {nodes = {}, children = {}}
end

-- DATOS DE LA ULTIMA PARTIDA LEIDA, POR JUGADA k (0: LOS NODOS ANTERIORES A LA PRIMERA JUGADA). UN NODO
-- SIN JUGADA SE SUMA A LA JUGADA ANTERIOR.
-- sgf_comments[k]: COMENTARIO (C). sgf_marks[k]: MARCAS (TR, SQ, CR, MA, LB) Y TERRITORIO (TB, TW),
-- "{forma}{x}{y}{color}{i}" (color: EL DE LA PIEDRA QUE HAY AHI, O neutral; i: EL TEXTO DE LB EN
-- sgf_labels[i]). LA FORMA DEL TERRITORIO ES black-territory O white-territory; LA DE SL, selected.
-- sgf_dim[k]: LOS PUNTOS ATENUADOS (DD), QUE SE HEREDAN HASTA EL PROXIMO DD. sgf_lines[k]: FLECHAS (AR) Y
-- LINEAS (LN), "{arrow | line}{x1}{y1}{x2}{y2}".
-- sgf_notes[k]: ANOTACIONES (N; DE LA JUGADA: TE, BM, DO, IT; DE LA POSICION: GB, GW, DM, UC), "{propiedad}{valor}"; EL VALOR DE N ES
-- EL NUMERO DE SU TEXTO EN sgf_names.
local sgf_comments, sgf_marks, sgf_labels, sgf_dim, sgf_lines = {}, {}, {}, {}, {}
local sgf_notes, sgf_names = {}, {}
-- sgf_vars[k]: LAS VARIANTES DE LA JUGADA k, {children = {...}, siblings = {...}}, CADA UNA "{x}{y}{color}".
-- sgf_style: ST DE LA RAIZ. sgf_figures: "{jugada}{nombre}" DONDE EMPIEZA CADA FIGURA (FG).
local sgf_vars, sgf_style, sgf_figures = {}, 0, {}

function pgfgo.sgf_comment(k)
	tex.sprint(-2, sgf_comments[k] or "")
end

-- PRIMERO LOS PUNTOS ATENUADOS, PARA QUE LAS DEMAS MARCAS QUEDEN ENCIMA.
function pgfgo.sgf_marks(k)
	local list = {}
	for _, p in ipairs(sgf_dim[k] or {}) do insert(list, "{dim}" .. p .. "{neutral}{}") end
	for _, m in ipairs(sgf_marks[k] or {}) do insert(list, m) end
	token.set_macro("l__pgfgo_kernel_sgf_marks_clist", concat(list, ","))
end

function pgfgo.sgf_annotations(k)
	token.set_macro("l__pgfgo_kernel_sgf_annotations_clist", concat(sgf_notes[k] or {}, ","))
end

function pgfgo.sgf_name(i)
	tex.sprint(-2, sgf_names[i] or "")
end

-- LAS VARIANTES DE LA JUGADA k COMO LETRAS: mode ES children (LAS JUGADAS QUE PUEDEN SEGUIR), siblings (LAS
-- ALTERNATIVAS A LA JUGADA k) O auto (LO QUE DICE ST). SOLO SI HAY MAS DE UNA.
function pgfgo.sgf_variations(k, mode)
	if mode == "auto" then
		mode = (sgf_style % 4 >= 2) and "none" or ((sgf_style % 2 == 1) and "siblings" or "children")
	end
	local list = {}
	local found = sgf_vars[k] and sgf_vars[k][mode] or {}
	if #found > 1 then
		for i, v in ipairs(found) do
			if v ~= "" then insert(list, v .. "{" .. string.char(64 + i) .. "}") end
		end
	end
	token.set_macro("l__pgfgo_kernel_sgf_variations_clist", concat(list, ","))
end

function pgfgo.sgf_lines(k)
	token.set_macro("l__pgfgo_kernel_sgf_lines_clist", concat(sgf_lines[k] or {}, ","))
end

function pgfgo.sgf_label(i)
	tex.sprint(-2, sgf_labels[i] or "")
end

local markup = {{"TR", "triangle"}, {"SQ", "square"}, {"CR", "circle"}, {"MA", "cross"},
	{"SL", "selected"}, {"TB", "black-territory"}, {"TW", "white-territory"}}

function pgfgo.sgf_read(name, path_text)
	local black, white, moves = {}, {}, {}
	sgf_comments, sgf_marks, sgf_labels, sgf_dim, sgf_lines = {}, {}, {}, {}, {}
	sgf_notes, sgf_names = {}, {}
	sgf_vars, sgf_style, sgf_figures = {}, 0, {}
	local view
	local size_x, size_y = 19, 19
	local path = {}
	for d in (path_text or ""):gmatch("%d+") do insert(path, tonumber(d)) end
	local t = read_tree(name)
	if t then
		local nodes, missing, kids, sibs = game_line(t, path)
		if missing then
			message("warning", "sgf-variation", name, path_text)
		end
		local root = nodes[1] or {}
		if root.SZ then
			local x, y = root.SZ[1]:match("^%s*(%d+)%s*:%s*(%d+)%s*$")
			size_x = tonumber(x or root.SZ[1]) or 19
			size_y = tonumber(y or root.SZ[1]) or 19
		end
		sgf_style = root.ST and tonumber(root.ST[1]) or 0
		-- LA PARTIDA SIMULADA, PARA SABER DE QUE COLOR ES CADA PUNTO MARCADO.
		local sim = {stones = {}, sx = size_x, sy = size_y}
		local started, count = false, 0
		local dim = {}
		local function each_point(node, property, f)
			for _, v in ipairs(node[property] or {}) do
				for _, c in ipairs(sgf_coords(v, size_y)) do f(point(c[1], c[2]), c) end
			end
		end
		local function without(list, p)
			local kept = {}
			for _, q in ipairs(list) do
				if q ~= p then insert(kept, q) end
			end
			return kept
		end
		local function put(c, color)
			if inside(sim, c[1], c[2]) then sim.stones[key(c[1], c[2])] = color end
		end
		-- LA JUGADA DE UN NODO: {x}{y}, O "" SI ES UN PASE O NO TIENE JUGADA.
		local function move_point(n)
			local v = (n.B or n.W or {})[1]
			local c = v and sgf_coords(v, size_y)[1]
			if not c or (v == "tt" and size_x <= 19 and size_y <= 19) then return "" end
			return point(c[1], c[2]) .. "{" .. (sim.stones[key(c[1], c[2])] or "neutral") .. "}"
		end
		local function moves_of(list)
			local out = {}
			for _, m in ipairs(list or {}) do
				if m.B or m.W then insert(out, move_point(m)) end
			end
			return out
		end
		for idx, n in ipairs(nodes) do
			-- VW: LA VISTA DE LOS NODOS ANTERIORES A LA PRIMERA JUGADA (VW[] ES TODO EL TABLERO).
			if not started and n.VW then
				view = nil
				each_point(n, "VW", function(p, c)
					view = view or {c[1], c[2], c[1], c[2]}
					view = {math.min(view[1], c[1]), math.min(view[2], c[2]),
						math.max(view[3], c[1]), math.max(view[4], c[2])}
				end)
			end
			-- PL: EL JUGADOR QUE JUEGA DESPUES.
			if n.PL then
				local p = (n.PL[1] or ""):upper()
				if p == "B" or p == "W" then
					insert(moves, "{player}{" .. (p == "B" and "black" or "white") .. "}{}")
				end
			end
			if not started then
				-- LAS PIEDRAS INICIALES SON LAS DE LOS NODOS ANTERIORES A LA PRIMERA JUGADA.
				each_point(n, "AE", function(p, c) black, white = without(black, p), without(white, p); put(c, nil) end)
				each_point(n, "AB", function(p, c) white = without(white, p); insert(black, p); put(c, "black") end)
				each_point(n, "AW", function(p, c) black = without(black, p); insert(white, p); put(c, "white") end)
			else
				-- DESPUES, SON EVENTOS ENTRE LAS JUGADAS: PRIMERO SE QUITA (AE) Y DESPUES SE AGREGA.
				each_point(n, "AE", function(p, c) insert(moves, "{remove}" .. p); put(c, nil) end)
				each_point(n, "AB", function(p, c) insert(moves, "{add-black}" .. p); put(c, "black") end)
				each_point(n, "AW", function(p, c) insert(moves, "{add-white}" .. p); put(c, "white") end)
			end
			for _, player in ipairs({{"B", "black"}, {"W", "white"}}) do
				local values = n[player[1]]
				if values then
					started = true
					-- MN CAMBIA EL NUMERO DE ESTA JUGADA (Y LAS SIGUIENTES SIGUEN DESDE AHI).
					local mn = n.MN and tonumber(n.MN[1])
					if mn then
						insert(moves, "{number}{" .. mn .. "}{}")
					end
					local v = values[1] or ""
					-- [] Y, HASTA 19x19, [tt] SON PASES.
					local c = sgf_coords(v, size_y)[1]
					if not c or (v == "tt" and size_x <= 19 and size_y <= 19) then
						insert(moves, "{" .. player[2] .. "}{}{}")
					else
						insert(moves, "{" .. player[2] .. "}" .. point(c[1], c[2]))
						if inside(sim, c[1], c[2]) then play(sim, player[2], c[1], c[2]) end
					end
					count = count + 1
					-- LAS ALTERNATIVAS A ESTA JUGADA, CON LA POSICION DESPUES DE JUGARLA.
					sgf_vars[count] = sgf_vars[count] or {}
					sgf_vars[count].siblings = moves_of(sibs[idx])
				end
			end
			-- LAS JUGADAS QUE PUEDEN SEGUIR (LAS DEL ULTIMO NODO DE LA JUGADA).
			sgf_vars[count] = sgf_vars[count] or {}
			sgf_vars[count].children = moves_of(kids[idx])
			-- FG: UNA FIGURA NUEVA EMPIEZA EN ESTA JUGADA (O EN LA SIGUIENTE, SI EL NODO NO TIENE JUGADA).
			if n.FG then
				local v = n.FG[1] or ""
				local title = v:match("^%d*:(.*)$") or (v:match("^%d*$") and "") or v
				local start = (n.B or n.W) and count or count + 1
				local index = 0
				if title ~= "" then
					insert(sgf_names, title)
					index = #sgf_names
				end
				if sgf_figures[#sgf_figures] and sgf_figures[#sgf_figures][1] == start then
					sgf_figures[#sgf_figures] = {start, index}
				else
					insert(sgf_figures, {start, index})
				end
			end
			for _, prop in ipairs({"N", "TE", "BM", "DO", "IT", "GB", "GW", "DM", "UC"}) do
				local v = n[prop]
				if v then
					local list = sgf_notes[count] or {}
					sgf_notes[count] = list
					if prop == "N" then
						insert(sgf_names, (concat(v, " "):gsub("%s+", " "):match("^%s*(.-)%s*$")))
						insert(list, "{N}{" .. #sgf_names .. "}")
					else
						insert(list, "{" .. prop .. "}{" .. (tonumber(v[1]) == 2 and 2 or 1) .. "}")
					end
				end
			end
			if n.C then
				local text = concat(n.C, " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
				if text ~= "" then
					sgf_comments[count] = sgf_comments[count] and (sgf_comments[count] .. " " .. text) or text
				end
			end
			-- LAS MARCAS SE GUARDAN CON EL COLOR DE LA PIEDRA QUE HAY EN ESE MOMENTO.
			local function mark(kind, c, i)
				local list = sgf_marks[count] or {}
				sgf_marks[count] = list
				insert(list, "{" .. kind .. "}" .. point(c[1], c[2]) .. "{"
					.. (sim.stones[key(c[1], c[2])] or "neutral") .. "}{" .. (i or "") .. "}")
			end
			for _, m in ipairs(markup) do
				each_point(n, m[1], function(p, c) mark(m[2], c) end)
			end
			for _, v in ipairs(n.LB or {}) do
				local where, text = v:match("^(%a%a):(.*)$")
				if where then
					insert(sgf_labels, text)
					for _, c in ipairs(sgf_coords(where, size_y)) do mark("label", c, #sgf_labels) end
				end
			end
			-- DD REEMPLAZA LOS PUNTOS ATENUADOS (DD[] LOS QUITA); SIN DD, SIGUEN LOS DEL NODO ANTERIOR.
			if n.DD then
				dim = {}
				each_point(n, "DD", function(p) insert(dim, p) end)
			end
			sgf_dim[count] = dim
			for _, kind in ipairs({{"AR", "arrow"}, {"LN", "line"}}) do
				for _, v in ipairs(n[kind[1]] or {}) do
					local a, b = v:match("^(%a%a):(%a%a)$")
					local p, q = a and sgf_coords(a, size_y)[1], b and sgf_coords(b, size_y)[1]
					if p and q then
						local list = sgf_lines[count] or {}
						sgf_lines[count] = list
						insert(list, "{" .. kind[2] .. "}" .. point(p[1], p[2]) .. point(q[1], q[2]))
					end
				end
			end
		end
	end
	local figures = {}
	for _, f in ipairs(sgf_figures) do insert(figures, "{" .. f[1] .. "}{" .. f[2] .. "}") end
	token.set_macro("l__pgfgo_kernel_sgf_figures_clist", concat(figures, ","))
	token.set_macro("l_pgfgo_kernel_sgf_view_tl", view and
		(point(view[1], view[2]) .. point(view[3], view[4])) or "")
	tex.setcount("l_pgfgo_kernel_sgf_size_x_int", size_x)
	tex.setcount("l_pgfgo_kernel_sgf_size_y_int", size_y)
	token.set_macro("l__pgfgo_kernel_sgf_black_clist", concat(black, ","))
	token.set_macro("l__pgfgo_kernel_sgf_white_clist", concat(white, ","))
	token.set_macro("l__pgfgo_kernel_sgf_moves_clist", concat(moves, ","))
end

-- PROPIEDAD DE LA RAIZ DE LA PARTIDA (PB, PW, RE, KM, DT, ...), COMO TEXTO. VARIOS VALORES SE SEPARAN
-- CON COMAS.
function pgfgo.sgf_info(name, property)
	local t = read_tree(name)
	local root = t and t.nodes[1] or {}
	tex.sprint(-2, concat(root[property] or {}, ", "))
end


---------------------------------------------------------------------------------------------------
-- TERRITORIO
---------------------------------------------------------------------------------------------------

-- text: LAS PIEDRAS VIVAS, {x}{y}{black | white}. CADA REGION DE PUNTOS SIN PIEDRAS VIVAS (VACIOS O CON
-- PIEDRAS MUERTAS) ES DEL COLOR QUE LA RODEA; SI LA TOCAN LOS DOS COLORES, O NINGUNO, ES neutral.
function pgfgo.territory(text)
	local b = {stones = {}, sx = count("l_pgfgo_goban_size_x_int"), sy = count("l_pgfgo_goban_size_y_int")}
	for x, y, c in text:gmatch("{(%d+)}{(%d+)}{(%a+)}") do
		b.stones[key(tonumber(x), tonumber(y))] = c
	end
	local owner, list = {}, {}
	for y = 1, b.sy do
		for x = 1, b.sx do
			local k = key(x, y)
			if not b.stones[k] and not owner[k] then
				local region, touches, pending = {}, {}, {{x, y}}
				owner[k] = true
				while #pending > 0 do
					local p = table.remove(pending)
					insert(region, p)
					for _, n in ipairs(neighbours(b, p[1], p[2])) do
						local nk = key(n[1], n[2])
						local c = b.stones[nk]
						if c then
							touches[c] = true
						elseif not owner[nk] then
							owner[nk] = true
							insert(pending, n)
						end
					end
				end
				local o = "neutral"
				if touches.black and not touches.white then o = "black" end
				if touches.white and not touches.black then o = "white" end
				for _, p in ipairs(region) do owner[key(p[1], p[2])] = o end
			end
		end
	end
	for y = 1, b.sy do
		for x = 1, b.sx do
			local o = owner[key(x, y)]
			if type(o) == "string" then insert(list, point(x, y) .. "{" .. o .. "}") end
		end
	end
	token.set_macro("l__pgfgo_kernel_territory_clist", concat(list, ","))
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
