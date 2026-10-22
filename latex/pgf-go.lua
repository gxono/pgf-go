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

-- RESPUESTA DE UN CONDICIONAL DE expl3.
local function prg_return(ok)
	tex_code(ok and "\\prg_return_true:" or "\\prg_return_false:")
end

-- DEJA LOS ELEMENTOS DE list, SEPARADOS POR COMAS, EN LA VARIABLE name DE TeX.
local function set_clist(name, list)
	token.set_macro(name, concat(list, ","))
end

local function goban_size()
	return count("l_pgfgo_goban_size_x_int"), count("l_pgfgo_goban_size_y_int")
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
	local sx, sy = goban_size()
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
	local sx, sy = goban_size()
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
	set_clist("l__pgfgo_kernel_points_clist", list)
end

local function window()
	return count("l_pgfgo_goban_from_x_int"), count("l_pgfgo_goban_to_x_int"),
		count("l_pgfgo_goban_from_y_int"), count("l_pgfgo_goban_to_y_int")
end

function pgfgo.if_visible(x, y)
	local sx, sy = goban_size()
	if x >= 1 and x <= sx and y >= 1 and y <= sy then
		local fx, tx, fy, ty = window()
		prg_return(x >= fx and x <= tx and y >= fy and y <= ty)
	else
		message("warning", "outside-board", x, y)
		prg_return(false)
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

-- PASO PARA IR DE a A b (1 SI SON IGUALES).
local function step(a, b)
	return a <= b and 1 or -1
end

-- A1 -- E6, A1 -|- E6 Y A1 |-| E6 (mode: "--", "-|" O "|-"), EN EL ORDEN DEL CAMINO. EL EJE LARGO AVANZA
-- DE A UNA; EN EL CORTO, LA POSICION MAS CERCANA A LA RECTA. EN UN EMPATE GANA LA DEL LADO DEL EXTREMO MAS
-- CERCANO, Y EN EL MEDIO EXACTO, LA MENOR. EN CADA ESCALON, -| Y |- PONEN ANTES SU ESQUINA. LA MISMA CUENTA
-- ESTA EN pgf-go-coordinate-parser.sty (\__pgfgo_coordinate_stairs:nnnnn).
local function stairs(out, mode, x1, y1, x2, y2)
	local dx, dy = x2 - x1, y2 - y1
	local n = math.max(math.abs(dx), math.abs(dy))
	if n == 0 then
		out(x1, y1)
		return
	end
	local function offset(d, i)
		local a = math.abs(d) * i
		local base = a // n
		local rest = 2 * (a - base * n)
		if rest > n or (rest == n and (2 * i > n or (2 * i == n and d < 0))) then
			base = base + 1
		end
		return (d < 0 and -1 or 1) * base
	end
	local px, py
	for i = 0, n do
		local x, y
		if math.abs(dy) < math.abs(dx) then
			x, y = x1 + (dx < 0 and -i or i), y1 + offset(dy, i)
		else
			x, y = x1 + offset(dx, i), y1 + (dy < 0 and -i or i)
		end
		if px and x ~= px and y ~= py then
			if mode == "-|" then
				out(x, py)
			elseif mode == "|-" then
				out(px, y)
			end
		end
		out(x, y)
		px, py = x, y
	end
end

-- RECTANGULO DE ESQUINAS (x1,y1) Y (x2,y2), COLUMNA POR COLUMNA DESDE x1 Y CADA COLUMNA DESDE y1: EMPIEZA
-- EN LA PRIMERA ESQUINA Y TERMINA EN LA SEGUNDA. TIENE UN ORDEN SOLO SI ES UNA LINEA (O UN PUNTO).
local function rectangle(out, x1, y1, x2, y2)
	for x = x1, x2, step(x1, x2) do
		for y = y1, y2, step(y1, y2) do out(x, y) end
	end
	return x1 == x2 or y1 == y2
end

-- LOS OPERADORES DE CADENA, DE (x1,y1) A (x2,y2), CON LOS DOS EXTREMOS. DEVUELVEN SI TIENEN UN ORDEN.
local links = {
	["--"] = function(out, x1, y1, x2, y2)
		stairs(out, "--", x1, y1, x2, y2)
		return true
	end,
	["-|-"] = function(out, x1, y1, x2, y2)
		stairs(out, "-|", x1, y1, x2, y2)
		return true
	end,
	["|-|"] = function(out, x1, y1, x2, y2)
		stairs(out, "|-", x1, y1, x2, y2)
		return true
	end,
	["-|"] = function(out, x1, y1, x2, y2)
		for x = x1, x2, step(x1, x2) do out(x, y1) end
		for y = y1 + step(y1, y2), y2, step(y1, y2) do out(x2, y) end
		return true
	end,
	["|-"] = function(out, x1, y1, x2, y2)
		for y = y1, y2, step(y1, y2) do out(x1, y) end
		for x = x1 + step(x1, x2), x2, step(x1, x2) do out(x, y2) end
		return true
	end,
	-- EL CONTORNO, UNA VUELTA DESDE (x1,y1): PRIMERO HORIZONTAL HASTA x2.
	r = function(out, x1, y1, x2, y2)
		if x1 == x2 or y1 == y2 then
			rectangle(out, x1, y1, x2, y2)
			return false
		end
		local sx, sy = step(x1, x2), step(y1, y2)
		for x = x1, x2, sx do out(x, y1) end
		for y = y1 + sy, y2, sy do out(x2, y) end
		for x = x2 - sx, x1, -sx do out(x, y2) end
		for y = y2 - sy, y1 + sy, -sy do out(x1, y) end
		return false
	end,
}

-- LOS TRAMOS QUE SE ENCADENAN (A3, A:C 3, C 1:3, A1:C3) SON RECTANGULOS: DEVUELVEN SUS DOS ESQUINAS.
-- c ES LA COLUMNA (LETRA -> NUMERO).
local pieces = {
	{"^([A-Z])(%d%d?)$", function(c, l, n)
		return c(l), tonumber(n), c(l), tonumber(n)
	end},
	{"^([A-Z]):([A-Z])%s*(%d%d?)$", function(c, l1, l2, n)
		return c(l1), tonumber(n), c(l2), tonumber(n)
	end},
	{"^([A-Z])%s*(%d%d?):(%d%d?)$", function(c, l, n1, n2)
		return c(l), tonumber(n1), c(l), tonumber(n2)
	end},
	{"^([A-Z])(%d%d?):([A-Z])(%d%d?)$", function(c, l1, n1, l2, n2)
		return c(l1), tonumber(n1), c(l2), tonumber(n2)
	end},
}

