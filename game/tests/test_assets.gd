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

## Test scripts related to custom assets.


## The directory to use to test [TaggedDirectory].
const TAGGED_DIR_TEST_LOCATION := "user://assets/__tagged_dir__"

## The directory to use to test [AssetPackTypeCatalog].
const TYPE_CATALOG_TEST_LOCATION := "user://assets/__type_catalog__"


func before_all() -> void:
	var asset_dir := Directory.new()
	if not asset_dir.dir_exists("user://assets"):
		asset_dir.make_dir("user://assets")


func test_asset_entries() -> void:
	var entry := AssetEntry.new()
	
	# id
	assert_eq(entry.id, "_")
	entry.id = "Test"
	assert_eq(entry.id, "Test")
	entry.id = "   Test   "
	assert_eq(entry.id, "Test")
	entry.id = "Test\n    "
	assert_eq(entry.id, "Test")
	entry.id = "" # Cannot be empty.
	assert_eq(entry.id, "Test")
	entry.id = "    \n\n  " # Cannot be empty.
	assert_eq(entry.id, "Test")
	entry.id = "Test/Subtest" # Must be a valid file name.
	assert_eq(entry.id, "Test")
	entry.id = "Test?" # Must be a valid file name.
	assert_eq(entry.id, "Test")
	entry.id = "Test*" # Must be a valid file name.
	assert_eq(entry.id, "Test")
	
	# name
	assert_eq(entry.name, "Test")
	entry.name = "Test2"
	assert_eq(entry.name, "Test2")
	entry.name = ""
	assert_eq(entry.name, "Test")
	entry.name = "    \n\t  "
	assert_eq(entry.name, "Test")
	entry.name = "/Test/" # Must be a valid file name.
	assert_eq(entry.name, "Test")
	
	# pack, type, get_path
	assert_eq(entry.pack, "TabletopClub")
	assert_eq(entry.type, "")
	assert_eq(entry.get_path(), "")
	
	entry.pack = "PackA"
	assert_eq(entry.pack, "PackA")
	entry.pack = "PackA/SubPack" # No '/' allowed in pack.
	assert_eq(entry.pack, "PackA")
	assert_eq(entry.get_path(), "")
	
	entry.type = "cards"
	assert_eq(entry.get_path(), "PackA/cards/Test")
	entry.type = "dice"
	assert_eq(entry.get_path(), "PackA/dice/Test")
	entry.pack = "PackB"
	assert_eq(entry.get_path(), "PackB/dice/Test")


