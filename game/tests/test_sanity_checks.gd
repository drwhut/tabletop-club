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

## Test the [SanityCheck] class.


## These files are placed under user://assets for these tests.
const TEST_FILES := ["test_image.png", "test_text.txt"]


func before_all() -> void:
	gut.p("Creating test files...")
	
	var asset_dir := Directory.new()
	if not asset_dir.dir_exists("user://assets"):
		asset_dir.make_dir("user://assets")
	
	for file_name in TEST_FILES:
		var file_path := "user://assets".plus_file(file_name)
		
		var file := File.new()
		file.open(file_path, File.WRITE)
		file.close()
	
	gut.p("Done creating test files.")


func after_all() -> void:
	gut.p("Removing test files...")
	
	var dir := Directory.new()
	for file_name in TEST_FILES:
		var file_path := "user://assets".plus_file(file_name)
		dir.remove(file_path)
	
	gut.p("Removed test files.")


func test_numeric_checks() -> void:
	# float
	assert_true(SanityCheck.is_valid_float(0.0))
	assert_true(SanityCheck.is_valid_float(1.0))
	assert_true(SanityCheck.is_valid_float(1.618033988749894))
	assert_true(SanityCheck.is_valid_float(-3.14e159))
	
	assert_false(SanityCheck.is_valid_float(INF))
	assert_false(SanityCheck.is_valid_float(-INF))
	assert_false(SanityCheck.is_valid_float(NAN))
	
	# Since everything else is based on floats, just do simple checks.
	
	# Vector2
	assert_true(SanityCheck.is_valid_vector2(Vector2(15.6, 26.9)))
	assert_false(SanityCheck.is_valid_vector2(Vector2(0.0, INF)))
	
	# Rect2
	assert_true(SanityCheck.is_valid_rect2(Rect2(0.0, 0.0, 20.0, 15.0)))
	assert_false(SanityCheck.is_valid_rect2(Rect2(-INF, -INF, INF, INF)))
	
	# Vector3
	assert_true(SanityCheck.is_valid_vector3(Vector3(1.0, 2.0, 3.0)))
	assert_false(SanityCheck.is_valid_vector3(Vector3(1.0, NAN, 3.0)))
	
	# AABB
	assert_true(SanityCheck.is_valid_aabb(AABB(Vector3.ZERO, Vector3.ONE)))
	assert_false(SanityCheck.is_valid_aabb(AABB(Vector3.ZERO,
			Vector3(1.0e100, INF, 1.0e100))))

# TODO: Check every file used for the default asset pack.
func test_resource_checks() -> void:
	# is_valid_res_path
	var PNG := ["png"]
	var RES := ["tres"]
	var TXT := ["txt"]
	
	var ALL := PNG + RES + TXT
	
	# Relative paths are not allowed.
	assert_false(SanityCheck.is_valid_res_path("test_text.txt", TXT))
	assert_false(SanityCheck.is_valid_res_path("test/test_text.txt", TXT))
	assert_false(SanityCheck.is_valid_res_path("../test_image.png", PNG))
	
	# Path must start with res://assets or user://assets.
	assert_false(SanityCheck.is_valid_res_path("res://tabletop_club_logo.png", PNG))
	assert_false(SanityCheck.is_valid_res_path("user://test_image.png", PNG))
	assert_false(SanityCheck.is_valid_res_path("/home/test_text.txt", TXT))
	
	# Path must point to an existing file.
	assert_false(SanityCheck.is_valid_res_path("res://assets/rjj9ws.png", PNG))
	assert_false(SanityCheck.is_valid_res_path("user://assets/fnj27.txt", TXT))
	
	# Path must have a valid extension.
	assert_false(SanityCheck.is_valid_res_path("res://assets/custom_value.gd", ALL))
	assert_false(SanityCheck.is_valid_res_path("user://assets/test_image.png", TXT))
	assert_false(SanityCheck.is_valid_res_path("user://assets/test_text.txt", PNG))
	
	# Path must not contain ".."
	assert_false(SanityCheck.is_valid_res_path(
			"res://assets/entry/../default_physics_material.tres", RES))
	assert_false(SanityCheck.is_valid_res_path(
			"user://assets/ignore/../text_image.png", PNG))
	
	# Valid checks.
	# TODO: Add more asserts once more files have been placed under res://assets.
	assert_true(SanityCheck.is_valid_res_path("user://assets/test_text.txt", TXT))
	assert_true(SanityCheck.is_valid_res_path("user://assets/test_image.png", ALL))