local function piece(s, c)
	for _, rule in ipairs(pieces) do
		local captures = {s:match(rule[1])}
		if captures[1] then
			return {rule[2](c, table.unpack(captures))}
		end
	end
end

-- LO QUE NO SE ENCADENA NI TIENE UN ORDEN: RECTANGULOS DE RANGOS, COLUMNAS Y FILAS ENTERAS Y *. w ES LA
-- PARTE VISIBLE.
local regions = {
	{"^([A-Z]):([A-Z])%s*(%d%d?):(%d%d?)$", function(out, c, w, l1, l2, n1, n2)
		return rectangle(out, c(l1), tonumber(n1), c(l2), tonumber(n2))
	end},
	{"^([A-Z])$", function(out, c, w, l)
		rectangle(out, c(l), w.fy, c(l), w.ty)
	end},
	{"^(%d%d?)$", function(out, c, w, n)
		rectangle(out, w.fx, tonumber(n), w.tx, tonumber(n))
	end},
	{"^([A-Z]):([A-Z])$", function(out, c, w, l1, l2)
		rectangle(out, c(l1), w.fy, c(l2), w.ty)
	end},
	{"^(%d%d?):(%d%d?)$", function(out, c, w, n1, n2)
		rectangle(out, w.fx, tonumber(n1), w.tx, tonumber(n2))
	end},
	{"^%*$", function(out, c, w)
		rectangle(out, w.fx, w.fy, w.tx, w.ty)
	end},
}

-- PARTE A1 -| C3 -- E3 EN {"A1", "-|", "C3", "--", "E3"}. EN CADA LUGAR SE PRUEBAN LOS OPERADORES EN ESTE
-- ORDEN, COMO LA EXPRESION REGULAR DEL KERNEL expl3.
local operators = {"-|-", "|-|", "--", "-|", "|-", "r"}