func test_asset_packs() -> void:
	var pack = AssetPack.new()
	assert_eq(pack.id, "_")
	assert_eq(pack.name, "_")
	
	for property in ["id", "name"]:
		# Similar checks to AssetEntry.
		pack.set(property, "MyPack")
		assert_eq(pack.get(property), "MyPack")
		pack.set(property, "   MyPack   \n   ")
		assert_eq(pack.get(property), "MyPack")
		pack.set(property, "   ")
		assert_eq(pack.get(property), "MyPack")
		pack.set(property, "My/Pack")
		assert_eq(pack.get(property), "MyPack")
	
	assert_eq(pack.origin, "")
	assert_true(pack.is_bundled())
	pack.origin = "res://assets"
	assert_eq(pack.origin, "res://assets")
	assert_false(pack.is_bundled())
	pack.origin = "res://dhhwby" # origin must be an existing directory.
	assert_eq(pack.origin, "res://assets")
	
	var a = AssetEntry.new()
	a.id = "A"
	var b = AssetEntry.new()
	b.id = "B"
	
	assert_true(pack.is_empty())
	pack.add_entry("pieces", a)
	assert_false(pack.is_empty())
	assert_true(pack.has_entry("pieces", "A"))
	assert_eq(pack.get_entry_count(), 1)
	assert_eq(pack.get_entry("pieces", "A"), a)
	
	assert_eq(a.pack, "MyPack")
	assert_eq(a.type, "pieces")
	assert_eq(a.get_path(), "MyPack/pieces/A")
	
	pack.remove_entry("pieces", 0)
	assert_true(pack.is_empty())
	assert_eq(pack.get_entry_count(), 0)
	assert_false(pack.has_entry("pieces", "A"))
	
	pack.add_entry("cards", b)
	assert_eq(pack.get_entry_count(), 1)
	assert_true(pack.has_entry("cards", "B"))
	assert_false(pack.has_entry("pieces", "B"))
	
	assert_eq(b.pack, "MyPack")
	assert_eq(b.type, "cards")
	assert_eq(b.get_path(), "MyPack/cards/B")
	
	assert_eq_deep(pack.get_type("cards"), [b])
	pack.add_entry("cards", a)
	assert_eq_deep(pack.get_type("cards"), [a, b])
	assert_eq_deep(pack.get_all(), {
		"boards": [],
		"cards": [a, b],
		"containers": [],
		"dice": [],
		"games": [],
		"music": [],
		"pieces": [],
		"skyboxes": [],
		"sounds": [],
		"speakers": [],
		"stacks": [],
		"tables": [],
		"templates": [],
		"timers": [],
		"tokens": [],
	})
	
	pack.erase_entry("cards", "A")
	pack.erase_entry("cards", "B")
	assert_true(pack.is_empty())
	assert_false(pack.has_entry("cards", "B"))
	
	var b_temp = AssetEntry.new()
	b_temp.id = "B"
	b_temp.temp = true
	
	var c_temp = AssetEntry.new()
	c_temp.id = "C"
	c_temp.temp = true
	
	pack.add_entry("tables", c_temp)
	pack.add_entry("tables", a)
	pack.add_entry("tables", b)
	assert_eq(pack.get_entry_count(), 3)
	assert_eq_deep(pack.get_type("tables"), [a, b, c_temp])
	assert_eq_deep(pack.get_removed_entries(), [])
	assert_eq_deep(pack.get_replaced_entries(), [])
	
	pack.clear_temp_entries()
	assert_eq(pack.get_entry_count(), 2)
	assert_eq_deep(pack.get_type("tables"), [a, b])
	
	pack.add_entry("tables", b_temp)
	assert_eq(pack.get_entry_count(), 2)
	assert_eq_deep(pack.get_type("tables"), [a, b_temp])
	assert_eq_deep(pack.get_removed_entries(), [])
	assert_eq_deep(pack.get_replaced_entries(), [b])
	
	# Cannot temporarily remove temporary entries.
	pack.remove_entry("tables", 1, true)
	assert_eq_deep(pack.get_type("tables"), [a, b_temp])
	
	pack.clear_temp_entries()
	assert_eq(pack.get_entry_count(), 2)
	assert_eq_deep(pack.get_type("tables"), [a, b])
	assert_eq_deep(pack.get_removed_entries(), [])
	assert_eq_deep(pack.get_replaced_entries(), [])
	
	pack.erase_entry("tables", "A", true)
	assert_eq(pack.get_entry_count(), 1)
	assert_eq_deep(pack.get_type("tables"), [b])
	assert_eq_deep(pack.get_removed_entries(), [a])
	assert_eq_deep(pack.get_replaced_entries(), [])
	
	pack.clear_temp_entries()
	assert_eq(pack.get_entry_count(), 2)
	assert_eq_deep(pack.get_type("tables"), [a, b])
	assert_eq_deep(pack.get_removed_entries(), [])
	assert_eq_deep(pack.get_replaced_entries(), [])
	
	pack.add_entry("tables", c_temp)
	pack.add_entry("tables", b_temp)
	pack.erase_entry("tables", "A", true)
	assert_eq(pack.get_entry_count(), 2)
	assert_eq_deep(pack.get_type("tables"), [b_temp, c_temp])
	assert_eq_deep(pack.get_removed_entries(), [a])
	assert_eq_deep(pack.get_replaced_entries(), [b])
	
	pack.clear_temp_entries()
	assert_eq(pack.get_entry_count(), 2)
	assert_eq_deep(pack.get_type("tables"), [a, b])
	assert_eq_deep(pack.get_removed_entries(), [])
	assert_eq_deep(pack.get_replaced_entries(), [])
	
	pack.clear_all_entries()
	assert_true(pack.is_empty())
	
	pack.add_entry("?????", a)
	assert_true(pack.is_empty())
	assert_true(pack.get_type("?????").empty())


