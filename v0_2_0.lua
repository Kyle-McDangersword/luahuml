--[[----------------------------------------------------------------------------

For Huml Version 0.2.0

This is a submodule that is part of the Huml decoder and encoder module.

--]]----------------------------------------------------------------------------

local export = {}
-- local redefinitions for convenience
local find = string.find
local gsub = string.gsub
local len = string.len
local lower = string.lower
local sub = string.sub
local rep = string.rep
local concat = table.concat
local insert = table.insert
local maxn = table.maxn
local remove = table.remove
--
local tokens = {
	binary_mark = "0b",
	comment_mark = "#",
	empty_dict = "{}",
	empty_list = "[]",
	hexadecimal_mark = "0x",
	infinity = "inf",
	inline_vector_item_delimiter = ",",
	list_item_mark = "-",
	multiline_string_mark = "\"\"\"",
	nan = "nan",
	null = "null",
	number_splitter = "_",
	octal_mark = "0o",
	scalar_delimiter = ":",
	string_mark = "\"",
	vector_delimiter = "::"
	}
tokens["true"] = "true"
tokens["false"] = "false"
local characters_that_could_be_in_unenclosed_token = "A-Za-z0-9%-_%+%[%]{}%."
-- functions
local char
local escape_control_characters_function
local fall
local split
local trim
local valid_key
function char(input_string, character)
	return sub(input_string, character, character)
	end
function escape_control_characters_function(input_string)
	local output = gsub(input_string, "\b", "\\b")
	output = gsub(output, "\f", "\\f")
	output = gsub(output, "\n", "\\n")
	output = gsub(output, "\r", "\\r")
	output = gsub(output, "\t", "\\t")
	output = gsub(output, "\v", "\\v")
	return output
	end
