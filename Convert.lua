--[[
  _                __   ____  __ _      
 | |               \ \ / /  \/  | |     
 | |    _   _  __ _ \ V /| \  / | |     
 | |   | | | |/ _` | > < | |\/| | |     
 | |___| |_| | (_| |/ . \| |  | | |____ 
 |______\__,_|\__,_/_/ \_\_|  |_|______|

A simple, open-source XML to Lua file converter, made for my
Roblox text rendering module Text+, and written in pure Lua.


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
    return nil
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
    if success ~= nil then
        return true
    end
end

-- XML to Lua conversion.
local function extractInteger(element, attribute)
    local integer = tonumber(element:match(attribute.."=\"(%d+)\""))
    if integer then
        return integer
    else
        return 0
    end
end
local function convert(xml)
    -- Normalize whitespace for multi-line element handling.
    local xml = xml:gsub("%s+", " ")
    local fontSize = 0

    -- Extract font size from info element.
    local infoElement = xml:match("<info[^>]+>")
    if infoElement then
        fontSize = extractInteger(infoElement, "size")
    end

    -- Gather character information.
    local characters = {}
    
    for element in xml:gmatch("<char[^>]+/>") do
        local id = extractInteger(element, "id")
        if id > 0 then
            local width = extractInteger(element, "width")
            local height = extractInteger(element, "height")
            local x = extractInteger(element, "x")
            local y = extractInteger(element, "y")
            local xOffset = extractInteger(element, "xoffset")
            local yOffset = extractInteger(element, "yoffset")
            local xAdvance = extractInteger(element, "xadvance")

            -- Process character and escape special characters
            local char_str = string.char(id)
            local escaped = char_str:gsub("[\\\"]", function(c)
                return c == "\\" and "\\\\" or "\\\""
            end)
            local key = string.format("[\"%s\"]", escaped)

            table.insert(characters, key.." = {Vector2.new("..width..", "..height.."), Vector2.new("..x..", "..y.."), Vector2.new("..xOffset..", "..yOffset.."), "..xAdvance.."}")
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
    return output
end

-- Application.
local inputFile = findSupportedFile()
if not inputFile then
    print("No supported files found.\n")
    io.read()
end

local xml = readFile(inputFile)
if not xml then
    print("Failed to read \""..inputFile.."\".\n")
    io.read()
end

local lua_table = convert(xml)
if not lua_table then
    print("Conversion failed.\n")
    io.read()
end

local output_file = inputFile:gsub("%.%w+$", "")..".lua"
if not writeFile(output_file, lua_table) then
    print("Failed to write \""..output_file.."\".\n")
    io.read()
end