local function split_chain(s)
	local parts, i, start = {}, 1, 1
	while i <= #s do
		local found
		for _, op in ipairs(operators) do
			if s:sub(i, i + #op - 1) == op then
				found = op
				break
			end
		end
		if found then
			insert(parts, s:sub(start, i - 1):match("^%s*(.-)%s*$"))
			insert(parts, found)
			i = i + #found
			start = i
		else
			i = i + 1
		end
	end
	insert(parts, s:sub(start):match("^%s*(.-)%s*$"))
	return parts
end

-- UN ELEMENTO (LO QUE ESTA ENTRE DOS COMAS): DEJA SUS INTERSECCIONES EN out, EN ORDEN, Y DEVUELVE SI TIENE
-- UN ORDEN FIJO. EN UNA CADENA CADA OPERADOR VA DEL ULTIMO PUNTO DE UN TRAMO AL PRIMERO DEL SIGUIENTE, Y
-- EL PUNTO QUE COMPARTEN VA UNA SOLA VEZ. SI NO SE RECONOCE, AVISA Y NO DEJA NADA.
local function expand_item(item, c, w, out)
	local parts = split_chain(item)
	local corners = {}
	for k = 1, #parts, 2 do
		corners[k] = piece(parts[k], c)
		if not corners[k] then
			corners = nil
			break
		end
	end
	if not corners then
		if #parts == 1 then
			for _, rule in ipairs(regions) do
				local captures = {item:match(rule[1])}
				if captures[1] then
					return rule[2](out, c, w, table.unpack(captures)) or false
				end
			end
		end
		message("warning", "unknown-coordinate", item)
		return true
	end
	local skip = false
	local function put(x, y)
		if skip then
			skip = false
		else
			out(x, y)
		end
	end
	local ordered = rectangle(put, table.unpack(corners[1]))
	for k = 2, #parts, 2 do
		local from, to = corners[k - 1], corners[k + 1]
		skip = true
		ordered = links[parts[k]](put, from[3], from[4], to[1], to[2]) and ordered
		skip = true
		ordered = rectangle(put, table.unpack(to)) and ordered
	end
	return ordered
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

-- LOS CORCHETES SE REPARTEN EN SU LUGAR: A[1:3, 5] ES A1:3, A5; [A, C:D]2 ES A2, C:D2; [A, B][1, 2] ES
-- A1, A2, B1, B2. ASI CONSERVAN SU ORDEN Y PUEDEN SER TRAMOS DE UNA CADENA.
local function expand_brackets(group)
	local function join(list)
		return concat(list, ", ")
	end
	group = group:gsub("%[([^%]]*)%]%[([^%]]*)%]", function(letters, numbers)
		local out = {}
		for _, l in ipairs(clist(letters)) do
			for _, n in ipairs(clist(numbers)) do insert(out, l .. n) end
		end
		return join(out)
	end)
	group = group:gsub("([A-Z])%[([^%]]*)%]", function(l, numbers)
		local out = {}
		for _, n in ipairs(clist(numbers)) do insert(out, l .. n) end
		return join(out)
	end)
	group = group:gsub("%[([^%]]*)%](%d%d?)", function(letters, n)
		local out = {}
		for _, l in ipairs(clist(letters)) do insert(out, l .. n) end
		return join(out)
	end)
	return group
end

local function column_function(use_i)
	return function(letter)
		return column_number(letter, use_i)
	end
end

-- LAS INTERSECCIONES DE UN GRUPO (LO QUE ESTA ENTRE DOS ;), EN ORDEN Y CON REPETICIONES, Y SI TODOS SUS
-- ELEMENTOS TIENEN UN ORDEN FIJO.
local function expand_group(group, use_i)
	local fx, tx, fy, ty = window()
	local w = {fx = fx, tx = tx, fy = fy, ty = ty}
	local c = column_function(use_i)
	local list, ordered = {}, true
	local function out(x, y)
		insert(list, point(x, y))
	end
	for _, item in ipairs(clist(expand_brackets(group))) do
		ordered = expand_item(item, c, w, out) and ordered
	end
	return list, ordered
end

local function set_ordered(ordered)
	tex_code("\\bool_set_" .. (ordered and "true" or "false") .. ":N\\l_pgfgo_kernel_points_ordered_bool")
end

-- TODA LA SINTAXIS DE \stones: LOS GRUPOS SEPARADOS POR ; SE SUMAN Y SE RESTAN ALTERNADAMENTE. EL ORDEN
-- ES EL DE LOS GRUPOS QUE SUMAN.
function pgfgo.points(spec, use_i)
	local list, seen = {}, {}
	local add, ordered = true, true
	for group in (spec .. ";"):gmatch("([^;]*);") do
		local items, group_ordered = expand_group(group, use_i)
		if add then
			for _, item in ipairs(items) do add_unique(list, seen, item) end
			ordered = ordered and group_ordered
		else
			local removed = {}
			for _, item in ipairs(items) do removed[item] = true end
			local kept = {}
			seen = {}
			for _, item in ipairs(list) do
				if not removed[item] then add_unique(kept, seen, item) end
			end
			list = kept
		end
		add = not add
	end
	set_clist("l__pgfgo_kernel_points_clist", list)
	set_ordered(ordered)
end

-- LAS JUGADAS DE \moves: UN SOLO GRUPO, EN ORDEN Y CON REPETICIONES.
function pgfgo.moves(spec, use_i)
	local list, ordered = expand_group(spec, use_i)
	set_clist("l__pgfgo_kernel_points_clist", list)
	set_ordered(ordered)
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
	local n, odd = #v, false
	for i = 1, n do
		local a, b = v[i], v[i % n + 1]
		if on_segment(px, py, a, b) then return true end
		if (a[2] > py) ~= (b[2] > py) then
			-- px < x DEL CRUCE, MULTIPLICANDO POR dy (CON SU SIGNO).
			local dy = b[2] - a[2]
			local lhs = (px - a[1]) * dy
			local rhs = (py - a[2]) * (b[1] - a[1])
			if (dy > 0 and lhs < rhs) or (dy < 0 and lhs > rhs) then
				odd = not odd
			end
		end
	end
	return odd
end

function pgfgo.polygon(text)
	local v = {}
	for x, y in text:gmatch("{(%-?%d+)}{(%-?%d+)}") do
		insert(v, {tonumber(x), tonumber(y)})
	end
	local list = {}
	if #v > 0 then
		local sx, sy = goban_size()
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
	set_clist("l__pgfgo_kernel_points_clist", list)
end

function pgfgo.point(spec, use_i)
	local l, n = spec:match("^([A-Z])(%d%d?)$")
	if l then
		token.set_macro("l_pgfgo_kernel_point_tl", point(column_number(l, use_i), n))
	end
	prg_return(l)
end


---------------------------------------------------------------------------------------------------
-- PIEDRAS EN EL TABLERO (CAPTURAS)
---------------------------------------------------------------------------------------------------

-- CLAVE DE UNA INTERSECCION EN LAS TABLAS (UN ENTERO; x E y PUEDEN SER NEGATIVOS O PASARSE DEL TABLERO).
local function key(x, y)
	return y * 0x100000 + x
end

-- UN TABLERO ES {stones = {[key(x, y)] = "black" | "white"}, sx = ancho, sy = alto}. EL DEL goban LEE
-- SU TAMANO DE TeX; LA LECTURA DE UN SGF USA OTRO PARA SIMULAR LA PARTIDA.
local stones = {}

local function goban_board()
	local sx, sy = goban_size()
	return {stones = stones, sx = sx, sy = sy}
end

local function inside(b, x, y)
	return x and y and x >= 1 and y >= 1 and x <= b.sx and y <= b.sy
end

local function on_board(x, y)
	return inside(goban_board(), x, y)
end

-- OESTE, ESTE, SUR, NORTE (EL ORDEN DECIDE EL DE LAS PIEDRAS CAPTURADAS).
local directions = {{-1, 0}, {1, 0}, {0, -1}, {0, 1}}

local function neighbours(b, x, y)
	local list = {}
	for _, d in ipairs(directions) do
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
		local k = key(p[1], p[2])
		local color = b.stones[k]
		removed[color] = (removed[color] or 0) + 1
		b.stones[k] = nil
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
	prg_return(on_board(x, y) and stones[key(x, y)])
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
	set_clist("l__pgfgo_kernel_captured_clist", captured)
	move_number = move_number + 1
	black_turn = not black_turn
end

-- COPIAS CON NOMBRE DEL TABLERO, LOS PRISIONEROS, EL NUMERO Y EL TURNO (PARA SEGUIR UNA PARTIDA DESDE
-- DONDE QUEDO, SIN VOLVER A JUGARLA).
local saved_boards = {}

local function copy(t)
	local c = {}
	for k, v in pairs(t) do
		c[k] = v
	end
	return c
end

function pgfgo.board_save(name)
	saved_boards[name] = {copy(stones), copy(prisoners), move_number, black_turn}
end

function pgfgo.board_restore(name)
	local s = saved_boards[name]
	if s then
		stones, prisoners, move_number, black_turn = copy(s[1]), copy(s[2]), s[3], s[4]
	end
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
		-- i ESTA EN [. \ ESCAPA EL CARACTER QUE SIGUE: \] NO CIERRA EL VALOR. SE SALTA DE UNA \ O ] A LA
		-- SIGUIENTE.
		local out = {}
		i = i + 1
		while true do
			local j = s:find("[\\%]]", i)
			if not j then
				insert(out, s:sub(i))
				i = #s + 1
				break
			end
			insert(out, s:sub(i, j - 1))
			if s:byte(j) == 93 then
				i = j + 1
				break
			end
			insert(out, s:sub(j + 1, j + 1))
			i = j + 2
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
			elseif c:match("%a") then
				-- UN NODO SIN ; (LA RAIZ DE ALGUNOS ARCHIVOS VIEJOS: "(SZ[19]...").
				insert(t.nodes, node())
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
		local x1, x2 = sgf_number(a:sub(1, 1)), sgf_number(b:sub(1, 1))
		local y1, y2 = sgf_number(a:sub(2, 2)), sgf_number(b:sub(2, 2))
		-- EN ORDEN CRECIENTE, SIN IMPORTAR CUAL ESQUINA VIENE PRIMERO.
		for x = math.min(x1, x2), math.max(x1, x2) do
			for y = math.min(y1, y2), math.max(y1, y2) do
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

-- CODIFICACIONES. UN ARCHIVO QUE ES UTF-8 VALIDO SE LEE COMO UTF-8. SI NO, SE USA LA CODIFICACION QUE PIDE
-- \l_pgfgo_kernel_sgf_charset_tl O, CON auto, LA DE CA; SIN NINGUNA, Latin-1 (LA DE SGF POR DEFECTO).
-- GBK, Big5, Shift_JIS, EUC-JP Y EUC-KR SE CONVIERTEN CON LAS TABLAS DE pgf-go-charsets.lua. UNA
-- CODIFICACION DESCONOCIDA PRODUCE UN AVISO (Y SE LEE COMO Latin-1). UTF-16 CON BOM SE PASA A UTF-8 AL
-- LEER EL ARCHIVO. LOS NOMBRES SE COMPARAN SIN
-- MAYUSCULAS NI SIGNOS (Shift_JIS ES shiftjis).
local charset_kinds = {
	utf8 = "utf8", utf16 = "utf8", utf16le = "utf8", utf16be = "utf8", iso88591 = "latin", iso885915 = "latin", latin1 = "latin", windows1252 = "latin",
	cp1252 = "latin", ascii = "latin", usascii = "latin",
	gbk = "gbk", gb2312 = "gbk", gb18030 = "gbk", cp936 = "gbk", windows936 = "gbk", euccn = "gbk",
	big5 = "big5", big5hkscs = "big5", cp950 = "big5", windows950 = "big5",
	shiftjis = "sjis", sjis = "sjis", xsjis = "sjis", cp932 = "sjis", windows31j = "sjis", mskanji = "sjis",
	eucjp = "eucjp",
	euckr = "euckr", cp949 = "euckr", windows949 = "euckr", uhc = "euckr", ksc5601 = "euckr",
	ksc56011987 = "euckr",
}