function export.decode(huml_string)
	if type(huml_string) ~= "string" then
		return nil, "A string wasn’t provided properly."
		end
	local lua_value
	local at_first_item_of_lua_value = true
	local current_vector_type
	local at_first_child_of_multiline_vector = false
	local current_multiline_string_starting_line
	local line_number = 0
	local line_content
	local current_path = {}
	local next_list_index = 1
	-- functions
	local add_item
	local convert_to_lua_value
	local current_path_in_lua_value
	local find_unescaped_character
	local key_already_exists
	local matching_token
	local nan
	local parse_string_literal
	local parser_error
	function add_item(item)
		local local_at_first_item_of_lua_value = at_first_item_of_lua_value
		local local_at_first_child_of_multiline_vector = at_first_child_of_multiline_vector
		-- resetting now instead of for each case later on
		at_first_item_of_lua_value = false
		at_first_child_of_multiline_vector = false
		-- determining what type of item item is: a solitary value, a list item, or a dict item
		-- treating multiline strings as a special case
		if matching_token(item, 1, tokens.list_item_mark .. " ") then -- It’s a list item.
			if local_at_first_item_of_lua_value then
				-- making an implicit list
				lua_value = {}
				current_vector_type = "list"
			elseif local_at_first_child_of_multiline_vector then
				current_vector_type = "list"
				end
			if current_vector_type ~= "list" then
				return "Unacceptable list item encountered outside a list"
				end
			item = sub(item, len(tokens.list_item_mark .. " ") + 1) -- removing the list item mark and the following space to make item more convenient
			if matching_token(item, 1, tokens.vector_delimiter) then -- It’s a vector.
				if len(item) == len(tokens.vector_delimiter) then -- It’s a multiline vector.
					current_path_in_lua_value()[next_list_index] = {}
					insert(current_path, next_list_index)
					next_list_index = 1
					at_first_child_of_multiline_vector = true
					return
					end
				-- If it got to this point, it’s an inline vector.
				local expected_space = char(item, len(tokens.vector_delimiter) + 1)
				if expected_space ~= " " then
					local quote = escape_control_characters_function(expected_space)
					return "Unacceptable nonspace character ⟨" .. quote .. "⟩ encountered after a vector delimiter"
					end
				item = sub(item, len(tokens.vector_delimiter .. " ") + 1) -- removing the vector delimiter and the following space to make item more convenient
				local value, error_message = convert_to_lua_value(item, true)
				if error_message then
					return error_message
					end
				current_path_in_lua_value()[next_list_index] = value
				next_list_index = next_list_index + 1
				return
				end
			-- If it got to this point, it’s a scalar.
			if matching_token(item, 1, tokens.multiline_string_mark) then -- It’s a multiline string.
				if len(tokens.multiline_string_mark) ~= len(item) then
					local quote = escape_control_characters_function(sub(item, len(tokens.multiline_string_mark) + 1))
					return "Unacceptable content ⟨" .. quote .. "⟩ encountered after a multiline string mark"
					end
				current_path_in_lua_value()[next_list_index] = ""
				insert(current_path, next_list_index)
				next_list_index = next_list_index + 1
				current_multiline_string_starting_line = line_number
				return
				end
			-- If it got to this point, it’s a simple value.
			local value, error_message = convert_to_lua_value(item)
			if error_message then
				return error_message
				end
			current_path_in_lua_value()[next_list_index] = value
			next_list_index = next_list_index + 1
			return
			end
		-- If it got to this point, it’s either a dict item or a solitary value.
		if matching_token(item, 1, tokens.multiline_string_mark) then -- It’s a multiline string solitary value.
			if len(tokens.multiline_string_mark) ~= len(item) then
				local quote = escape_control_characters_function(sub(item, len(tokens.multiline_string_mark) + 1))
				return "Unacceptable content ⟨" .. quote .. "⟩ encountered after a multiline string mark"
				end
			if not local_at_first_item_of_lua_value then
				return "Unacceptable solitary value"
				end
			lua_value = ""
			current_multiline_string_starting_line = line_number
			return
			end
		local end_of_first_token
		local enclosed
		if matching_token(item, 1, tokens.string_mark) then -- The first token is an enclosed string.
			enclosed = true
			end_of_first_token = find_unescaped_character(sub(item, 2), tokens.string_mark)
			if not end_of_first_token then
				return "Unacceptable unclosed string"
				end
			end_of_first_token = end_of_first_token + 1
		else -- The first token is not an enclosed string.
			enclosed = false
			local _
			_, end_of_first_token = find(item, "^[" .. characters_that_could_be_in_unenclosed_token .. "]+")
			if not end_of_first_token then
				local unacceptable_character_position = find(item, "[^" .. characters_that_could_be_in_unenclosed_token .. "]")
				local quote = escape_control_characters_function(char(item, unacceptable_character_position))
				return "Unacceptable unenclosed character ⟨" .. quote .. "⟩"
				end
			end
		local first_token = sub(item, 1, end_of_first_token)
		if matching_token(item, end_of_first_token + 1, tokens.vector_delimiter) then -- It’s a vector dict item.
			if not enclosed and not valid_key(first_token) then
				local quote = escape_control_characters_function(first_token)
				return "Unacceptable unenclosed key ⟨" .. quote .. "⟩"
				end
			if local_at_first_item_of_lua_value then
				-- making an implicit dict
				lua_value = {}
				current_vector_type = "dict"
			elseif local_at_first_child_of_multiline_vector then
				current_vector_type = "dict"
				end
			if current_vector_type ~= "dict" then
				return "Unacceptable dict item encountered outside a dict"
				end
			local key, error_message = parse_string_literal(first_token)
			if error_message then
				return error_message
				end
			if key_already_exists(key) then
				local quote = escape_control_characters_function(key)
				return "Unacceptable duplicate key ⟨" .. quote .. "⟩"
				end
			item = sub(item, end_of_first_token + 1) -- removing the key to make item more convenient
			if len(item) == len(tokens.vector_delimiter) then -- It’s a multiline vector.
				current_path_in_lua_value()[key] = {}
				insert(current_path, key)
				next_list_index = 1
				at_first_child_of_multiline_vector = true
				return
				end
			-- If it got to this point, it’s an inline vector.
			local expected_space = char(item, len(tokens.vector_delimiter) + 1)
			if expected_space ~= " " then
				local quote = escape_control_characters_function(expected_space)
				return "Unacceptable nonspace character ⟨" .. quote .. "⟩ encountered after a vector delimiter"
				end
			item = sub(item, len(tokens.vector_delimiter) + 2) -- removing the vector delimiter and the following space to make item more convenient
			local value, error_message = convert_to_lua_value(item, true)
			if error_message then
				return error_message
				end
			current_path_in_lua_value()[key] = value
			return
			end
		if matching_token(item, 1, tokens.empty_list) or matching_token(item, 1, tokens.empty_dict) then -- It’s a solitary value that contains an empty vector.
			if not local_at_first_item_of_lua_value then
				return "Unacceptable solitary value"
				end
			local value, error_message = convert_to_lua_value(item, true)
			if error_message then
				return error_message
				end
			lua_value = value
			return
			end
		-- searching for an inline vector delimiter to determine whether this
		-- is an implicit vector solitary value
		local position = 1
		while position <= len(item) do
			if matching_token(item, position, tokens.inline_vector_item_delimiter) then -- It’s a vector solitary value.
				if not local_at_first_item_of_lua_value then
					return "Unacceptable solitary value"
					end
				local value, error_message = convert_to_lua_value(item, true)
				if error_message then
					return error_message
					end
				lua_value = value
				return
			elseif matching_token(item, position, tokens.multiline_string_mark) then
				-- It can’t be a vector solitary value if it contains a multiline string.
				break
			elseif matching_token(item, position, tokens.string_mark) then
				-- skipping portions encapsulated in strings
				local ending_string_mark =
					find_unescaped_character(
						sub(item, position + 1),
						tokens.string_mark
						)
				if not ending_string_mark then
					return "Unacceptable unclosed string in a value"
					end
				position = position + ending_string_mark
				end
			-- preparing for the next iteration of the loop
			position = position + 1
			end
		--
		if matching_token(item, end_of_first_token + 1, tokens.scalar_delimiter) then -- It’s a scalar dict item.
			if not enclosed and not valid_key(first_token) then
				local quote = escape_control_characters_function(first_token)
				return "Unacceptable unenclosed key ⟨" .. quote .. "⟩"
				end
			if local_at_first_item_of_lua_value then
				-- making an implicit dict
				lua_value = {}
				current_vector_type = "dict"
			elseif local_at_first_child_of_multiline_vector then
				current_vector_type = "dict"
				end
			if current_vector_type ~= "dict" then
				return "Unacceptable dict item encountered outside a dict"
				end
			local key, error_message = parse_string_literal(first_token)
			if error_message then
				return error_message
				end
			if key_already_exists(key) then
				local quote = escape_control_characters_function(key)
				return "Unacceptable duplicate key ⟨" .. quote .. "⟩"
				end
			local expected_space = char(item, end_of_first_token + len(tokens.scalar_delimiter) + 1)
			if expected_space ~= " " then
				local quote = escape_control_characters_function(expected_space)
				return "Unacceptable nonspace character ⟨" .. quote .. "⟩ encountered after a scalar delimiter"
				end
			item = sub(item, end_of_first_token + len(tokens.scalar_delimiter) + 2) -- removing the key, the scalar delimiter, and the following space to make item more convenient
			if matching_token(item, 1, tokens.multiline_string_mark) then -- It’s a multiline string.
				if len(tokens.multiline_string_mark) ~= len(item) then
					local quote = escape_control_characters_function(sub(item, len(tokens.multiline_string_mark) + 1))
					return "Unacceptable content ⟨" .. quote .. "⟩ encountered after a multiline string mark"
					end
				current_path_in_lua_value()[key] = ""
				insert(current_path, key)
				current_multiline_string_starting_line = line_number
				return
				end
			-- If it got to this point, it’s a simple value.
			local value, error_message = convert_to_lua_value(item)
			if error_message then
				return error_message
				end
			current_path_in_lua_value()[key] = value
			return
			end
		-- If it got to this point, it’s a scalar solitary value.
		if not local_at_first_item_of_lua_value then
			return "Unacceptable solitary value"
			end
		local value, error_message = convert_to_lua_value(item)
		if error_message then
			return error_message
			end
		lua_value = value
		end
	function convert_to_lua_value(value, vector)
		-- functions
		local convert_value_to_lua_value
		function convert_value_to_lua_value(value)
			-- determining what type of value value is: null, a string, a boolean, an empty vector, or a number
			if value == tokens.null then
				return
				end
			if matching_token(value, 1, tokens.string_mark) then -- value is a string.
				local end_of_string = find_unescaped_character(sub(value, 2), tokens.string_mark)
				if not end_of_string then
					return nil, "Unacceptable unclosed string in a value"
					end
				end_of_string = end_of_string + 1
				if end_of_string ~= len(value) then
					local quote = escape_control_characters_function(sub(value, end_of_string + 1))
					return nil, "Unacceptable content ⟨" .. quote .. "⟩ encountered after the end of a string in a value"
					end
				local string_value, error_message = parse_string_literal(value)
				if error_message then
					return nil, error_message
					end
				return string_value
				end
			if value == tokens["true"] then
				return true
				end
			if value == tokens["false"] then
				return false
				end
			if value == tokens.empty_list or value == tokens.empty_dict then -- value is an empty vector.
				if not vector then
					return nil, "Unacceptable empty vector encountered in a scalar item"
					end
				return {}
				end
			-- If it got to this point, value must be some kind of number.
			if value == tokens.infinity or value == "+" .. tokens.infinity then
				return math.huge
				end
			if value == "-" .. tokens.infinity then
				return - math.huge
				end
			if value == tokens.nan then
				return nan()
				end
			value = gsub(value, tokens.number_splitter, "") -- removing number splitters
			local sign = 1
			if char(value, 1) == "+" then
				value = sub(value, 2) -- removing redundant plus signs
			elseif char(value, 1) == "-" then
				sign = - 1
				value = sub(value, 2) -- removing minus signs
				end
			value = lower(value)
			if matching_token(value, 1, tokens.binary_mark) then -- value is written in binary notation.
				value = sub(value, len(tokens.binary_mark) + 1) -- removing the binary mark to make it more convenient
				local unacceptable_character = find(value, "[^01]")
				if unacceptable_character then
					local quote = escape_control_characters_function(char(value, unacceptable_character))
					return nil, "Unacceptable character ⟨" .. quote .. "⟩ encountered within a binary value"
					end
				-- converting binary to decimal
				local amount = 0
				local place_value = 1
				for i = len(value), 1, - 1 do
					if char(value, i) == "1" then
						amount = amount + place_value
						end
					place_value = 2 * place_value
					end
				--
				return sign * amount
				end
			if matching_token(value, 1, tokens.hexadecimal_mark) then -- value is written in hexadecimal notation.
				value = sub(value, len(tokens.hexadecimal_mark) + 1) -- removing the hexadecimal mark to make it more convenient
				local unacceptable_character = find(value, "[^a-f0-9]")
				if unacceptable_character then
					local quote = escape_control_characters_function(char(value, unacceptable_character))
					return nil, "Unacceptable character ⟨" .. quote .. "⟩ encountered within a hexadecimal value"
					end
				return sign * tonumber(tokens.hexadecimal_mark .. value)
				end
			if matching_token(value, 1, tokens.octal_mark) then -- value is written in octal notation.
				value = sub(value, len(tokens.octal_mark) + 1) -- removing the octal mark to make it more convenient
				local unacceptable_character = find(value, "[^0-7]")
				if unacceptable_character then
					local quote = escape_control_characters_function(char(value, unacceptable_character))
					return nil, "Unacceptable character ⟨" .. quote .. "⟩ encountered within an octal value"
					end
				-- converting octal to decimal
				local amount = 0
				local place_value = 1
				for i = len(value), 1, - 1 do
					local numeral = tonumber(char(value, i))
					amount = amount + numeral * place_value
					place_value = 8 * place_value
					end
				--
				return sign * amount
				end
			local _, end_of_initial_numerals = find(value, "^[0-9]+")
			if end_of_initial_numerals then -- value is a decimal.
				if char(value, end_of_initial_numerals + 1) == "." then -- decimal point
					local _, end_of_numerals_after_decimal_point = find(value, "^[0-9]+", end_of_initial_numerals + 2)
					if not end_of_numerals_after_decimal_point then
						local quote = escape_control_characters_function(sub(value, end_of_initial_numerals + 1))
						return nil, "Unacceptable content ⟨" .. quote .. "⟩ encountered after a number"
						end
					end_of_initial_numerals = end_of_numerals_after_decimal_point
					end
				local exponent = 1
				if char(value, end_of_initial_numerals + 1) == "e" then -- scientific notation exponent
					local exponent_portion = sub(value, end_of_initial_numerals + 2)
					local exponent_sign = 1
					if char(exponent_portion, 1) == "+" then
						exponent_portion = sub(exponent_portion, 2) -- removing redundant plus signs
					elseif char(exponent_portion, 1) == "-" then
						exponent_sign = - 1
						exponent_portion = sub(exponent_portion, 2) -- removing minus signs
						end
					if not find(exponent_portion, "^[0-9]+$") then
						local quote = escape_control_characters_function(sub(value, end_of_initial_numerals + 1))
						return nil, "Unacceptable content ⟨" .. quote .. "⟩ encountered after a number"
						end
					exponent = 10 ^ (exponent_sign * tonumber(exponent_portion))
				elseif end_of_initial_numerals ~= len(value) then
					local quote = escape_control_characters_function(sub(value, end_of_initial_numerals + 1))
					return nil, "Unacceptable content ⟨" .. quote .. "⟩ encountered after a number"
					end
				return sign * tonumber(sub(value, 1, end_of_initial_numerals)) * exponent
				end
			-- If it got to this point, the mistake is so incomprehensible that it has no idea.
			return nil, "Your poor computer has no idea what this means."
			end
		--
		if len(value) == 0 then
			return nil, "Unacceptable lack of a value"
			end
		if char(value, 1) == " " then
			return nil, "Unacceptable space encountered before a value"
			end
		if vector then
			local output = {}
			-- functions
			local key_already_exists
			function key_already_exists(key_to_check)
				for key in pairs(output) do
					if key == key_to_check then
						return true
						end
					end
				return false
				end
			--
			local vector_type
			local next_list_index = 0
			local start_of_item
			local end_of_item = 0
			local out_of_string = len(value) + 2
			-- going through each item in the inline vector
			while end_of_item ~= out_of_string do
				start_of_item = end_of_item
				-- searching for the next inline vector item delimiter
				local position = end_of_item + 1
				while position <= len(value) do
					if matching_token(value, position, tokens.string_mark) then
						-- skipping portions encapsulated in strings
						local ending_string_mark =
							find_unescaped_character(
								sub(value, position + 1),
								tokens.string_mark
								)
						if not ending_string_mark then
							return nil, "Unacceptable unclosed string in a value"
							end
						position = position + ending_string_mark
					elseif matching_token(value, position, tokens.inline_vector_item_delimiter) then
						end_of_item = position
						break
						end
					-- preparing for the next iteration of the loop
					position = position + 1
					end
				--
				if end_of_item == start_of_item then -- An appropriate delimiter for end_of_item hasn’t been found.
					end_of_item = out_of_string
				else
					end_of_item = end_of_item + 1 -- advancing to the space after the delimiter
					local expected_space = char(value, end_of_item)
					if expected_space ~= " " then
						local quote = escape_control_characters_function(expected_space)
						return nil, "Unacceptable nonspace character ⟨" .. quote .. "⟩ encountered after an item delimiter"
						end
					end
				next_list_index = next_list_index + 1
				local item = sub(value, start_of_item + 1, end_of_item - 2)
				if len(item) == 0 then
					return nil, "Unacceptable lack of a value for an item encountered inside an inline vector"
					end
				--
				if char(item, 1) == " " then
					local quote = escape_control_characters_function(trim(item))
					return nil, "Unacceptable space encountered before an item ⟨" .. quote .. "⟩ encountered inside an inline vector"
					end
				if char(item, - 1) == " " then
					local quote = escape_control_characters_function(trim(item))
					return nil, "Unacceptable space encountered after an item ⟨" .. quote .. "⟩ encountered inside an inline vector"
					end
				-- determining what type of item item is: a list item (unmarked) or a dict item
				local end_of_first_token
				local enclosed
				if matching_token(item, 1, tokens.string_mark) then -- The first token is an enclosed string.
					enclosed = true
					end_of_first_token = find_unescaped_character(sub(item, 2), tokens.string_mark)
					if not end_of_first_token then
						return nil, "Unacceptable unclosed string encountered inside an inline vector"
						end
					end_of_first_token = end_of_first_token + 1
				else -- The first token is not an enclosed string.
					enclosed = false
					local _
					_, end_of_first_token = find(item, "^[" .. characters_that_could_be_in_unenclosed_token .. "]+")
					if not end_of_first_token then
						local unacceptable_character_position = find(item, "[^" .. characters_that_could_be_in_unenclosed_token .. "]")
						local quote = escape_control_characters_function(char(item, unacceptable_character_position))
						return nil, "Unacceptable unenclosed character ⟨" .. quote .. "⟩ encountered inside an inline vector"
						end
					end
				local first_token = sub(item, 1, end_of_first_token)
				if matching_token(item, end_of_first_token + 1, tokens.vector_delimiter) then
					return nil, "Unacceptable vector delimiter ⟨" .. tokens.vector_delimiter .. "⟩ encountered inside an inline vector"
					end
				if matching_token(item, end_of_first_token + 1, tokens.scalar_delimiter) then -- It’s a dict item.
					if not enclosed and not valid_key(first_token) then
						local quote = escape_control_characters_function(first_token)
						return "Unacceptable unenclosed key ⟨" .. quote .. "⟩"
						end
					if vector_type == "list" then
						return nil, "Unacceptable dict item encountered inside an inline list"
					else
						vector_type = "dict"
						end
					local key, error_message = parse_string_literal(first_token)
					if error_message then
						return nil, error_message
						end
					if key_already_exists(key) then
						local quote = escape_control_characters_function(key)
						return "Unacceptable duplicate key ⟨" .. quote .. "⟩"
						end
					local expected_space = char(item, end_of_first_token + len(tokens.scalar_delimiter) + 1)
					if expected_space ~= " " then
						local quote = escape_control_characters_function(expected_space)
						return nil, "Unacceptable nonspace character ⟨" .. quote .. "⟩ encountered after a delimiter encountered inside an inline dict"
						end
					item = sub(item, end_of_first_token + len(tokens.scalar_delimiter) + 2) -- removing the key, the delimiter, and the following space to make item more convenient
					if len(item) == 0 then
						return nil, "Unacceptable lack of a value for an item encountered inside an inline dict"
						end
					local item_value, error_message = convert_value_to_lua_value(item)
					if error_message then
						return nil, error_message
						end
					if type(item_value) == "table" then -- It’s an empty vector (a special case).
						return nil, "Unacceptable empty vector encountered in a scalar item"
						end
					output[key] = item_value
				else -- It’s a list item.
					if end_of_first_token ~= len(item) then
						local quote = escape_control_characters_function(sub(item, end_of_first_token + 1))
						return nil, "Unacceptable content ⟨" .. quote .. "⟩ encountered after an item encountered inside an inline list"
						end
					if vector_type == "dict" then
						return nil, "Unacceptable list item encountered inside an inline dict"
					else
						vector_type = "list"
						end
					local item_value, error_message = convert_value_to_lua_value(item)
					if error_message then
						return nil, error_message
						end
					if type(item_value) == "table" then -- It’s an empty vector (a special case).
						if next_list_index ~= 1 or end_of_item ~= out_of_string then -- It’s not the first item or it’s not the last item.
						                                                             -- (There are other items then.)
							return nil, "Unacceptable empty vector encountered inside an inline vector"
							end
						return item_value
						end
					output[next_list_index] = item_value
					end
				end
			return output
		else -- not vector
			return convert_value_to_lua_value(value)
			end
		end
	function current_path_in_lua_value()
		local path_item = lua_value
		for i = 1, maxn(current_path) do
			path_item = path_item[current_path[i]]
			end
		return path_item
		end
	function find_unescaped_character(string_to_search, character)
		-- This function searches for the first instance of character that
		-- isn’t directly preceded by an odd number of backslashes.
		--
		local position = find(string_to_search, character, nil, true)
		while position do
			local backslashes = 0
			while position - 1 - backslashes >= 1 and char(string_to_search, position - 1 - backslashes) == "\\" do
				backslashes = backslashes + 1
				end
			if backslashes % 2 == 0 then -- found successfully
				return position
				end
			-- preparing for the next iteration of the loop
			position = find(string_to_search, character, position + 1, true)
			end
		end
	function key_already_exists(key_to_check)
		local parent = current_path_in_lua_value()
		for key in pairs(parent) do
			if key == key_to_check then
				return true
				end
			end
		return false
		end
	function matching_token(string_to_match, position, token)
		return sub(string_to_match, position, position - 1 + len(token)) == token
		end
	function nan()
		-- This function returns nan (not a number).
		--
		return math.abs(0 / 0)
		end
	function parse_string_literal(string_literal)
		-- This function reads a string literal encoded in plain text, and converts it into a string value.
		-- It assumes that there is a matching tokens.string_mark at the final character if there is one at the first character.
		-- Only backslashes, double quotation marks, and control characters are unescaped.
		--
		if not matching_token(string_literal, 1, tokens.string_mark) then -- string_literal is not a string literal.
			return string_literal
			end
		local output = sub(string_literal, len(tokens.string_mark) + 1, - len(tokens.string_mark) - 1) -- removing the string marks
		output = split(output, "\\\\", nil, nil, true) -- temporarily splitting output at escaped backslashes
		                                               -- so that they don’t conflict with the following conversions
		for i = 1, maxn(output) do
			output[i] = gsub(output[i], "\\\"", "\"")
			output[i] = gsub(output[i], "\\b", "\b")
			output[i] = gsub(output[i], "\\f", "\f")
			output[i] = gsub(output[i], "\\n", "\n")
			output[i] = gsub(output[i], "\\r", "\r")
			output[i] = gsub(output[i], "\\t", "\t")
			output[i] = gsub(output[i], "\\v", "\v")
			if find(output[1], "\\", nil, true) then
				return nil, "Unacceptable backslash encountered inside a string"
				end
			end
		--
		return concat(output, "\\")
		end
	function parser_error(message)
		return nil, message .. "\nLine " .. line_number .. " ⟨" .. escape_control_characters_function(line_content) .. "⟩"
		end
	--
	local start_of_line
	local end_of_line = 0
	local out_of_string = len(huml_string) + 1
	-- main loop
	-- going through each line of huml_string
	while end_of_line ~= out_of_string do
		start_of_line = end_of_line
		end_of_line = find(huml_string, "\n", end_of_line + 1, true)
		if not end_of_line then
			end_of_line = out_of_string
			end
		line_number = line_number + 1
		line_content = sub(huml_string, start_of_line + 1, end_of_line - 1)
		--
		local _, end_of_initial_spaces = find(line_content, "^ *")
		local indentation_level = end_of_initial_spaces / 2
		if current_multiline_string_starting_line then -- currently inside a multiline string
			local base_indentation_level = maxn(current_path) - 1
			if base_indentation_level == - 1 then
				base_indentation_level = 0 -- Solitary multiline strings at root level and multiline string
				                           -- items on the 1st level both have the same indentation of 0.
				end
			local base_indentation = sub(line_content, 1, base_indentation_level * 2)
			local nonspace_character_position = find(base_indentation, "[^ ]")
			if nonspace_character_position then
				local quote = escape_control_characters_function(char(base_indentation, nonspace_character_position))
				return parser_error("Unacceptable content ⟨" .. quote .. "⟩ encountered within an indent")
				end
			local line_content_without_base_indentation = sub(line_content, base_indentation_level * 2 + 1)
			if matching_token(line_content_without_base_indentation, 1, tokens.multiline_string_mark) then -- It’s the end of the multiline string.
				current_multiline_string_starting_line = nil
				-- handling any following comment
				if len(tokens.multiline_string_mark) ~= len(line_content_without_base_indentation) then -- Something else is on the line after the string mark.
					local rest_of_string = sub(line_content_without_base_indentation, len(tokens.multiline_string_mark) + 1)
					if matching_token(rest_of_string, 1, tokens.comment_mark) then
						return parser_error("Unacceptable comment mark without a preceding space")
						end
					local _, end_of_following_spaces = find(rest_of_string, "^ +")
					if not end_of_following_spaces or not matching_token(rest_of_string, end_of_following_spaces + 1, tokens.comment_mark) then -- There are either no following spaces
					                                                                                                                            -- or what follows the spaces is not a comment.
						local quote = escape_control_characters_function(rest_of_string)
						return parser_error("Unacceptable content ⟨" .. quote .. "⟩ encountered after a multiline string mark")
						end
					if char(rest_of_string, end_of_following_spaces + 2) ~= " " then
						return parser_error("Unacceptable comment mark without a following space")
						end
					end
			else -- It’s a line of the multiline string.
				local secondary_indentation = sub(line_content_without_base_indentation, 1, 2)
				if find(secondary_indentation, "[^ ]") then
					local quote = escape_control_characters_function(secondary_indentation)
					return parser_error("Unacceptable content ⟨" .. quote .. "⟩ encountered within an indent")
					end
				local content_to_add = sub(line_content_without_base_indentation, 3)
				if line_number ~= current_multiline_string_starting_line + 1 then -- It’s already past the first line.
					content_to_add = "\n" .. content_to_add
					end
				if maxn(current_path) == 0 then
					lua_value = lua_value .. content_to_add
				else
					-- going through current_path to get to the penultimate item
					-- (The final item is where the multiline string is being assembled,
					-- but it can’t be referenced since it’s a string.)
					local path_item = lua_value
					for i = 1, maxn(current_path) - 1 do
						path_item = path_item[current_path[i]]
						end
					--
					local final_path_item = current_path[maxn(current_path)]
					path_item[final_path_item] = path_item[final_path_item] .. content_to_add
					end
				end
		elseif len(line_content) ~= 0 then -- not currently inside a multiline string
		                                   -- completely skipping empty lines
			if char(line_content, - 1) == " " then
				return parser_error("Unacceptable trailing space")
				end
			if indentation_level ~= math.floor(indentation_level) then
				return parser_error("Unacceptable odd level of indentation")
				end
			if at_first_child_of_multiline_vector then
				if indentation_level ~= maxn(current_path) then
					return parser_error("Unacceptable level of indentation directly after the declaration of a multiline vector")
					end
			else -- not at_first_child_of_multiline_vector
				if indentation_level > maxn(current_path) then
					return parser_error("Unacceptable level of indentation")
				else -- The indentation level has either stayed the same or decreased.
					-- going through each level the indentation has decreased by
					-- and updating relevant tracking variables
					for i = maxn(current_path), indentation_level + 1, - 1 do
						remove(current_path)
						local key = next(current_path_in_lua_value())
						if type(key) == "number" then
							current_vector_type = "list"
							next_list_index = maxn(current_path_in_lua_value()) + 1
						else -- type(key) == "string"
							current_vector_type = "dict"
							end
						end
					end
				end
			local pure_line_content = sub(line_content, end_of_initial_spaces + 1)
			-- checking and removing any comment from pure_line_content
			local position = 1
			while position <= len(pure_line_content) do
				-- searching for a comment mark
				if matching_token(pure_line_content, position, tokens.multiline_string_mark) then
					-- skipping multiline string marks
					position = position + len(tokens.multiline_string_mark) - 1
				elseif matching_token(pure_line_content, position, tokens.string_mark) then
					-- skipping portions encapsulated in strings
					local ending_string_mark =
						find_unescaped_character(
							sub(pure_line_content, position + 1),
							tokens.string_mark
							)
					if not ending_string_mark then -- Found an unclosed string.
					                               -- But will wait until adding the item to throw a more precise error.
						break
						end
					position = position + ending_string_mark
				elseif matching_token(pure_line_content, position, tokens.comment_mark) then
					if position ~= 1 and char(pure_line_content, position - 1) ~= " " then
						return parser_error("Unacceptable comment mark without a preceding space")
						end
					if char(pure_line_content, position + 1) ~= " " then
						return parser_error("Unacceptable comment mark without a following space")
						end
					pure_line_content = sub(pure_line_content, 1, position - 1) -- removing the actual comment
					end
				-- preparing for the next iteration of the loop
				position = position + 1
				end
			pure_line_content = gsub(pure_line_content, " +$", "") -- removing any resulting spaces due to a comment removal
			--
			if len(pure_line_content) ~= 0 then
				local error_message = add_item(pure_line_content)
				if error_message then
					return parser_error(error_message)
					end
				end
			end
		end
	--
	if at_first_item_of_lua_value then
		return parser_error("Unacceptable lack of any content")
		end
	if at_first_child_of_multiline_vector then
		return parser_error("Unacceptable lack of children in a vector")
		end
	if current_multiline_string_starting_line then
		return parser_error("Unacceptable unclosed multiline string that was opened on line " .. current_multiline_string_starting_line)
		end
	return lua_value
	end