var _asset_db_content_changed_flag = false

func test_asset_db() -> void:
	AssetDB.connect("content_changed", self, "_on_AssetDB_content_changed")
	
	var a := AssetEntry.new()
	a.id = "A"
	var b := AssetEntry.new()
	b.id = "B"
	var c := AssetEntry.new()
	c.id = "C"
	var d := AssetEntry.new()
	d.id = "D"
	var e := AssetEntry.new()
	e.id = "E"
	
	var pack_1 := AssetPack.new()
	pack_1.id = "Pack1"
	pack_1.add_entry("pieces", a)
	pack_1.add_entry("pieces", b)
	pack_1.add_entry("cards", c)
	
	var pack_2 := AssetPack.new()
	pack_2.id = "Pack2"
	pack_2.add_entry("pieces", d)
	pack_2.add_entry("cards", e)
	
	assert_eq(AssetDB.get_entry_count(), 0)
	assert_eq_deep(AssetDB.get_all_entries(), [])
	assert_eq_deep(AssetDB.get_all_packs(), [])
	
	AssetDB.add_pack(pack_1)
	assert_eq(AssetDB.get_entry_count(), 0) # Not commited yet.
	assert_eq_deep(AssetDB.get_all_entries(), []) # Not commited yet.
	assert_eq_deep(AssetDB.get_all_packs(), [pack_1])
	assert_true(AssetDB.has_pack("Pack1"))
	assert_eq(AssetDB.get_pack("Pack1"), pack_1)
	assert_false(AssetDB.has_pack("Pack2"))
	assert_eq(AssetDB.get_pack("Pack2"), null)
	
	AssetDB.add_pack(pack_2)
	assert_eq_deep(AssetDB.get_all_packs(), [pack_1, pack_2])
	assert_true(AssetDB.has_pack("Pack1"))
	assert_eq(AssetDB.get_pack("Pack1"), pack_1)
	assert_true(AssetDB.has_pack("Pack2"))
	assert_eq(AssetDB.get_pack("Pack2"), pack_2)
	
	assert_false(AssetDB.is_path_in_cache("Pack1/pieces/A"))
	assert_false(AssetDB.is_path_in_cache("Pack1/pieces/B"))
	assert_false(AssetDB.is_path_in_cache("Pack1/cards/C"))
	assert_false(AssetDB.is_path_in_cache("Pack2/pieces/D"))
	assert_false(AssetDB.is_path_in_cache("Pack2/cards/E"))
	assert_eq(AssetDB.get_entry("Pack1/pieces/A"), a)
	assert_eq(AssetDB.get_entry("Pack1/pieces/B"), b)
	assert_eq(AssetDB.get_entry("Pack1/cards/C"), c)
	assert_eq(AssetDB.get_entry("Pack2/pieces/D"), d)
	assert_eq(AssetDB.get_entry("Pack2/cards/E"), e)
	
	assert_eq(AssetDB.get_entry("Pack2/cards/C"), null)
	assert_eq(AssetDB.get_entry("Pack1/pieces/D"), null)
	
	AssetDB.commit_changes()
	assert_true(_asset_db_content_changed_flag)
	_asset_db_content_changed_flag = false
	
	assert_eq(AssetDB.get_entry_count(), 5)
	assert_eq_deep(AssetDB.get_all_entries(), [c, a, b, e, d])
	assert_eq_deep(AssetDB.get_all_packs(), [pack_1, pack_2])
	
	assert_true(AssetDB.is_path_in_cache("Pack1/pieces/A"))
	assert_true(AssetDB.is_path_in_cache("Pack1/pieces/B"))
	assert_true(AssetDB.is_path_in_cache("Pack1/cards/C"))
	assert_true(AssetDB.is_path_in_cache("Pack2/pieces/D"))
	assert_true(AssetDB.is_path_in_cache("Pack2/cards/E"))
	assert_eq(AssetDB.get_entry("Pack1/pieces/A"), a)
	assert_eq(AssetDB.get_entry("Pack1/pieces/B"), b)
	assert_eq(AssetDB.get_entry("Pack1/cards/C"), c)
	assert_eq(AssetDB.get_entry("Pack2/pieces/D"), d)
	assert_eq(AssetDB.get_entry("Pack2/cards/E"), e)
	
	assert_false(AssetDB.is_path_in_cache("Pack2/cards/C"))
	assert_false(AssetDB.is_path_in_cache("Pack1/pieces/D"))
	assert_eq(AssetDB.get_entry("Pack2/cards/C"), null)
	assert_eq(AssetDB.get_entry("Pack1/pieces/D"), null)
	
	assert_eq_deep(AssetDB.get_all_entries("pieces"), [a, b, d])
	assert_eq_deep(AssetDB.get_all_entries("cards"), [c, e])
	assert_eq_deep(AssetDB.get_all_entries("dice"), [])
	
	AssetDB.remove_pack("Pack2")
	assert_eq(AssetDB.get_entry_count(), 5) # Not commited.
	assert_true(AssetDB.has_pack("Pack1"))
	assert_false(AssetDB.has_pack("Pack2"))
	assert_true(AssetDB.is_path_in_cache("Pack2/pieces/D"))
	assert_true(AssetDB.is_path_in_cache("Pack2/cards/E"))
	
	AssetDB.commit_changes()
	assert_true(_asset_db_content_changed_flag)
	_asset_db_content_changed_flag = false
	
	assert_eq(AssetDB.get_entry_count(), 3)
	assert_false(AssetDB.is_path_in_cache("Pack2/pieces/D"))
	assert_false(AssetDB.is_path_in_cache("Pack2/cards/E"))
	
	var b_temp = AssetEntry.new()
	b_temp.id = "B"
	b_temp.temp = true
	
	pack_1.add_entry("pieces", b_temp)
	pack_1.erase_entry("cards", "C", true)
	d.temp = true
	e.temp = true
	
	AssetDB.add_pack(pack_2)
	AssetDB.commit_changes()
	assert_true(_asset_db_content_changed_flag)
	_asset_db_content_changed_flag = false
	
	assert_eq(AssetDB.get_entry_count(), 4)
	assert_eq_deep(AssetDB.get_all_entries(), [a, b_temp, e, d])
	assert_eq_deep(AssetDB.get_all_packs(), [pack_1, pack_2])
	
	assert_true(AssetDB.is_path_in_cache("Pack1/pieces/A"))
	assert_true(AssetDB.is_path_in_cache("Pack1/pieces/B"))
	assert_false(AssetDB.is_path_in_cache("Pack1/cards/C"))
	assert_true(AssetDB.is_path_in_cache("Pack2/pieces/D"))
	assert_true(AssetDB.is_path_in_cache("Pack2/cards/E"))
	assert_eq(AssetDB.get_entry("Pack1/pieces/A"), a)
	assert_eq(AssetDB.get_entry("Pack1/pieces/B"), b_temp)
	assert_eq(AssetDB.get_entry("Pack1/cards/C"), null)
	assert_eq(AssetDB.get_entry("Pack2/pieces/D"), d)
	assert_eq(AssetDB.get_entry("Pack2/cards/E"), e)
	
	AssetDB.revert_temp_changes()
	assert_true(_asset_db_content_changed_flag)
	_asset_db_content_changed_flag = false
	
	assert_eq(AssetDB.get_entry_count(), 3)
	assert_eq_deep(AssetDB.get_all_entries(), [c, a, b])
	assert_eq_deep(AssetDB.get_all_packs(), [pack_1])
	
	assert_true(AssetDB.is_path_in_cache("Pack1/pieces/A"))
	assert_true(AssetDB.is_path_in_cache("Pack1/pieces/B"))
	assert_true(AssetDB.is_path_in_cache("Pack1/cards/C"))
	assert_false(AssetDB.is_path_in_cache("Pack2/pieces/D"))
	assert_false(AssetDB.is_path_in_cache("Pack2/cards/E"))
	assert_eq(AssetDB.get_entry("Pack1/pieces/A"), a)
	assert_eq(AssetDB.get_entry("Pack1/pieces/B"), b)
	assert_eq(AssetDB.get_entry("Pack1/cards/C"), c)
	assert_eq(AssetDB.get_entry("Pack2/pieces/D"), null)
	assert_eq(AssetDB.get_entry("Pack2/cards/E"), null)
	
	AssetDB.revert_temp_changes()
	assert_false(_asset_db_content_changed_flag) # No changes made.
	
	AssetDB.disconnect("content_changed", self, "_on_AssetDB_content_changed")