local function charset_kind(text)
	return charset_kinds[text:lower():gsub("[^%w]", "")]
end

-- EL ARCHIVO DE LAS TABLAS LO BUSCA pgf-go-kernel-lua.sty (pgfgo.charsets_file).
local charset_tables

local function charset_table(kind)
	if not charset_tables then
		local file = pgfgo.charsets_file
		if not file or file == "" then
			file = kpse.find_file("pgf-go-charsets.lua", "lua") or kpse.find_file("pgf-go-charsets.lua", "tex")
		end
		charset_tables = file and dofile(file) or {}
	end
	return charset_tables[kind] or {}
end

-- EUC-JP Y Shift_JIS CODIFICAN LOS MISMOS CARACTERES (JIS X 0208): EL PAR DE EUC-JP SE PASA A Shift_JIS.
local function euc_to_sjis(c1, c2)
	local j1, j2 = c1 - 0x80, c2 - 0x80
	local s1 = (j1 + 1) // 2 + (j1 <= 0x5E and 0x70 or 0xB0)
	local s2 = j1 % 2 == 1 and j2 + (j2 >= 0x60 and 0x20 or 0x1F) or j2 + 0x7E
	return s1, s2
end

local replacement = utf8.char(0xFFFD)

local function decode(kind, s)
	local table_ = charset_table(kind == "eucjp" and "sjis" or kind)
	local rows = {}
	-- EL CARACTER DEL PAR (lead, trail), O nil.
	local function pair(lead, trail)
		if not trail or trail < 0x40 or trail > 0xFE then return nil end
		local row = rows[lead]
		if not row then
			row = {}
			for _, c in utf8.codes(table_[lead] or "") do insert(row, utf8.char(c)) end
			rows[lead] = row
		end
		local c = row[trail - 0x3F]
		return c ~= replacement and c or nil
	end
	local out, i, n = {}, 1, #s
	while i <= n do
		-- LO QUE ES ASCII PASA TAL CUAL.
		local j = s:find("[\128-\255]", i) or n + 1
		if j > i then
			insert(out, s:sub(i, j - 1))
			i = j
		end
		if i > n then break end
		local b, b2 = s:byte(i), s:byte(i + 1)
		local c, size = nil, 1
		if kind == "sjis" and b >= 0xA1 and b <= 0xDF then
			-- KATAKANA DE MEDIO ANCHO.
			c = utf8.char(0xFF61 + b - 0xA1)
		elseif kind == "eucjp" and b == 0x8E then
			size = 2
			c = b2 and b2 >= 0xA1 and b2 <= 0xDF and utf8.char(0xFF61 + b2 - 0xA1) or nil
		elseif kind == "eucjp" and b == 0x8F then
			-- JIS X 0212 (TRES BYTES): NO SE CONVIERTE.
			size = 3
		elseif kind == "gbk" and b2 and b2 >= 0x30 and b2 <= 0x39 then
			-- LA PARTE DE CUATRO BYTES DE GB18030: NO SE CONVIERTE.
			size = 4
		elseif kind == "eucjp" then
			if b2 and b >= 0xA1 and b <= 0xFE and b2 >= 0xA1 and b2 <= 0xFE then
				c = pair(euc_to_sjis(b, b2))
				size = 2
			end
		else
			c = pair(b, b2)
			-- UN PAR QUE NO EXISTE SE SALTEA ENTERO, SALVO QUE EL SEGUNDO BYTE SEA ASCII (COMO ] O \).
			size = (c or (b2 and b2 >= 0x80)) and 2 or 1
		end
		insert(out, c or replacement)
		i = i + size
	end
	return concat(out)
end

-- UN TEXTO EN UTF-16 CON BOM (FF FE: LITTLE ENDIAN; FE FF: BIG ENDIAN), PASADO A UTF-8. UN SUSTITUTO
-- SUELTO ES U+FFFD.
local function from_utf16(s)
	local big = s:byte(1) == 0xFE
	local function unit(i)
		local a, b = s:byte(i, i + 1)
		return big and a * 256 + b or b * 256 + a
	end
	local out, i, n = {}, 3, #s
	while i < n do
		local c = unit(i)
		i = i + 2
		if c >= 0xD800 and c <= 0xDBFF and i < n then
			local c2 = unit(i)
			if c2 >= 0xDC00 and c2 <= 0xDFFF then
				c = 0x10000 + (c - 0xD800) * 0x400 + (c2 - 0xDC00)
				i = i + 2
			end
		end
		insert(out, (c >= 0xD800 and c <= 0xDFFF) and replacement or utf8.char(c))
	end
	return concat(out)
end

-- ARCHIVOS SGF YA LEIDOS, POR RUTA (UN DOCUMENTO SUELE LEER MUCHAS VECES EL MISMO ARCHIVO): {stamp =
-- FECHA Y TAMANO, text = CONTENIDO, ca = VALOR DE CA, utf8 = SI ES UTF-8 VALIDO, games = {[CODIFICACION] =
-- PARTIDAS}}. SI EL ARCHIVO CAMBIA, SE VUELVE A LEER.
local sgf_files = {}

local function sgf_file(path)
	local attributes = lfs.attributes(path)
	local stamp = attributes and (attributes.modification .. ":" .. attributes.size)
	local file = sgf_files[path]
	if not (file and stamp and file.stamp == stamp) then
		local f = io.open(path, "rb")
		local s = f:read("a")
		f:close()
		local bom = s:sub(1, 2)
		if bom == "\255\254" or bom == "\254\255" then
			s = from_utf16(s)
		end
		file = {stamp = stamp, text = s, ca = s:match("CA%s*%[([^%]]*)%]"), utf8 = utf8.len(s) ~= nil, games = {}}
		sgf_files[path] = file
	end
	return file
end

