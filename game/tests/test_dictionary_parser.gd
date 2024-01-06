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

extends GutTest

## Test the [DictionaryParser] class.


func test_get_strict_type() -> void:
	# NOTE: This test is identical to the one in test_advanced_config.gd, since
	# both functions serve the same purpose.
	var dict := {
		"int_value": 10,
		"float_value": 0.5,
		"string_value": "Hello, world!"
	}
	var parser := DictionaryParser.new(dict)
	
	# Boolean value does not exist, returns default.
	assert_eq(parser.get_strict_type("bool_value", true), true)
	
	# Success cases.
	assert_eq(parser.get_strict_type("int_value", 0), 10)
	assert_eq(parser.get_strict_type("float_value", 0.0), 0.5)
	assert_eq(parser.get_strict_type("string_value", ""), "Hello, world!")
	
	# Integers will be converted to floats if necessary...
	assert_eq(parser.get_strict_type("int_value", 0.25), 10.0)
	# ... but not the other way around.
	assert_eq(parser.get_strict_type("float_value", 25), 25)
	
	# Fail cases.
	assert_eq(parser.get_strict_type("int_value", "hi"), "hi")
	assert_eq(parser.get_strict_type("float_value", Vector2.ZERO), Vector2.ZERO)
	assert_eq(parser.get_strict_type("string_value", null), null)