func test_tagged_directory() -> void:
	var test_dir := Directory.new()
	if not test_dir.dir_exists(TAGGED_DIR_TEST_LOCATION):
		test_dir.make_dir(TAGGED_DIR_TEST_LOCATION)
	
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
	
	# Since the file was untagged, any stored metadata should have been deleted.
	assert_true(tagged_dir.is_new("a.txt"))
	assert_true(tagged_dir.is_changed("a.txt"))
	assert_eq(tagged_dir.get_file_meta("a.txt").new_md5, "0cc175b9c0f1b6a831c399e269772661")
	assert_eq(tagged_dir.get_file_meta("a.txt").old_md5, "")
	
	tagged_dir.untag("b.txt")
	assert_false(tagged_dir.is_tagged("b.txt"))
	assert_eq_deep(tagged_dir.get_tagged(), ["c.txt", "a.txt"])
	
	tagged_dir.remove_untagged()
	assert_true(test_dir.file_exists(a_path))
	assert_false(test_dir.file_exists(b_path))
	assert_true(test_dir.file_exists(c_path))
	
	# Clean the test directory after we are done. Untagging the files removes
	# the metadata files, which is required for the test to work properly.
	tagged_dir.untag("a.txt")
	tagged_dir.untag("c.txt")
	tagged_dir.remove_untagged()
	test_dir.remove(TAGGED_DIR_TEST_LOCATION)
	assert_false(test_dir.dir_exists(TAGGED_DIR_TEST_LOCATION))