-- LAS PARTIDAS DE UN ARCHIVO, CON SU TEXTO PASADO A UTF-8. AVISA SI LA CODIFICACION ES DESCONOCIDA.
local function sgf_games(name, path)
	local file = sgf_file(path)
	local forced = token.get_macro("l_pgfgo_kernel_sgf_charset_tl") or "auto"
	local wanted = (forced ~= "auto" and forced ~= "") and forced or file.ca
	local kind = wanted and charset_kind(wanted)
	if wanted and not kind then
		message("warning", "sgf-charset", name, wanted)
	end
	if file.utf8 then
		kind = "utf8"
	elseif not kind or kind == "utf8" then
		kind = "latin"
	end
	local games = file.games[kind]
	if not games then
		local s = file.text
		-- SIN UNA CODIFICACION QUE SIRVA, CUATRO BYTES ALTOS SEGUIDOS NO PARECEN Latin-1 (DONDE LAS LETRAS
		-- CON ACENTO VAN SUELTAS) SINO UNA CODIFICACION DE DOS BYTES (GBK, Shift_JIS...): SE AVISA.
		if kind == "latin" and (not wanted or charset_kind(wanted) == "utf8")
				and s:find("[\128-\255][\128-\255][\128-\255][\128-\255]") then
			message("warning", "sgf-guess-charset", name)
		end
		if kind == "latin" then
			s = s:gsub("[\128-\255]", function(c) return utf8.char(c:byte()) end)
		elseif kind ~= "utf8" then
			s = decode(kind, s)
		end
		games = parse_sgf(s)
		file.games[kind] = games
	end
	return games
end

-- LA PARTIDA \l_pgfgo_kernel_sgf_game_int DEL ARCHIVO. AVISA SI NO EXISTE Y USA LA PRIMERA.
local function read_tree(name)
	--EL NOMBRE LLEGA COMO LO DEJA \text_expand:n: \& \# \% \{ \} \_ TAL CUAL Y \$ COMO \protect \$.
	name = name:gsub("\\protect ", ""):gsub("\\([&#%%$_{}])", "%1")
	local path = find_file(name)
	if not path then
		message("error", "sgf-not-found", name)
		return nil
	end
	local games = sgf_games(name, path)
	local n = count("l_pgfgo_kernel_sgf_game_int")
	if not games[n] then
		if n ~= 1 then message("warning", "sgf-game", name, n) end
		n = 1
	end
	return games[n] or {nodes = {}, children = {}}
end

-- DATOS DE LA ULTIMA PARTIDA LEIDA, POR JUGADA k (0: LOS NODOS ANTERIORES A LA PRIMERA JUGADA). UN NODO
-- SIN JUGADA SE SUMA A LA JUGADA ANTERIOR.
-- sgf_comments[k]: COMENTARIOS (C), UNO POR NODO, TAL CUAL. sgf_marks[k]: MARCAS (TR, SQ, CR, MA, LB) Y TERRITORIO (TB, TW),
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
-- sgf_views: LAS VISTAS (VW), {start = jugada desde la que vale, rect = {x1, y1, x2, y2} O nil (TODO EL TABLERO)}.
local sgf_vars, sgf_style, sgf_figures, sgf_views = {}, 0, {}, {}

-- SIN EL CHAT DE LOS SERVIDORES: EN OGS, LO QUE SIGUE A UNA LINEA "-- chat --"; EN KGS, LAS LINEAS
-- "nombre [rango]: ..." Y, SI HABIA ALGUNA, TAMBIEN LAS "nombre: ..." (LOS QUE NO TIENEN RANGO).
local function without_chat(text)
	local kept, ranked = {}, false
	for line in (text .. "\n"):gmatch("(.-)\n") do
		if line:match("^%s*%-%- chat %-%-%s*$") then break end
		if line:match("^%s*[%w_]+ %[[%w%?%-]+%]: ") then
			ranked = true
		else
			insert(kept, line)
		end
	end
	if ranked then
		local rest = {}
		for _, line in ipairs(kept) do
			if not line:match("^%s*[%w_]+: ") then insert(rest, line) end
		end
		kept = rest
	end
	return concat(kept, "\n")
end

-- EL COMENTARIO DE LA JUGADA k (LOS DE SUS NODOS, SEGUIDOS), EN UNA LINEA. chat: false LE QUITA EL CHAT.
function pgfgo.sgf_comment(k, chat)
	local texts = {}
	for _, raw in ipairs(sgf_comments[k] or {}) do
		local text = (chat == false and without_chat(raw) or raw):gsub("%s+", " "):match("^%s*(.-)%s*$")
		if text ~= "" then insert(texts, text) end
	end
	tex.sprint(-2, concat(texts, " "))
end

-- PRIMERO LOS PUNTOS ATENUADOS, PARA QUE LAS DEMAS MARCAS QUEDEN ENCIMA.
function pgfgo.sgf_marks(k)
	local list = {}
	for _, p in ipairs(sgf_dim[k] or {}) do insert(list, "{dim}" .. p .. "{neutral}{}") end
	for _, m in ipairs(sgf_marks[k] or {}) do insert(list, m) end
	set_clist("l__pgfgo_kernel_sgf_marks_clist", list)
end

function pgfgo.sgf_annotations(k)
	set_clist("l__pgfgo_kernel_sgf_annotations_clist", sgf_notes[k] or {})
end

-- AVISA SI LA FUENTE ACTUAL NO TIENE ALGUN CARACTER CJK DE text (UNA VEZ POR FUENTE). SE LLAMA AL ESCRIBIR
-- UN TEXTO DEL ARCHIVO, CUANDO YA ESTA ELEGIDA LA FUENTE CON LA QUE SE ESCRIBE.
local glyphs_warned = {}
local function cjk(c)
	return (c >= 0x2E80 and c <= 0x9FFF) or (c >= 0xAC00 and c <= 0xD7AF) or (c >= 0xF900 and c <= 0xFAFF)
		or (c >= 0xFF00 and c <= 0xFFEF) or (c >= 0x20000 and c <= 0x2FFFF)
end
function pgfgo.sgf_glyphs(text)
	local id = font.current()
	local hashes = fonts and fonts.hashes and fonts.hashes.identifiers
	local f = (hashes and hashes[id]) or font.getfont(id)
	if not f or not f.characters then return end
	local name = (f.properties and f.properties.fullname) or f.fullname or f.name or tostring(id)
	if glyphs_warned[name] then return end
	pcall(function()
		for _, c in utf8.codes(text) do
			if cjk(c) and not f.characters[c] then
				glyphs_warned[name] = true
				message("warning", "sgf-glyphs", name, string.format("U+%04X", c))
				return
			end
		end
	end)
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
	set_clist("l__pgfgo_kernel_sgf_variations_clist", list)
end

function pgfgo.sgf_lines(k)
	set_clist("l__pgfgo_kernel_sgf_lines_clist", sgf_lines[k] or {})
end

