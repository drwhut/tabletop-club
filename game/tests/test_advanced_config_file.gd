# tabletop-club
# Copyright (c) 2020-2023 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2023 Tabletop Club contributors (see game/CREDITS.tres).
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

## Test the [AdvancedConfigFile] class.


func test_get_value_strict() -> void:
	var cfg := AdvancedConfigFile.new()
	cfg.set_value("section", "int_value", 10)
	cfg.set_value("section", "float_value", 0.5)
	cfg.set_value("section", "string_value", "Hello, world!")
	
	# Boolean value does not exist, returns default.
	assert_eq(cfg.get_value_strict("section", "bool_value", true), true)
	# Wrong section name.
	assert_eq(cfg.get_value_strict("uwotm8", "int_value", 5), 5)
	
	# Success cases.
	assert_eq(cfg.get_value_strict("section", "int_value", 0), 10)
	assert_eq(cfg.get_value_strict("section", "float_value", 0.0), 0.5)
	assert_eq(cfg.get_value_strict("section", "string_value", ""), "Hello, world!")
	
	# Integers will be converted to floats if necessary...
	assert_eq(cfg.get_value_strict("section", "int_value", 0.25), 10.0)
	# ... but not the other way around.
	assert_eq(cfg.get_value_strict("section", "float_value", 25), 25)
	
	# Fail cases.
	assert_eq(cfg.get_value_strict("section", "int_value", "hi"), "hi")
	assert_eq(cfg.get_value_strict("section", "float_value", Vector2.ZERO), Vector2.ZERO)
	assert_eq(cfg.get_value_strict("section", "string_value", null), null)


func test_pattern_match() -> void:
	### NO WILDCARDS ###
	
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "hello"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "hella"))
	assert_false(AdvancedConfigFile.is_pattern_match("hallo", "hello"))
	
	# Pattern matching is case-sensitive.
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "Hello"))
	
	# Testing differing lengths of strings.
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "hell"))
	assert_false(AdvancedConfigFile.is_pattern_match("hell", "hello"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", ""))
	assert_false(AdvancedConfigFile.is_pattern_match("", "hello"))
	assert_true(AdvancedConfigFile.is_pattern_match("", ""))
	
	### ? WILDCARD ###
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "hell?"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "?e??o"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "?????"))
	
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "h?l?a"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "????"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "hello?"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "?hello"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "he?"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "?ell"))
	assert_false(AdvancedConfigFile.is_pattern_match("", "???"))
	
	### * WILDCARD ###
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*****"))
	assert_true(AdvancedConfigFile.is_pattern_match("", "*"))
	assert_true(AdvancedConfigFile.is_pattern_match("", "***"))
	
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "h*"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "he*"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "hel*"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "hell*"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "hello*"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "hello***"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "hello!*"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "hill*"))
	
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*o"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*lo"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*llo"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*ello"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*hello"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "**hello"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "*hello!"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "*elo"))
	
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*hell*"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "***ll***"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "*ih*"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "**la**"))
	
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "he*lo"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "he*llo"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*h*ll***o"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "h*o"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "h*e*l*l*o"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*h*e*l*l*o*"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "he*la"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "h*lla"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "*j****ll*o*"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "h*i"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "*h*e*l*a*"))
	
	### ?+* WILDCARDS ###
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*?"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "?*"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "?*?"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*?*"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "***??"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "?????**"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*????*"))
	
	assert_true(AdvancedConfigFile.is_pattern_match("a", "*?"))
	assert_true(AdvancedConfigFile.is_pattern_match("a", "?*"))
	assert_false(AdvancedConfigFile.is_pattern_match("", "*?"))
	assert_false(AdvancedConfigFile.is_pattern_match("", "*?"))
	assert_false(AdvancedConfigFile.is_pattern_match("a", "?*?"))
	assert_true(AdvancedConfigFile.is_pattern_match("a", "*?*"))
	assert_false(AdvancedConfigFile.is_pattern_match("a", "*??"))
	assert_false(AdvancedConfigFile.is_pattern_match("a", "?????*"))
	assert_false(AdvancedConfigFile.is_pattern_match("a", "**????**"))
	
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "h?*o"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "?*e??o"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "*?ll*"))
	assert_true(AdvancedConfigFile.is_pattern_match("hello", "hell*?*"))
	
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "*?hello"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "h?*el*o"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "h*??a"))
	assert_false(AdvancedConfigFile.is_pattern_match("hello", "??*l*???"))