func test_type_catalog() -> void:
	var test_dir := Directory.new()
	if not test_dir.dir_exists(TYPE_CATALOG_TEST_LOCATION):
		test_dir.make_dir(TYPE_CATALOG_TEST_LOCATION)
	
	# We've already tested TaggedDirectory, so we don't need to check if the
	# directory is empty.
	var catalog := AssetPackTypeCatalog.new(TYPE_CATALOG_TEST_LOCATION)
	var card_dir := "res://tests/test_pack/cards"
	var piece_dir := "res://tests/test_pack/pieces"
	
	# If the directory failed to open, then stop now to prevent cleaning the
	# res:// directory.
	if catalog.dir_path.empty():
		fail_test("Failed to open directory: '%s'" % TYPE_CATALOG_TEST_LOCATION)
		return
	
	### COLLECTING ASSETS ###
	
	assert_eq_deep(catalog.collect_audio(piece_dir), [])
	assert_eq_deep(catalog.get_tagged(), [])
	assert_eq_deep(catalog.collect_text_templates(piece_dir), [])
	assert_eq_deep(catalog.get_tagged(), [])
	
	assert_eq_deep(catalog.collect_textures(piece_dir), ["white_texture.png"])
	assert_eq_deep(catalog.get_tagged(), ["white_texture.png"])
	var white_tex_path := TYPE_CATALOG_TEST_LOCATION.plus_file("white_texture.png")
	assert_file_exists(white_tex_path)
	
	assert_eq_deep(catalog.collect_support(piece_dir), ["piece_mat.mtl"])
	assert_eq_deep(catalog.get_tagged(), ["white_texture.png", "piece_mat.mtl"])
	assert_file_exists(TYPE_CATALOG_TEST_LOCATION.plus_file("piece_mat.mtl"))
	
	# The order that files are scanned in can vary from platform to platform,
	# so we can't rely on the order of the arrays here.
	var collected_files := catalog.collect_scenes(piece_dir)
	assert_eq(collected_files.size(), 2)
	assert_true(collected_files.has("red_piece.obj"))
	assert_true(collected_files.has("white_piece.obj"))
	var tagged_files := catalog.get_tagged()
	assert_eq(tagged_files.size(), 4)
	assert_eq(tagged_files[0], "white_texture.png")
	assert_eq(tagged_files[1], "piece_mat.mtl")
	assert_true(tagged_files.has("red_piece.obj"))
	assert_true(tagged_files.has("white_piece.obj"))
	var red_path := TYPE_CATALOG_TEST_LOCATION.plus_file("red_piece.obj")
	var white_path := TYPE_CATALOG_TEST_LOCATION.plus_file("white_piece.obj")
	assert_file_exists(red_path)
	assert_file_exists(white_path)
	
	# Make sure each test is consistent by ensuring that the catalog identifies
	# the files as being new, so that we can check how importing changes when
	# the files are either changed, or stay the same.
	assert_true(catalog.is_new("white_texture.png"))
	assert_true(catalog.is_new("piece_mat.mtl"))
	assert_true(catalog.is_new("red_piece.obj"))
	assert_true(catalog.is_new("white_piece.obj"))
	
	### IMPORTING ASSETS ###
	
	var red_scn := "user://.import/red_piece.obj-%s.scn" % red_path.md5_text()
	var white_scn := "user://.import/white_piece.obj-%s.scn" % white_path.md5_text()
	var white_stex := "user://.import/white_texture.png-%s.stex" % white_tex_path.md5_text()
	
	# To start with, forcefully import each file to ensure that the resources
	# exist and are up-to-date for the rest of the test.
	assert_false(catalog.is_imported("white_texture.png"))
	assert_false(catalog.is_imported("white_piece.obj"))
	assert_false(catalog.is_imported("red_piece.obj"))
	assert_eq(catalog.import_file("white_texture.png"), OK)
	assert_eq(catalog.import_file("white_piece.obj"), OK)
	assert_eq(catalog.import_file("red_piece.obj"), OK)
	assert_true(catalog.is_imported("white_texture.png"))
	assert_true(catalog.is_imported("white_piece.obj"))
	assert_true(catalog.is_imported("red_piece.obj"))
	
	assert_file_exists(white_stex)
	assert_true(catalog.is_tagged("white_texture.png.import"))
	assert_true(ResourceLoader.exists(white_tex_path))
	_check_texture(white_tex_path, Color.white)
	
	assert_file_exists(white_scn)
	assert_true(catalog.is_tagged("white_piece.obj.import"))
	assert_true(catalog.is_tagged("white_mat.material"))
	assert_true(catalog.is_new("white_texture.png")) # Check it was not re-tagged.
	assert_true(ResourceLoader.exists(white_path))
	_check_scene(white_path, white_tex_path, Color.white)
	
	assert_file_exists(red_scn)
	assert_true(catalog.is_tagged("red_piece.obj.import"))
	assert_true(catalog.is_tagged("red_mat.material"))
	assert_true(ResourceLoader.exists(red_path))
	_check_scene(red_path, "", Color.red)
	
	# Add a new file to see if it is imported automatically.
	assert_eq_deep(catalog.collect_textures(card_dir), ["black_texture.png"])
	assert_true(catalog.is_tagged("black_texture.png"))
	assert_true(catalog.is_new("black_texture.png"))
	assert_false(catalog.is_imported("black_texture.png"))
	
	var black_tex_path := TYPE_CATALOG_TEST_LOCATION.plus_file("black_texture.png")
	var black_stex := "user://.import/black_texture.png-%s.stex" % black_tex_path.md5_text()
	assert_file_exists(black_tex_path)
	
	# Change an existing file to see if it is imported automatically.
	var white_file := File.new()
	white_file.open(white_path, File.READ_WRITE)
	white_file.seek_end()
	white_file.store_string("\nf 3 2 1")
	white_file.close()
	
	catalog.tag("white_piece.obj", true)
	assert_true(catalog.is_changed("white_piece.obj"))
	
	# Keep one file the same to see if importing is skipped.
	catalog.tag("white_texture.png", true)
	assert_false(catalog.is_new("white_texture.png"))
	assert_false(catalog.is_changed("white_texture.png"))
	
	var modified_check := File.new()
	var white_stex_modified_old := modified_check.get_modified_time(white_stex)
	var white_scn_modified_old := modified_check.get_modified_time(white_scn)
	
	gut.p("Waiting for UNIX timestamp to increment before continuing...")
	OS.delay_msec(1000)
	catalog.import_tagged()
	
	var white_stex_modified_new := modified_check.get_modified_time(white_stex)
	var white_scn_modified_new := modified_check.get_modified_time(white_scn)
	
	assert_file_exists(black_stex)
	assert_true(catalog.is_imported("black_texture.png"))
	assert_true(catalog.is_tagged("black_texture.png.import"))
	assert_true(ResourceLoader.exists(black_tex_path))
	_check_texture(black_tex_path, Color.black)
	
	assert_ne(white_scn_modified_old, white_scn_modified_new)
	assert_eq(white_stex_modified_old, white_stex_modified_new)
	
	# Make sure that assets are re-imported if generated files are missing, even
	# if the file is tagged as unchanged.
	catalog.tag("red_piece.obj", true)
	assert_false(catalog.is_new("red_piece.obj"))
	assert_false(catalog.is_changed("red_piece.obj"))
	
	catalog.tag("white_piece.obj", true)
	assert_false(catalog.is_new("white_piece.obj"))
	assert_false(catalog.is_changed("white_piece.obj"))
	
	assert_true(catalog.is_imported("red_piece.obj"))
	assert_true(catalog.is_imported("white_piece.obj"))
	test_dir.remove(red_path + ".import")
	test_dir.remove(white_scn)
	assert_file_does_not_exist(red_path + ".import")
	assert_file_does_not_exist(white_scn)
	assert_false(catalog.is_imported("red_piece.obj"))
	assert_false(catalog.is_imported("white_piece.obj"))
	
	catalog.import_tagged()
	assert_true(catalog.is_imported("red_piece.obj"))
	assert_true(catalog.is_imported("white_piece.obj"))
	assert_file_exists(red_path + ".import")
	assert_file_exists(white_scn)
	
	# Clean up the test directory.
	for tagged_file in catalog.get_tagged():
		catalog.untag(tagged_file)
	catalog.remove_untagged()
	test_dir.remove(TYPE_CATALOG_TEST_LOCATION)
	assert_false(test_dir.dir_exists(TYPE_CATALOG_TEST_LOCATION))