function pgfgo.sgf_label(i)
	tex.sprint(-2, sgf_labels[i] or "")
end

-- LA VISTA QUE ABARCA LAS DE LAS JUGADAS k1 A k2 (EL RECTANGULO QUE LAS CONTIENE). VACIA SI EN ALGUNA DE
-- ESAS JUGADAS SE VE TODO EL TABLERO. LA JUGADA 0 TIENE LA VISTA DE LA 1.
local function view_text(rect)
	return rect and (point(rect[1], rect[2]) .. point(rect[3], rect[4])) or ""
end

local function views_between(k1, k2)
	k1 = math.max(k1, 1)
	k2 = math.max(k2, k1)
	local rect
	-- ANTES DE LA PRIMERA VISTA SE VE TODO EL TABLERO.
	if not sgf_views[1] or sgf_views[1].start > k1 then return nil end
	for i, v in ipairs(sgf_views) do
		local last = sgf_views[i + 1] and sgf_views[i + 1].start - 1 or math.huge
		if v.start <= k2 and last >= k1 then
			if not v.rect then return nil end
			rect = rect and {math.min(rect[1], v.rect[1]), math.min(rect[2], v.rect[2]),
				math.max(rect[3], v.rect[3]), math.max(rect[4], v.rect[4])} or v.rect
		end
	end
	return rect
end

function pgfgo.sgf_view(k1, k2)
	token.set_macro("l_pgfgo_kernel_sgf_view_tl", view_text(views_between(k1, k2)))
end

-- TAMANO DE UNA PARTIDA (SZ DE LA RAIZ; 19 SI NO ESTA).
local function sgf_size(root)
	local size_x, size_y = 19, 19
	if root and root.SZ then
		local x, y = root.SZ[1]:match("^%s*(%d+)%s*:%s*(%d+)%s*$")
		size_x = tonumber(x or root.SZ[1]) or 19
		size_y = tonumber(y or root.SZ[1]) or 19
	end
	return size_x, size_y
end

-- TODAS LAS LINEAS DE LA PARTIDA, COMO VARIANTES ("2.1"; LA UNICA LINEA DE UNA PARTIDA SIN BIFURCACIONES ES
-- ""), EN ORDEN. Y EL RECTANGULO QUE CONTIENE TODAS LAS PIEDRAS, JUGADAS, MARCAS, FLECHAS Y LINEAS DEL ARBOL
-- (UNA FLECHA aa:cc SE LEE COMO EL RECTANGULO DE SUS EXTREMOS).
function pgfgo.sgf_tree(name)
	local paths, box = {}, nil
	local t = read_tree(name)
	if t then
		local size_x, size_y = sgf_size(t.nodes[1])
		local function extend(v)
			if v == "tt" and size_x <= 19 and size_y <= 19 then return end
			for _, c in ipairs(sgf_coords(v, size_y)) do
				if c[1] <= size_x and c[2] >= 1 then
					box = box and {math.min(box[1], c[1]), math.min(box[2], c[2]),
						math.max(box[3], c[1]), math.max(box[4], c[2])} or {c[1], c[2], c[1], c[2]}
				end
			end
		end
		local function walk(tree, prefix)
			for _, n in ipairs(tree.nodes) do
				for _, prop in ipairs({"AB", "AW", "B", "W", "TR", "SQ", "CR", "MA", "SL", "AR", "LN"}) do
					for _, v in ipairs(n[prop] or {}) do extend(v) end
				end
				for _, v in ipairs(n.LB or {}) do extend(v:match("^(%a%a):") or "") end
			end
			if #tree.children == 0 then
				insert(paths, "{" .. concat(prefix, ".") .. "}")
			elseif #tree.children == 1 then
				walk(tree.children[1], prefix)
			else
				for i, c in ipairs(tree.children) do
					local p = {table.unpack(prefix)}
					insert(p, i)
					walk(c, p)
				end
			end
		end
		walk(t, {})
	end
	set_clist("l__pgfgo_kernel_sgf_paths_clist", paths)
	token.set_macro("l_pgfgo_kernel_sgf_extent_tl", view_text(box))
end

