-- pgf-go-pages.lua: PASA CADA PAGINA DE UN DOCUMENTO COMPILADO CON \usepackage[pages]{pgf-go} A SU PROPIO
-- ARCHIVO, EN LA CARPETA <documento>-pages. NO SE LLAMA DIRECTO: LO LLAMA <documento>-pages.lua, QUE ESCRIBE
-- EL PAQUETE CON LOS NOMBRES DE LAS PAGINAS:
--   texlua <documento>-pages.lua [svg | png | pdf] [resolucion]
-- svg (POR DEFECTO) CON pdftocairo O dvisvgm; png (resolucion EN PUNTOS POR PULGADA, 300 SI NO SE DICE) CON
-- pdftocairo O pdftoppm; pdf CON pdftocairo O pdfseparate.

local windows = os.type == "windows"
local null = windows and "NUL" or "/dev/null"

local function quote(s)
	return "\"" .. s .. "\""
end

local function run(command)
	local ok, _, code = os.execute(command)
	return ok == true or ok == 0 or code == 0
end

local function exists(program)
	return run(program .. " -v >" .. null .. " 2>&1") or run(program .. " --version >" .. null .. " 2>&1")
end

-- COMO SE HACE CADA FORMATO: EL PROGRAMA Y EL COMANDO PARA LA PAGINA i DE input EN output (SIN EXTENSION).
local tools = {
	svg = {
		{"pdftocairo", function(i, input, output)
			return "pdftocairo -svg -f " .. i .. " -l " .. i .. " " .. quote(input) .. " " .. quote(output .. ".svg")
		end},
		{"dvisvgm", function(i, input, output)
			return "dvisvgm --pdf --page=" .. i .. " -o " .. quote(output .. ".svg") .. " " .. quote(input)
		end},
	},
	png = {
		{"pdftocairo", function(i, input, output, dpi)
			return "pdftocairo -png -singlefile -r " .. dpi .. " -f " .. i .. " -l " .. i .. " " .. quote(input) .. " " .. quote(output)
		end},
		{"pdftoppm", function(i, input, output, dpi)
			return "pdftoppm -png -singlefile -r " .. dpi .. " -f " .. i .. " -l " .. i .. " " .. quote(input) .. " " .. quote(output)
		end},
	},
	pdf = {
		{"pdftocairo", function(i, input, output)
			return "pdftocairo -pdf -f " .. i .. " -l " .. i .. " " .. quote(input) .. " " .. quote(output .. ".pdf")
		end},
		{"pdfseparate", function(i, input, output)
			return "pdfseparate -f " .. i .. " -l " .. i .. " " .. quote(input) .. " " .. quote(output .. ".pdf")
		end},
	},
}

return function(pdf, names, arg)
	local format = arg[1] or "svg"
	local dpi = tonumber(arg[2]) or 300
	if not tools[format] then
		print("pgf-go: unknown format '" .. format .. "' (svg, png or pdf).")
		os.exit(1)
	end
	local tool
	for _, t in ipairs(tools[format]) do
		if exists(t[1]) then
			tool = t
			break
		end
	end
	if not tool then
		local programs = {}
		for _, t in ipairs(tools[format]) do table.insert(programs, t[1]) end
		print("pgf-go: " .. format .. " needs " .. table.concat(programs, " or ") .. ".")
		os.exit(1)
	end
	-- EL PDF Y LA CARPETA ESTAN JUNTO A ESTE SCRIPT.
	local dir = arg[0]:match("^(.*)[/\\]") or "."
	local input = dir .. "/" .. pdf
	if not lfs.isfile(input) then
		print("pgf-go: there is no file '" .. input .. "'.")
		os.exit(1)
	end
	local folder = dir .. "/" .. pdf:gsub("%.pdf$", "") .. "-pages"
	lfs.mkdir(folder)
	for i, name in ipairs(names) do
		local output = folder .. "/" .. name
		if not run(tool[2](i, input, output, dpi)) then
			print("pgf-go: " .. tool[1] .. " failed on page " .. i .. ".")
			os.exit(1)
		end
		print(output .. "." .. format)
	end
end
