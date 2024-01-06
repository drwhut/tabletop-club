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

class_name DictionaryParser
extends Reference

## A class for parsing dictionaries with data validation.


## The dictionary to parse.
var dictionary := {}


func _init(to_parse: Dictionary):
	dictionary = to_parse


## Get the value from [member dictionary] that corresponds to the given key.
## It must be the same data type as [code]default[/code], otherwise an error
## is thrown and the default value is returned instead. Integers are converted
## to floats if necessary, but the reverse is not true.
func get_strict_type(key, default):
	# NOTE: This is almost identical to AdvancedConfigFile.get_strict().
	if not dictionary.has(key):
		return default
	
	var value = dictionary.get(key)
	var value_type := typeof(value)
	var default_type := typeof(default)
	
	if value_type == default_type:
		return value
	elif value_type == TYPE_INT and default_type == TYPE_REAL:
		return float(value)
	else:
		push_error("Value of '%s' is incorrect data type (expected: %s, got: %s)" % [
				str(key), SanityCheck.get_type_name(default_type),
				SanityCheck.get_type_name(value_type)])
		return default