-- LAS VARIANTES DEL ARBOL: CADA LINEA QUE SE APARTA DE LA PRINCIPAL, POR LA JUGADA DONDE NACE, COMO
-- "{camino}{profundidad}{nace}{empieza}{ultima}{comentada}": camino SIN LOS 1 DEL FINAL (EL DE
-- \pgfgo_kernel_sgf_read:nn); profundidad: CUANTAS VECES SE APARTA (1: DE LA LINEA PRINCIPAL); nace: LA JUGADA
-- DE LA LINEA PRINCIPAL QUE REEMPLAZA LA PRIMERA VEZ; empieza: SU PRIMERA JUGADA PROPIA (LA QUE REEMPLAZA LA
-- ULTIMA VEZ); ultima: SU CANTIDAD DE JUGADAS; comentada: 1 SI ALGUN NODO PROPIO TIENE C.
function pgfgo.sgf_branches(name)
	local list = {}
	local t = read_tree(name)
	local function walk(tree, choices, depth, moves, born, start, commented)
		for _, n in ipairs(tree.nodes) do
			if n.B or n.W then moves = moves + 1 end
			if depth > 0 and n.C and concat(n.C):match("%S") then commented = true end
		end
		if #tree.children == 0 then
			if depth > 0 then
				local p = {table.unpack(choices)}
				while p[#p] == 1 do p[#p] = nil end
				insert(list, {born = born, text = "{" .. concat(p, ".") .. "}{" .. depth .. "}{" .. born .. "}{"
					.. start .. "}{" .. moves .. "}{" .. (commented and 1 or 0) .. "}"})
			end
		elseif #tree.children == 1 then
			walk(tree.children[1], choices, depth, moves, born, start, commented)
		else
			for i, c in ipairs(tree.children) do
				local p = {table.unpack(choices)}
				insert(p, i)
				if i == 1 then
					walk(c, p, depth, moves, born, start, commented)
				else
					walk(c, p, depth + 1, moves, depth == 0 and moves + 1 or born, moves + 1, false)
				end
			end
		end
	end
	if t then walk(t, {}, 0, 0, 0, 0, false) end
	-- POR LA JUGADA DONDE NACEN; LAS QUE NACEN EN LA MISMA, EN EL ORDEN DEL ARBOL.
	for i, b in ipairs(list) do b.index = i end
	table.sort(list, function(a, b) return a.born < b.born or (a.born == b.born and a.index < b.index) end)
	local texts = {}
	for _, b in ipairs(list) do insert(texts, b.text) end
	set_clist("l__pgfgo_kernel_sgf_branches_clist", texts)
end

local markup = {{"TR", "triangle"}, {"SQ", "square"}, {"CR", "circle"}, {"MA", "cross"},
	{"SL", "selected"}, {"TB", "black-territory"}, {"TW", "white-territory"}}

function pgfgo.sgf_read(name, path_text)
	local black, white, moves = {}, {}, {}
	sgf_comments, sgf_marks, sgf_labels, sgf_dim, sgf_lines = {}, {}, {}, {}, {}
	sgf_notes, sgf_names = {}, {}
	sgf_vars, sgf_style, sgf_figures, sgf_views = {}, 0, {}, {}
	local size_x, size_y = 19, 19
	local print_mode, komi = 1, "0"
	local path = {}
	for d in (path_text or ""):gmatch("%d+") do insert(path, tonumber(d)) end
	local t = read_tree(name)
	if t then
		local nodes, missing, kids, sibs = game_line(t, path)
		if missing then
			message("warning", "sgf-variation", name, path_text)
		end
		local root = nodes[1] or {}
		size_x, size_y = sgf_size(root)
		sgf_style = root.ST and tonumber(root.ST[1]) or 0
		-- PM: 0 SIN NUMEROS, 1 COMO ESTAN, 2 REINICIADOS CADA 100.
		print_mode = root.PM and tonumber(root.PM[1]) or 1
		komi = root.KM and tonumber(root.KM[1]) and root.KM[1]:match("^%s*(.-)%s*$") or "0"
		-- LA PARTIDA SIMULADA, PARA SABER DE QUE COLOR ES CADA PUNTO MARCADO.
		local sim = {stones = {}, sx = size_x, sy = size_y}
		local started, played = false, 0
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
			-- VW: LA VISTA DESDE LA JUGADA DE ESTE NODO (O LA SIGUIENTE, SI NO TIENE JUGADA). VW[] ES TODO EL
			-- TABLERO. LA DE LOS NODOS ANTERIORES A LA PRIMERA JUGADA VALE DESDE LA PRIMERA.
			if n.VW then
				local view
				each_point(n, "VW", function(p, c)
					view = view or {c[1], c[2], c[1], c[2]}
					view = {math.min(view[1], c[1]), math.min(view[2], c[2]),
						math.max(view[3], c[1]), math.max(view[4], c[2])}
				end)
				local start = played + 1
				if sgf_views[#sgf_views] and sgf_views[#sgf_views].start == start then
					sgf_views[#sgf_views].rect = view
				else
					insert(sgf_views, {start = start, rect = view})
				end
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
					played = played + 1
					-- LAS ALTERNATIVAS A ESTA JUGADA, CON LA POSICION DESPUES DE JUGARLA.
					sgf_vars[played] = sgf_vars[played] or {}
					sgf_vars[played].siblings = moves_of(sibs[idx])
				end
			end
			-- LAS JUGADAS QUE PUEDEN SEGUIR (LAS DEL ULTIMO NODO DE LA JUGADA).
			sgf_vars[played] = sgf_vars[played] or {}
			sgf_vars[played].children = moves_of(kids[idx])
			-- FG: UNA FIGURA NUEVA EMPIEZA EN ESTA JUGADA (O EN LA SIGUIENTE, SI EL NODO NO TIENE JUGADA).
			if n.FG then
				local v = n.FG[1] or ""
				local title = v:match("^%d*:(.*)$") or (v:match("^%d*$") and "") or v
				local start = (n.B or n.W) and played or played + 1
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
					local list = sgf_notes[played] or {}
					sgf_notes[played] = list
					if prop == "N" then
						insert(sgf_names, (concat(v, " "):gsub("%s+", " "):match("^%s*(.-)%s*$")))
						insert(list, "{N}{" .. #sgf_names .. "}")
					else
						insert(list, "{" .. prop .. "}{" .. (tonumber(v[1]) == 2 and 2 or 1) .. "}")
					end
				end
			end
			if n.C then
				-- TAL CUAL (CON SUS LINEAS, PARA PODER QUITAR EL CHAT); LOS ESPACIOS SE JUNTAN AL ESCRIBIRLO.
				local list = sgf_comments[played] or {}
				sgf_comments[played] = list
				insert(list, concat(n.C, "\n"))
			end
			-- LAS MARCAS SE GUARDAN CON EL COLOR DE LA PIEDRA QUE HAY EN ESE MOMENTO.
			local function mark(kind, c, i)
				local list = sgf_marks[played] or {}
				sgf_marks[played] = list
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
			sgf_dim[played] = dim
			for _, kind in ipairs({{"AR", "arrow"}, {"LN", "line"}}) do
				for _, v in ipairs(n[kind[1]] or {}) do
					local a, b = v:match("^(%a%a):(%a%a)$")
					local p, q = a and sgf_coords(a, size_y)[1], b and sgf_coords(b, size_y)[1]
					if p and q then
						local list = sgf_lines[played] or {}
						sgf_lines[played] = list
						insert(list, "{" .. kind[2] .. "}" .. point(p[1], p[2]) .. point(q[1], q[2]))
					end
				end
			end
		end
	end
	-- LOS PASES CON LOS QUE TERMINA LA LINEA SON {black | white}{}{end}: CIERRAN LA PARTIDA Y NO SE ANOTAN.
	for i = #moves, 1, -1 do
		local color, rest = moves[i]:match("^{(%a+)}(.*)$")
		if color == "black" or color == "white" then
			if rest ~= "{}{}" then break end
			moves[i] = "{" .. color .. "}{}{end}"
		end
	end
	local figures = {}
	for _, f in ipairs(sgf_figures) do insert(figures, "{" .. f[1] .. "}{" .. f[2] .. "}") end
	set_clist("l__pgfgo_kernel_sgf_figures_clist", figures)
	token.set_macro("l_pgfgo_kernel_sgf_view_tl", view_text(views_between(0, 0)))
	tex.setcount("l_pgfgo_kernel_sgf_print_int", print_mode)
	token.set_macro("l_pgfgo_kernel_sgf_komi_tl", komi)
	tex.setcount("l_pgfgo_kernel_sgf_size_x_int", size_x)
	tex.setcount("l_pgfgo_kernel_sgf_size_y_int", size_y)
	set_clist("l__pgfgo_kernel_sgf_black_clist", black)
	set_clist("l__pgfgo_kernel_sgf_white_clist", white)
	set_clist("l__pgfgo_kernel_sgf_moves_clist", moves)
end

-- PROPIEDAD DE LA RAIZ DE LA PARTIDA (PB, PW, RE, KM, DT, ...), COMO TEXTO. VARIOS VALORES SE SEPARAN
-- CON COMAS.
function pgfgo.sgf_info(name, property)
	local t = read_tree(name)
	local root = t and t.nodes[1] or {}
	tex.sprint(-2, concat(root[property] or {}, ", "))
end

-- LA PROPIEDAD DE LA JUGADA move DE LA LINEA path_text (LA DE SU NODO Y LA DE LOS NODOS SIN JUGADA QUE LO
-- SIGUEN; move = 0: LOS NODOS ANTERIORES A LA PRIMERA JUGADA), COMO TEXTO. VARIOS VALORES, CON COMAS.
function pgfgo.sgf_move_info(name, path_text, move, property)
	local out = {}
	local t = read_tree(name)
	if t then
		local path = {}
		for d in (path_text or ""):gmatch("%d+") do insert(path, tonumber(d)) end
		local k = 0
		for _, n in ipairs((game_line(t, path))) do
			if n.B or n.W then k = k + 1 end
			if k > move then break end
			if k == move then
				for _, v in ipairs(n[property] or {}) do insert(out, v) end
			end
		end
	end
	tex.sprint(-2, concat(out, ", "))
end


---------------------------------------------------------------------------------------------------
-- TERRITORIO
---------------------------------------------------------------------------------------------------

-- text: LAS PIEDRAS VIVAS, {x}{y}{black | white}. CADA REGION DE PUNTOS SIN PIEDRAS VIVAS (VACIOS O CON
-- PIEDRAS MUERTAS) ES DEL COLOR QUE LA RODEA; SI LA TOCAN LOS DOS COLORES, O NINGUNO, ES neutral.
function pgfgo.territory(text)
	local sx, sy = goban_size()
	local b = {stones = {}, sx = sx, sy = sy}
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
	set_clist("l__pgfgo_kernel_territory_clist", list)
end

-- DIRECCIONES DE LOS LADOS: 0 ESTE, 1 NORTE, 2 OESTE, 3 SUR.
local steps = {[0] = {1, 0}, {0, 1}, {-1, 0}, {0, -1}}

-- text: LOS PUNTOS DE TERRITORIO DE UN COLOR, {x}{y}. SE PINTA CADA CASILLA [x,x+1]x[y,y+1] DEL TABLERO
-- CON ALGUNA ESQUINA EN ESOS PUNTOS. CADA CASILLA TIENE SUS LADOS EN SENTIDO ANTIHORARIO; QUEDAN LOS QUE NO
-- TIENEN OTRA CASILLA PINTADA DEL OTRO LADO. SE RECORREN PREFIRIENDO GIRAR A LA IZQUIERDA (ASI UN CONTACTO
-- POR UNA ESQUINA SEPARA LAS ZONAS) Y SOLO QUEDAN LOS VERTICES DONDE EL BORDE GIRA.
function pgfgo.region(text)
	local sx, sy = goban_size()
	local own, painted, out = {}, {}, {}
	for x, y in text:gmatch("{(%-?%d+)}{(%-?%d+)}") do
		own[key(tonumber(x), tonumber(y))] = true
	end
	for cy = 1, sy - 1 do
		for cx = 1, sx - 1 do
			if own[key(cx, cy)] or own[key(cx + 1, cy)] or own[key(cx, cy + 1)] or own[key(cx + 1, cy + 1)] then
				painted[key(cx, cy)] = true
			end
		end
	end
	local function side(x, y, d)
		local k = key(x, y)
		out[k] = out[k] or {}
		out[k][d] = true
	end
	for cy = 1, sy - 1 do
		for cx = 1, sx - 1 do
			if painted[key(cx, cy)] then
				if not painted[key(cx, cy - 1)] then side(cx, cy, 0) end
				if not painted[key(cx + 1, cy)] then side(cx + 1, cy, 1) end
				if not painted[key(cx, cy + 1)] then side(cx + 1, cy + 1, 2) end
				if not painted[key(cx - 1, cy)] then side(cx, cy + 1, 3) end
			end
		end
	end
	-- CADA CONTORNO EMPIEZA EN SU VERTICE MAS BAJO (Y DE MAS A LA IZQUIERDA), QUE SE ENCUENTRA PRIMERO
	-- AL RECORRER LOS VERTICES FILA POR FILA DESDE ABAJO.
	local contours = {}
	for y = 1, sy do
		for x = 1, sx do
			local first = out[key(x, y)]
			while first and next(first) do
				local d
				for i = 3, 0, -1 do if first[i] then d = i end end
				first[d] = nil
				local v = {point(x, y)}
				local px, py = x + steps[d][1], y + steps[d][2]
				while px ~= x or py ~= y do
					local here, nd = out[key(px, py)], nil
					for _, t in ipairs({(d + 1) % 4, d, (d + 3) % 4}) do
						if here[t] then nd = t; break end
					end
					here[nd] = nil
					if nd ~= d then insert(v, point(px, py)) end
					d = nd
					px, py = px + steps[d][1], py + steps[d][2]
				end
				insert(contours, "{" .. concat(v, ",") .. "}")
			end
		end
	end
	set_clist("l__pgfgo_kernel_region_clist", contours)
end

---------------------------------------------------------------------------------------------------
-- MEMORIA
---------------------------------------------------------------------------------------------------

-- UNA LISTA POR NOMBRE (EL DE UN goban CON name O UNA COPIA DE resume). CADA ELEMENTO ES LA LISTA DE TOKENS QUE VUELVE A
-- DIBUJARLO (SE GUARDAN TOKENS, NO TEXTO, PARA NO DEPENDER DE LOS CATCODES).
local remembered = {}

local function memory(name)
	local list = remembered[name]
	if not list then
		list = {}
		remembered[name] = list
	end
	return list
end

-- LEE EL GRUPO {...} QUE SIGUE.
function pgfgo.remember_push(name)
	insert(memory(name), token.scan_toks())
end

function pgfgo.remember_clear(name)
	remembered[name] = {}
end

function pgfgo.remember_replay(name)
	local all = {}
	for _, toks in ipairs(memory(name)) do
		for _, t in ipairs(toks) do insert(all, t) end
	end
	if #all > 0 then
		token.put_next(all)
	end
end

function pgfgo.remember_append(name, other)
	local list = memory(name)
	for _, toks in ipairs(memory(other)) do insert(list, toks) end
end

-- DEJA \tl_set:Nn \<cs> {<TODO EL CODIGO DE LA MEMORIA>} PARA QUE TeX LO EJECUTE.
function pgfgo.remember_get(name, cs)
	local all = {token.create("tl_set:Nn"), token.create(cs), token.create(123, 1)}
	for _, toks in ipairs(memory(name)) do
		for _, t in ipairs(toks) do insert(all, t) end
	end
	insert(all, token.create(125, 2))
	token.put_next(all)
end

return pgfgo
