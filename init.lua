--[=[---------------------------------------------------------------------------

luahuml
Huml decoder and encoder
Version 0.1.0
for Lua Versions 5.1 to 5.5
for Huml Version 0.2.0

This is a module that converts data from Huml to Lua and vice versa.
Information about Huml can be found at huml.io.

Exported Functions

    decode(huml_string)
        -- Returns a Lua value, or nil along with an error message if failed.

    encode(lua_value, [escape_control_characters, [split_numbers]])
        -- Returns a Huml string, or nil along with an error message if failed.
        -- If escape_control_characters is truthy, canonical control characters
           will be converted into their escaped representations. Multiline
           strings will be precluded since the newlines will become “\n”.
        -- If split_numbers is truthy, decimals like 5000000 will be
           represented as “5_000_000”, as supported by the Huml spec.

--------------------------------------------------------------------------------

Notes

Since Huml has a distinction between lists and dicts while Lua does not, Lua
tables that contain only numerical keys will be converted into Huml lists, and
all other Lua tables will be converted into Huml dicts, in which case, all
nonstring keys will be converted into strings. Duplicate keys are not allowed in
Huml, so if the behaviour that was just described causes duplicate keys, the
function will fail.

--]=]---------------------------------------------------------------------------

local export = {}
-- local redefinitions for convenience
local find = string.find
local gsub = string.gsub
local sub = string.sub
-- functions
function export.decode(huml_string)
	local version = "v0.2.0" -- latest
	if sub(huml_string, 1, 6) == "%HUML " then -- A directive has been found on the first line.
		local newline = find(huml_string, "\n", nil, true)
		if not newline then
			return
			end
		if sub(huml_string, 7, 7) == "v" then -- It’s a version directive.
			version = sub(huml_string, 7, newline - 1)
			end
		huml_string = sub(huml_string, newline) -- removing the content of the first line
		end
	version = gsub(version, "%.", "_")
	if version == "v0_2_0" then
		return require("luahuml." .. version).decode(huml_string)
		end
	return nil, "An unsupported version of Huml was specified."
	end
function export.encode(lua_value, escape_control_characters, split_numbers)
	return require("luahuml.v0_2_0").encode(lua_value, escape_control_characters, split_numbers)
	end
--
return export