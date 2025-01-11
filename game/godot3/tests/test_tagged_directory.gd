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

## Test the [TaggedDirectory] class.


## The directory to use to test [TaggedDirectory].
const TAGGED_DIR_TEST_LOCATION := "user://assets/__tagged_dir__"


func test_tagged_directory() -> void:
	var test_dir := Directory.new()
	if not test_dir.dir_exists(TAGGED_DIR_TEST_LOCATION):
		test_dir.make_dir_recursive(TAGGED_DIR_TEST_LOCATION)
	
	# We expect there to be no files or directories at the start of the test.
	test_dir.open(TAGGED_DIR_TEST_LOCATION)
	test_dir.list_dir_begin(true, false)
	assert_eq(test_dir.get_next(), "")
	test_dir.list_dir_end()
	
	var tagged_dir := TaggedDirectory.new("test") # Must be an absoute path.
	assert_eq(tagged_dir.dir_path, "")
	tagged_dir.dir_path = "user://logs" # Must begin with user://assets
	assert_eq(tagged_dir.dir_path, "")
	tagged_dir.dir_path = "user://assets/.." # Cannot contain ".."
	assert_eq(tagged_dir.dir_path, "")
	tagged_dir.dir_path = "user://assets/__0123456789__" # Directory must exist.
	assert_eq(tagged_dir.dir_path, "")
	tagged_dir.dir_path = TAGGED_DIR_TEST_LOCATION
	assert_eq(tagged_dir.dir_path, TAGGED_DIR_TEST_LOCATION)
	
	# If we failed to open the directory, then stop now to prevent the res://
	# directory from getting cleaned.
	if tagged_dir.dir_path.empty():
		fail_test("Failed to open directory: '%s'" % TAGGED_DIR_TEST_LOCATION)
		return
	
	assert_eq_deep(tagged_dir.get_tagged(), [])
	
	var file := File.new()
	var a_path := TAGGED_DIR_TEST_LOCATION.plus_file("a.txt")
	var b_path := TAGGED_DIR_TEST_LOCATION.plus_file("b.txt")
	var c_path := TAGGED_DIR_TEST_LOCATION.plus_file("c.txt")
	
	file.open(a_path, File.WRITE)
	file.store_string("a")
	file.close()
	file.open(b_path, File.WRITE)
	file.store_string("b")
	file.close()
	
	tagged_dir.tag("test.txt", false) # File must exist for it to be tagged.
	assert_false(tagged_dir.is_tagged("test.txt"))
	
	tagged_dir.tag("a.txt", true)
	assert_true(tagged_dir.is_tagged("a.txt"))
	assert_false(tagged_dir.is_tagged("b.txt"))
	assert_eq_deep(tagged_dir.get_tagged(), ["a.txt"])
	
	assert_true(tagged_dir.is_new("a.txt"))
	assert_true(tagged_dir.is_changed("a.txt"))
	assert_eq(tagged_dir.get_file_meta("a.txt").new_md5, "0cc175b9c0f1b6a831c399e269772661")
	assert_eq(tagged_dir.get_file_meta("a.txt").old_md5, "")
	
	# Tagged files may not store metadata. This just prevents them from being
	# deleted.
	tagged_dir.tag("b.txt", false)
	assert_true(tagged_dir.is_tagged("b.txt"))
	assert_eq_deep(tagged_dir.get_tagged(), ["a.txt", "b.txt"])
	assert_eq(tagged_dir.get_file_meta("b.txt").new_md5, "")
	assert_eq(tagged_dir.get_file_meta("b.txt").old_md5, "")
	
	tagged_dir.tag("b.txt", true)
	assert_true(tagged_dir.is_new("b.txt"))
	assert_true(tagged_dir.is_changed("b.txt"))
	assert_eq(tagged_dir.get_file_meta("b.txt").new_md5, "92eb5ffee6ae2fec3ad71c777531578f")
	assert_eq(tagged_dir.get_file_meta("b.txt").old_md5, "")
	
	file.open(b_path, File.WRITE)
	file.store_string("d")
	file.close()
	file.open(c_path, File.WRITE)
	file.store_string("c")
	file.close()
	
	tagged_dir.tag("a.txt", true)
	tagged_dir.tag("b.txt", true)
	tagged_dir.tag("c.txt", true)
	assert_true(tagged_dir.is_tagged("a.txt"))
	assert_true(tagged_dir.is_tagged("b.txt"))
	assert_true(tagged_dir.is_tagged("c.txt"))
	assert_eq_deep(tagged_dir.get_tagged(), ["a.txt", "b.txt", "c.txt"])
	
	assert_false(tagged_dir.is_new("a.txt"))
	assert_false(tagged_dir.is_changed("a.txt"))
	assert_eq(tagged_dir.get_file_meta("a.txt").new_md5, "0cc175b9c0f1b6a831c399e269772661")
	assert_eq(tagged_dir.get_file_meta("a.txt").old_md5, "0cc175b9c0f1b6a831c399e269772661")
	
	assert_false(tagged_dir.is_new("b.txt"))
	assert_true(tagged_dir.is_changed("b.txt"))
	assert_eq(tagged_dir.get_file_meta("b.txt").new_md5, "8277e0910d750195b448797616e091ad")
	assert_eq(tagged_dir.get_file_meta("b.txt").old_md5, "92eb5ffee6ae2fec3ad71c777531578f")
	
	assert_true(tagged_dir.is_new("c.txt"))
	assert_true(tagged_dir.is_changed("c.txt"))
	assert_eq(tagged_dir.get_file_meta("c.txt").new_md5, "4a8a08f09d37b73795649038408b5f33")
	assert_eq(tagged_dir.get_file_meta("c.txt").old_md5, "")
	
	tagged_dir.untag("a.txt")
	assert_false(tagged_dir.is_tagged("a.txt"))
	assert_eq_deep(tagged_dir.get_tagged(), ["b.txt", "c.txt"])
	
	tagged_dir.tag("a.txt", true)
	assert_true(tagged_dir.is_tagged("a.txt"))
	assert_eq_deep(tagged_dir.get_tagged(), ["b.txt", "c.txt", "a.txt"])
	
	# Untagging a file does not remove the metadata stored about it.
	assert_false(tagged_dir.is_new("a.txt"))
	assert_false(tagged_dir.is_changed("a.txt"))
	assert_eq(tagged_dir.get_file_meta("a.txt").new_md5, "0cc175b9c0f1b6a831c399e269772661")
	assert_eq(tagged_dir.get_file_meta("a.txt").old_md5, "0cc175b9c0f1b6a831c399e269772661")
	
	tagged_dir.untag("b.txt")
	assert_false(tagged_dir.is_tagged("b.txt"))
	assert_eq_deep(tagged_dir.get_tagged(), ["c.txt", "a.txt"])
	
	tagged_dir.remove_untagged()
	assert_true(test_dir.file_exists(a_path))
	assert_false(test_dir.file_exists(b_path))
	assert_true(test_dir.file_exists(c_path))
	
	file.open(b_path, File.WRITE)
	file.store_string("B")
	file.close()
	
	tagged_dir.tag("b.txt", true)
	assert_true(tagged_dir.is_tagged("b.txt"))
	assert_eq_deep(tagged_dir.get_tagged(), ["c.txt", "a.txt", "b.txt"])
	
	# Removing all untagged files DOES remove their metadata, if it exists.
	assert_true(tagged_dir.is_new("b.txt"))
	assert_true(tagged_dir.is_changed("b.txt"))
	assert_eq(tagged_dir.get_file_meta("b.txt").new_md5, "9d5ed678fe57bcca610140957afab571")
	assert_eq(tagged_dir.get_file_meta("b.txt").old_md5, "")
	
	# Clean the test directory after we are done. By untagging the files and
	# removing them, we also remove the stored metadata files as well.
	tagged_dir.untag("a.txt")
	tagged_dir.untag("b.txt")
	tagged_dir.untag("c.txt")
	tagged_dir.remove_untagged()
	test_dir.remove(TAGGED_DIR_TEST_LOCATION)
	assert_false(test_dir.dir_exists(TAGGED_DIR_TEST_LOCATION))