function export.encode(lua_value, escape_control_characters, split_numbers)
	local huml = {}
	-- functions
	local add_item
	local empty_table
	local escape_backslashes_and_double_quotation_marks
	local format_number
	local is_nan
	local only_numerical_keys
	function add_item(key_to_add, item_to_add, indentation_level) -- main recursive function
		-- functions
		local insert_line
		function insert_line(value, vector)
			if indentation_level == - 1 then
				-- bypassing keys, list marks, and delimiters when at root level
				insert(huml, value)
				return
				end
			local line_content = rep("  ", indentation_level)
			if key_to_add then -- inserting into a Huml dict
				line_content = line_content .. key_to_add
				if not vector then
					line_content = line_content .. tokens.scalar_delimiter .. " "
					end
			else -- inserting into a Huml list
				line_content = line_content .. tokens.list_item_mark .. " "
				end
			if vector then
				if value then
					line_content = line_content .. tokens.vector_delimiter .. " " .. value
				else -- The values must be coming on subsequent lines.
					line_content = line_content .. tokens.vector_delimiter
					end
			else
				line_content = line_content .. value
				end
			insert(huml, line_content)
			end
		--
		local item_type = type(item_to_add)
		if item_type == "table" then
			if empty_table(item_to_add) then
				insert_line(tokens.empty_dict, true)
				return
				end
			insert_line(nil, true)
			if only_numerical_keys(item_to_add) then
				-- adding each child
				for i = 1, maxn(item_to_add) do
					local error_message, error_location = add_item(nil, item_to_add[i], indentation_level + 1)
					if error_message then
						insert(error_location, i)
						return error_message, error_location
						end
					end
			else -- There are nonnumerical keys.
				-- adding each child
				-- converting all keys to strings
				local used_keys = {}
				for key, value in pairs(item_to_add) do
					local string_key = tostring(key)
					string_key = escape_control_characters_function(string_key)
					string_key = escape_backslashes_and_double_quotation_marks(string_key)
					-- checking if the key is a duplicate of another key when converted to a string
					for i = 1, maxn(used_keys) do
						if used_keys[i] == string_key then
							return "The input table contains conflicting keys when they’re converted to strings.", {"\"" .. string_key .. "\""}
							end
						end
					--
					insert(used_keys, string_key)
					if not valid_key(string_key) then
						string_key = tokens.string_mark .. string_key .. tokens.string_mark
						end
					local error_message, error_location = add_item(string_key, value, indentation_level + 1)
					if error_message then
						insert(error_location, "\"" .. key .. "\"")
						return error_message, error_location
						end
					end
				end
		elseif item_type == "number" then
			local number = item_to_add
			if number == math.huge then
				insert_line(tokens.infinity)
				return
				end
			if number == - math.huge then
				insert_line("-" .. tokens.infinity)
				return
				end
			if is_nan(number) then
				insert_line(tokens.nan)
				return
				end
			if split_numbers then
				number = format_number(number)
				end
			insert_line(number)
		elseif item_type == "boolean" then
			if item_to_add then
				insert_line(tokens["true"])
			else
				insert_line(tokens["false"])
				end
		elseif item_type == "nil" then
			insert_line(tokens.null)
		else -- If it’s any other type, it will end up being a string.
			local string_item = tostring(item_to_add)
			if escape_control_characters then
				string_item = escape_backslashes_and_double_quotation_marks(string_item)
				string_item = escape_control_characters_function(string_item)
				insert_line(tokens.string_mark .. string_item .. tokens.string_mark)
				return
				end
			local newline = find(string_item, "\n", nil, true)
			if newline then -- string_item contains at least 1 canonical newline,
			                -- so it will be represented as a multiline string.
				local multiline_item = {tokens.multiline_string_mark}
				local start_of_line
				local end_of_line = 0
				local out_of_string = len(string_item) + 1
				-- adding each line
				while end_of_line ~= out_of_string do
					start_of_line = end_of_line
					end_of_line = find(string_item, "\n", end_of_line + 1, true)
					if not end_of_line then
						end_of_line = out_of_string
						end
					local line = sub(string_item, start_of_line + 1, end_of_line - 1)
					insert(multiline_item, rep("  ", indentation_level + 1) .. line)
					end
				--
				insert(multiline_item, rep("  ", indentation_level) .. tokens.multiline_string_mark)
				insert_line(concat(multiline_item, "\n"))
			else -- string_item doesn’t contain any canonical newlines,
			     -- so it will be represented as a singleline string.
				insert_line(tokens.string_mark .. escape_backslashes_and_double_quotation_marks(string_item) .. tokens.string_mark)
				end
			end
		end
	function empty_table(table_to_check)
		for key in pairs(table_to_check) do
			return false
			end
		return true
		end
	function escape_backslashes_and_double_quotation_marks(input_string)
		local output = gsub(input_string, "\\", "\\\\")
		output = gsub(output, "\"", "\\\"")
		return output
		end
	function format_number(number)
		-- functions
		local format_rational_number
		function format_rational_number(rational_number)
			local sign = ""
			if char(rational_number, 1) == "-" then
				sign = "-"
				rational_number = sub(rational_number, 2)
				end
			local decimal_point = find(rational_number, ".", 1, true)
			if decimal_point then
				local spaces_needed = math.floor((len(rational_number) - decimal_point - 1) / 3)
				local ultimate_length = len(rational_number) + spaces_needed
				for i = decimal_point + 4, ultimate_length, 4 do
					rational_number = sub(rational_number, 1, i - 1) .. tokens.number_splitter .. sub(rational_number, i)
					end
			else
				decimal_point = len(rational_number) + 1
				end
			for i = decimal_point - 4, 1, - 3 do
				rational_number = sub(rational_number, 1, i) .. tokens.number_splitter .. sub(rational_number, i + 1)
				end
			return sign .. rational_number
			end
		--
		number = tostring(number)
		local e = find(number, "e", 2, true)
		if e then
			local exponent = sub(number, e + 1)
			if char(exponent, 1) == "+" then
				exponent = sub(exponent, 2)
				end
			return format_rational_number(sub(number, 1, e - 1)) .. "e" .. format_rational_number(exponent)
			end
		return format_rational_number(number)
		end
	function is_nan(value)
		-- This function checks if a value is nan (not a number).
		--
		if type(value) ~= "number" then
			return false
			end
		if tostring(math.abs(value)) == "nan" then
			return true
			end
		return false
		end
	function only_numerical_keys(table_to_check)
		for key in pairs(table_to_check) do
			if type(key) ~= "number" then
				return false
				end
			end
		return true
		end
	--
	local error_message, error_location = add_item(nil, lua_value, - 1) -- starting at - 1 level of indentation so that any direct children can sit at 0
	if error_message then
		-- adding a tree path resembling Lua table notation
		error_message = error_message .. "\n"
		for i = maxn(error_location), 1, - 1 do
			error_message = error_message .. "[" .. error_location[i] .. "]"
			end
		--
		return nil, error_message
		end
	return concat(huml, "\n")
	end
