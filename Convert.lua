--[[
  _                __   ____  __ _      
 | |        	   \ \ / /  \/  | |	    
 | |    _   _  __ _ \ V /| \  / | |	    
 | |   | | | |/ _` | > < | |\/| | |	    
 | |___| |_| | (_| |/ . \| |  | | |____ 
 |______\__,_|\__,_/_/ \_\_|  |_|______|

v1.2.1 (executable version)

A simple, open-source XML to Lua file converter, made for my
Roblox text rendering module Text+, as web and executable.


GitHub:
https://github.com/AlexanderLindholt/LuaXML


--------------------------------------------------------------------------------
MIT License

Copyright (c) 2025 AlexanderLindholt

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--------------------------------------------------------------------------------

]]--

local lfs = require("lfs")

-- File functions.
local function findSupportedFile()
	for filename in lfs.dir(".") do
		if filename ~= "." and filename ~= ".." then
			local attribute = lfs.attributes(filename)
			if attribute and attribute.mode == "file" then
				local extension = filename:match("^.+(%..+)$")
				if extension then
					extension = extension:lower()
					if extension == ".fnt" or extension == ".txt" or extension == ".xml" then
						return filename
					end
				end
			end
		end
	end
end
local function readFile(path)
	local file = io.open(path, "rb")
	if not file then return end
	local content = file:read("*a")
	file:close()
	return content
end
local function writeFile(path, content)
	local file = io.open(path, "wb")
	if not file then return end
	local success = file:write(content)
	file:close()
	if success then
		return true
	end
end

-- XML to Lua conversion.
local function extractInteger(element, attribute)
	return tonumber(element:match(attribute.."=\"(-?%d+)\""))
end
local function convert(xml)
	-- Normalize whitespace for multi-line element handling.
	xml = xml:gsub("%s+", " ")

	-- Extract font size from info element.
	local fontSize = nil
	do
		local infoElement = xml:match("<info[^>]+>")
		if infoElement then
			fontSize = extractInteger(infoElement, "size")
		else
			return "Missing info element. Make sure the file is in \"BMFont XML\" format."
		end
	end

	-- Gather character information.
	local characters = {}
	
	for element in xml:gmatch("<char[^>]+/>") do
		local id = extractInteger(element, "id")
		if id then
			-- Extract data.
			local width = extractInteger(element, "width")
			local height = extractInteger(element, "height")
			local x = extractInteger(element, "x")
			local y = extractInteger(element, "y")
			local xOffset = extractInteger(element, "xoffset")
			local yOffset = extractInteger(element, "yoffset")
			local xAdvance = extractInteger(element, "xadvance")

			-- Ensure no data is missing.
			if not width or not height or not x or not y or not xOffset or not yOffset or not xAdvance then
				return "Character data is missing. Ensure the file is in \"BMFont XML\" format."
			end

			-- Format and insert data.
			table.insert(characters,
				"[\""..string.char(id):gsub("[\\\"]", function(c)
					if c == "\\" then
						return "\\\\"
					else
						return "\\\""
					end
				end).."\"]".." = {"..width..", "..height..", Vector2.new("..x..", "..y.."), "..xOffset..", "..yOffset..", "..xAdvance.."}"
			) -- ["A"] = {1, 2, Vector2.new(10, 20), 1, 2, 1}
		end
	end
	
	-- Build output structure.
	local output = "{\n\tSize = "..fontSize..",\n\tCharacters = {\n"
	for index, entry in ipairs(characters) do
		if index == #characters then
			-- Ensure no comma at the last member in the table.
			output = output.."\t\t"..entry.."\n"
		else
			output = output.."\t\t"..entry..",\n"
		end
	end
	output = output.."\t}\n}"

	-- Return final Lua table string.
	return output
end

-- Application.
local inputFile = findSupportedFile()
if not inputFile then
	print("No accepted files found.\nAccepted files: XML, FNT, TXT.")
	io.read()
end

local xml = readFile(inputFile)
if not xml then
	print("Failed to read \""..inputFile.."\".")
	io.read()
end

local result = convert(xml)
if type(result) ~= "string" then
	if result then
		print("Conversion failed: "..result)
	else
		print("Conversion failed.")
	end
	io.read()
end

local outputFile = inputFile:gsub("%.%w+$", "")..".lua"
if not writeFile(outputFile, result) then
	print("Failed to write \""..outputFile.."\". Ensure the file location is not restricted, or run as administrator.")
	io.read()
end