func _check_scene(scene_path: String, texture_path: String, albedo_color: Color):
	gut.p("Checking imported scene at '%s'..." % scene_path)
	
	var test_scene = load(scene_path)
	assert_is(test_scene, PackedScene)
	assert_true(test_scene.can_instance())
	
	var test_node = autofree(test_scene.instance())
	assert_is(test_node, Spatial)
	assert_eq(test_node.get_child_count(), 1)
	
	var child_node = test_node.get_child(0)
	assert_is(child_node, MeshInstance)
	
	var test_mesh: Mesh = child_node.mesh
	assert_eq(test_mesh.get_surface_count(), 1)
	var vertex_data: PoolVector3Array = test_mesh.get_faces()
	assert_eq(vertex_data.size(), 3)
	assert_eq(vertex_data[0], Vector3(1.0, 0.0, 0.0))
	assert_eq(vertex_data[1], Vector3(0.0, 0.0, 0.0))
	assert_eq(vertex_data[2], Vector3(0.0, 0.0, 1.0))
	
	assert_eq(child_node.get_surface_material_count(), 1)
	var test_mat: SpatialMaterial = test_mesh.surface_get_material(0)
	assert_eq(test_mat.albedo_color, albedo_color)
	var actual_texture_path := ""
	if test_mat.albedo_texture != null:
		actual_texture_path = test_mat.albedo_texture.resource_path
	assert_eq(actual_texture_path, texture_path)


func _check_texture(texture_path: String, correct_color: Color):
	gut.p("Checking imported texture at '%s'..." % texture_path)
	var test_texture = load(texture_path)
	assert_is(test_texture, StreamTexture)
	
	var test_image: Image = test_texture.get_data()
	assert_eq(test_image.get_width(), 1)
	assert_eq(test_image.get_height(), 1)
	assert_false(test_image.has_mipmaps())
	assert_false(test_image.is_compressed())
	
	test_image.lock()
	assert_eq(test_image.get_pixel(0, 0), correct_color)
	test_image.unlock()


func _on_AssetDB_content_changed():
	_asset_db_content_changed_flag = true