function fall(string_to_search, pattern, start_point, end_point, plain)
	-- This function finds all the matching portions in a string.
	--
	-- defaults
	if not start_point then
		start_point = 1
		end
	if not end_point then
		end_point = len(string_to_search)
	elseif end_point < 0 then
		end_point = len(string_to_search) + end_point + 1
		end
	--
	local starts = {}
	local ends = {}
	repeat
		local start_index, end_index =
			find(string_to_search, pattern, start_point, plain)
		if not start_index or end_index > end_point then
			break
			end
		insert(starts, start_index)
		insert(ends, end_index)
		start_point = end_index + 1
	until end_index == end_point
	return starts, ends
	end
function split(string_to_split, pattern, start_point, end_point, plain)
	if not pattern or pattern == "" then
		local output = {}
		for i = 1, len(string_to_split) do
			insert(output, char(string_to_split, i))
			end
		return output
		end
	local separator_starts, separator_ends =
		fall(string_to_split, pattern, start_point, end_point, plain)
	if maxn(separator_starts) == 0 then
		return {string_to_split}
		end
	local output = {}
	-- first substring
	if separator_starts[1] == 1 then
		output[1] = ""
	else
		output[1] = sub(string_to_split, 1, separator_starts[1] - 1)
		end
	-- middle substrings
	for i = 2, maxn(separator_starts) do
		if separator_ends[i - 1] + 1 == separator_starts[i] then
			output[i] = ""
		else
			output[i] =
				sub(
					string_to_split,
					separator_ends[i - 1] + 1,
					separator_starts[i] - 1
					)
			end
		end
	-- last substring
	if separator_ends[maxn(separator_ends)] == len(string_to_split) then
		insert(output, "")
	else
		insert(
			output,
			sub(string_to_split, separator_ends[maxn(separator_ends)] + 1)
			)
		end
	--
	return output
	end
function trim(input_string)
	local output = gsub(input_string, "^%s+", "")
	output = gsub(output, "%s+$", "")
	return output
	end
function valid_key(key)
	local invalid =
		len(key) == 0
			or find(char(key, 1), "[^A-Za-z]") -- The first character is not an ascii letter.
			or find(key, "[^A-Za-z0-9%-_]") -- The key contains characters that are not
			                                -- alphanumeric, not a hyphen, and not an underscore.
	return not invalid
	end
--
return export