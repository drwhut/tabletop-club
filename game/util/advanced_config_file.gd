# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

class_name AdvancedConfigFile
extends ConfigFile

## A version of the in-built [ConfigFile] class with extra features.
##
## This class includes type checking, as well as searching sections that use
## wildcards.


## Similar to [method ConfigFile.get_value], except it checks to see if the
## value is the same data type as [code]default[/code]. Integers will be
## converted to floats if necessary, but the reverse is not true.
func get_value_strict(section: String, key: String, default):
	if not has_section_key(section, key):
		return default
	
	var value = get_value(section, key)
	var value_type := typeof(value)
	var default_type := typeof(default)
	
	if value_type == default_type:
		return value
	elif value_type == TYPE_INT and default_type == TYPE_REAL:
		return float(value)
	else:
		push_error("Value of property '%s' in section '%s' is incorrect data type (expected: %s, got: %s)" % [
				key, section, SanityCheck.get_type_name(default_type),
				SanityCheck.get_type_name(value_type)])
		return default


## Searches all of the sections of the file for the given key, and returns the
## value of the one whose section pattern is longest, given that it matches with
## [code]full_section[/code]. If no instances of the key was found,
## [code]default[/code] is returned. If [code]strict_type[/code] is enabled,
## the value must be the same data type as [code]default[/code] for it to be
## returned, otherwise an error is thrown and the default value is returned.
func get_value_by_matching(full_section: String, key: String, default, strict_type: bool):
	var potential_sections := []
	for pattern in get_sections():
		if has_section_key(pattern, key) and is_pattern_match(full_section, pattern):
			potential_sections.push_back(pattern)
	
	if potential_sections.empty():
		return default
	
	potential_sections.sort_custom(StringLengthSorter, "sort_custom")
	var longest_section: String = potential_sections.pop_back()
	
	if strict_type:
		return get_value_strict(longest_section, key, default)
	else:
		return get_value(longest_section, key, default)


## Check if the source string matches the given pattern. The pattern string can
## contain asterisks (*) to match 0 or more characters, and question marks (?)
## to match exactly one character.
static func is_pattern_match(source: String, pattern: String) -> bool:
	return _pattern_match_recursive(source, pattern)


## A recursive algorithm for [method is_pattern_match].
static func _pattern_match_recursive(source: String, pattern: String) -> bool:
	var source_ptr := 0
	var pattern_ptr := 0
	var is_asterisk := false
	
	while pattern_ptr < pattern.length():
		var pattern_char := pattern[pattern_ptr]
		
		if pattern_char == "*":
			is_asterisk = true
		else:
			if is_asterisk:
				# This pattern character is straight after an asterisk, so we
				# need to find all instances of this character from where we
				# are scanning in the source string to see if one instance
				# matches the remaining pattern (the recursive part!)
				while source_ptr < source.length():
					var source_char := source[source_ptr]
					if pattern_char == "?" or source_char == pattern_char:
						var new_source := ""
						if source_ptr < source.length() - 1:
							new_source = source.substr(source_ptr + 1)
						
						var new_pattern := ""
						if pattern_ptr < pattern.length() - 1:
							new_pattern = pattern.substr(pattern_ptr + 1)
						
						# We've found a pattern that matches the rest of the
						# string, so return out!
						if _pattern_match_recursive(new_source, new_pattern):
							return true
					
					source_ptr += 1
				
				# If no matching characters were found, matching has failed.
				return false
			else:
				# Pattern expects a character, but there are none left.
				if source_ptr >= source.length():
					return false
				
				# Source character was not what we expected it to be.
				var source_char := source[source_ptr]
				if (pattern_char != "?" and source_char != pattern_char):
					return false
				
				source_ptr += 1
			
			is_asterisk = false
		
		pattern_ptr += 1
	
	# If the last pattern character was an asterisk, accept anything beyond
	# where we checked in the source string. If not, we expect the source
	# stirng to have ended at the same time as the pattern string.
	return is_asterisk or source_ptr >= source.length()


## A custom sorter that sorts a list of strings by ascending length. If two
## strings have the same length, then they are sorted lexically.
class StringLengthSorter:
	static func sort_custom(a: String, b: String) -> bool:
		if a.length() == b.length():
			return a < b
		else:
			return a.length() < b.length()