func test_get_value_by_matching() -> void:
	var cfg := AdvancedConfigFile.new()
	
	# test_image.png
	cfg.set_value("test_image.png", "a", 1)
	cfg.set_value("test_image.png", "b", "hello")
	cfg.set_value("test_image.png", "c", 4.20)
	cfg.set_value("test_image.png", "d", true)
	cfg.set_value("test_image.png", "e", Vector2.ZERO)
	cfg.set_value("test_image.png", "f", Vector3.ONE)
	cfg.set_value("test_image.png", "g", 10)
	cfg.set_value("test_image.png", "h", 3.14)
	
	# ????_image*
	cfg.set_value("????_image*", "a", 2)
	cfg.set_value("????_image*", "b", "hi")
	cfg.set_value("????_image*", "c", 6.69)
	cfg.set_value("????_image*", "d", false)
	cfg.set_value("????_image*", "i", 5)
	cfg.set_value("????_image*", "j", "yo")
	cfg.set_value("????_image*", "k", 4.274)
	cfg.set_value("????_image*", "l", true)
	
	# *.png
	cfg.set_value("*.png", "a", 3)
	cfg.set_value("*.png", "b", "heya")
	cfg.set_value("*.png", "e", Vector2.ONE)
	cfg.set_value("*.png", "f", Vector3.ZERO)
	cfg.set_value("*.png", "i", 7)
	cfg.set_value("*.png", "j", "oh")
	cfg.set_value("*.png", "m", Vector2(1.0, 2.0))
	cfg.set_value("*.png", "n", Vector3(-1.0, 2.0, 0.5))
	
	# *
	cfg.set_value("*", "a", 4)
	cfg.set_value("*", "c", 420.0)
	cfg.set_value("*", "e", -Vector2.ONE)
	cfg.set_value("*", "g", 20)
	cfg.set_value("*", "i", 22)
	cfg.set_value("*", "k", 1024.5)
	cfg.set_value("*", "m", -2.0 * Vector2.ONE)
	cfg.set_value("*", "o", 60)
	
	assert_eq(cfg.get_value_by_matching("test_image.png", "a", 0, true), 1)
	assert_eq(cfg.get_value_by_matching("test_image.png", "b", "", true), "hello")
	assert_eq(cfg.get_value_by_matching("test_image.png", "c", 0.0, true), 4.2)
	assert_eq(cfg.get_value_by_matching("test_image.png", "d", false, true), true)
	assert_eq(cfg.get_value_by_matching("test_image.png", "e", Vector2.ONE, true), Vector2.ZERO)
	assert_eq(cfg.get_value_by_matching("test_image.png", "f", Vector3.ZERO, true), Vector3.ONE)
	assert_eq(cfg.get_value_by_matching("test_image.png", "g", 0, true), 10)
	assert_eq(cfg.get_value_by_matching("test_image.png", "h", 0.0, true), 3.14)
	
	assert_eq(cfg.get_value_by_matching("test_image.png", "i", 0, true), 5)
	assert_eq(cfg.get_value_by_matching("test_image.png", "j", "", true), "yo")
	assert_eq(cfg.get_value_by_matching("test_image.png", "k", 0.0, true), 4.274)
	assert_eq(cfg.get_value_by_matching("test_image.png", "l", false, true), true)
	assert_eq(cfg.get_value_by_matching("test_image.png", "m", Vector2.ONE, true), Vector2(1.0, 2.0))
	assert_eq(cfg.get_value_by_matching("test_image.png", "n", Vector3.ZERO, true), Vector3(-1.0, 2.0, 0.5))
	assert_eq(cfg.get_value_by_matching("test_image.png", "o", 0, true), 60)
	assert_eq(cfg.get_value_by_matching("test_image.png", "p", 12.5, true), 12.5)
	
	# Testing strict and non-strict types.
	assert_eq(cfg.get_value_by_matching("test_image.png", "a", 5, true), 1)
	assert_eq(cfg.get_value_by_matching("test_image.png", "a", 2.7, true), 1.0) # int -> float
	assert_eq(cfg.get_value_by_matching("test_image.png", "a", "wat", true), "wat")
	assert_eq(cfg.get_value_by_matching("test_image.png", "a", true, true), true)
	
	assert_eq(cfg.get_value_by_matching("test_image.png", "a", 10, false), 1)
	assert_eq(cfg.get_value_by_matching("test_image.png", "a", 2.5, false), 1)
	assert_eq(cfg.get_value_by_matching("test_image.png", "a", "hi", false), 1)
	assert_eq(cfg.get_value_by_matching("test_image.png", "a", false, false), 1)
