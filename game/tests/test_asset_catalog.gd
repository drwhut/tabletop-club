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

## Test the [AssetCatalog] class.


## The internal directory for the empty asset pack.
const EMPTY_PACK_PATH := "user://assets/empty_pack"

## The internal directory for the test asset pack.
const TEST_PACK_PATH := "user://assets/test_pack"


func test_asset_catalog() -> void:
	var empty_pack_dir := Directory.new()
	if not empty_pack_dir.dir_exists(EMPTY_PACK_PATH):
		empty_pack_dir.make_dir_recursive(EMPTY_PACK_PATH)
	assert_true(empty_pack_dir.dir_exists(EMPTY_PACK_PATH))
	
	# Check that initial pack catalogs are created for internal directories.
	var catalog := AssetCatalog.new()
	var empty_pack_catalog := catalog.get_pack_catalog("empty_pack")
	assert_not_null(empty_pack_catalog)
	assert_eq(empty_pack_catalog.pack_name, "empty_pack")
	
	# Check that by scanning in packs, internal directories are created.
	empty_pack_dir.remove(EMPTY_PACK_PATH)
	assert_false(empty_pack_dir.dir_exists(EMPTY_PACK_PATH))
	catalog = AssetCatalog.new()
	assert_null(catalog.get_pack_catalog("empty_pack"))
	
	var test_dir := Directory.new()
	assert_eq(test_dir.open("res://tests"), OK)
	catalog.scan_dir_for_packs(test_dir)
	
	assert_true(empty_pack_dir.dir_exists(EMPTY_PACK_PATH))
	assert_not_null(catalog.get_pack_catalog("empty_pack"))
	
	# Check that the packs are imported.
	var pack_list := catalog.import_all()
	_check_pack_list(pack_list)
	
	# Check that rogue files are removed.
	var rogue_file_path := TEST_PACK_PATH.plus_file("pieces/rogue.obj")
	var rogue_file := File.new()
	rogue_file.open(rogue_file_path, File.WRITE)
	rogue_file.store_string("# Hehe, I'm in danger!")
	rogue_file.close()
	assert_file_exists(rogue_file_path)
	catalog.clean_rogue_files()
	assert_file_does_not_exist(rogue_file_path)
	
	# Clean the entire internal directory at the end of the test.
	var test_card_path := TEST_PACK_PATH.plus_file("cards/test_card.png")
	assert_file_exists(test_card_path)
	catalog = AssetCatalog.new()
	catalog.clean_rogue_files()
	assert_file_does_not_exist(test_card_path)
	
	# Remove the internal 'empty_pack' directory, since there should be no files
	# or directories in there.
	empty_pack_dir.remove(EMPTY_PACK_PATH)
	assert_false(empty_pack_dir.dir_exists(EMPTY_PACK_PATH))


func test_asset_catalog_interactive() -> void:
	var interactive := AssetCatalogInteractive.new()
	interactive.start("res://tests")
	assert_false(interactive.is_done())
	var pack_list := interactive.get_packs() # Blocks the main thread.
	assert_true(interactive.is_done())
	_check_pack_list(pack_list)
	
	# Clean the entire internal directory at the end of the test.
	var test_d6_path := TEST_PACK_PATH.plus_file("dice/d6/test_d6.obj")
	assert_file_exists(test_d6_path)
	var catalog := AssetCatalog.new()
	catalog.clean_rogue_files()
	assert_file_does_not_exist(test_d6_path)
	
	# Remove the internal 'empty_pack' directory, since there should be no files
	# or directories in there.
	var empty_pack_dir := Directory.new()
	empty_pack_dir.remove(EMPTY_PACK_PATH)
	assert_false(empty_pack_dir.dir_exists(EMPTY_PACK_PATH))


func _check_pack_list(pack_list: Array) -> void:
	gut.p("Checking asset packs were imported correctly...")
	
	assert_eq(pack_list.size(), 2)
	var num_empty_pack := 0
	var num_test_pack := 0
	for pack in pack_list:
		if pack.id == "empty_pack":
			assert_eq(pack.get_entry_count(), 0)
			num_empty_pack += 1
		elif pack.id == "test_pack":
			assert_eq(pack.get_entry_count(), 33)
			num_test_pack += 1
		else:
			fail_test("Unexpected pack '%s'" % pack.id)
	
	assert_eq(num_empty_pack, 1)
	assert_eq(num_test_pack, 1)
