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

## Test the [AssetPackCatalog] class.


## The name of the asset pack the catalog will create.
const PACK_NAME := "__TEST_PACK__"

## The path to the test asset pack.
const PACK_PATH := "res://tests/test_pack"

## The rogue file to test the catalogs ability to remove them.
const ROGUE_FILE_PATH := "user://assets/%s/pieces/rogue_file.txt" % PACK_NAME


func test_individual_functions() -> void:
	# Place a rogue file in the pack's internal directory to see if it is
	# removed while it is untagged.
	var type_dir := Directory.new()
	var type_dir_path := ROGUE_FILE_PATH.get_base_dir()
	if not type_dir.dir_exists(type_dir_path):
		type_dir.make_dir_recursive(type_dir_path)
	
	var rogue_file := File.new()
	rogue_file.open(ROGUE_FILE_PATH, File.WRITE)
	rogue_file.store_string("This is a rogue file!")
	rogue_file.close()
	assert_file_exists(ROGUE_FILE_PATH)
	
	var pack_catalog := AssetPackCatalog.new(PACK_NAME)
	pack_catalog.clean_rogue_files()
	assert_file_does_not_exist(ROGUE_FILE_PATH)
	
	# Scan the tests/test_pack/ directory, and see if the correct files were
	# tagged. We'll only be checking the cards/ sub-directory for this test.
	pack_catalog.scan_dir(PACK_PATH)
	
	var card_env: AssetPackCatalog.DirectoryEnvironment = \
			pack_catalog.get_dir_env("cards")
	var card_catalog := card_env.type_catalog
	var tagged_files := card_catalog.get_tagged()
	assert_eq(tagged_files.size(), 2)
	assert_true(tagged_files.has("black_texture.png"))
	assert_true(card_catalog.is_new("black_texture.png"))
	assert_true(tagged_files.has("test_card.png"))
	assert_true(card_catalog.is_new("test_card.png"))
	
	# Was the 'config.cfg' file read in correctly?
	var card_cfg := card_env.type_config
	assert_eq(card_cfg.get_value("black_texture.png", "ignore"), true)
	
	var main_files := card_env.main_assets
	assert_eq(main_files.size(), 2)
	assert_true(main_files.has("black_texture.png"))
	assert_true(main_files.has("test_card.png"))
	
	# Now that we have scanned a directory, we should be able to create an empty
	# AssetPack resource with the details filled in for us.
	var pack := pack_catalog.create_empty_pack()
	assert_eq(pack.id, PACK_NAME)
	assert_eq(pack.name, PACK_NAME)
	assert_eq(pack.origin, PACK_PATH)
	
	# Import just the cards/ sub-directory. Since 'black_texture.png' is
	# ignored, only 'test_card.png' should appear.
	var black_texture_path := "user://assets/%s/cards/black_texture.png" % PACK_NAME
	var test_card_path := "user://assets/%s/cards/test_card.png" % PACK_NAME
	pack_catalog.import_sub_dir(pack, "cards")
	
	# TODO: When the card scene has actual GeoData, check the avg_point and
	# bounding_box properties of all of the card entries (inc. children).
	
	assert_eq(pack.get_entry_count(), 1)
	var test_card = pack.get_entry("cards", "Card 1")
	assert_is(test_card, AssetEntryStackable)
	assert_eq(test_card.id, "Card 1")
	# TODO: Check test_card.scene_path.
	assert_eq_deep(test_card.texture_overrides, [test_card_path,
			black_texture_path])
	assert_eq(test_card.scale, Vector3(6.0, 1.0, 8.0))
	
	var user_suit: CustomValue = test_card.user_suit
	assert_eq(user_suit.get_value_variant(), 2.5)
	var user_value: CustomValue = test_card.user_value
	assert_eq(user_value.get_value_variant(), 1)
	
	# Check to see if the child entries are created properly.
	pack_catalog.create_child_entries(pack)
	assert_eq(pack.get_entry_count(), 4)
	
	var card_2 = pack.get_entry("cards", "Card 2")
	assert_is(card_2, AssetEntryStackable)
	# TODO: Check the scene_path.
	assert_eq_deep(card_2.texture_overrides, [test_card_path, black_texture_path])
	assert_eq(card_2.scale, Vector3(6.0, 1.0, 8.0))
	user_suit = card_2.user_suit
	assert_eq(user_suit.get_value_variant(), "hey")
	user_value = card_2.user_value
	assert_eq(user_value.get_value_variant(), 2)
	
	# TODO: Check Card 2's sound effects haven't changed.
	
	var card_3 = pack.get_entry("cards", "Card 3")
	assert_is(card_3, AssetEntryStackable)
	# TODO: Check the scene_path.
	assert_eq_deep(card_3.texture_overrides, [test_card_path, test_card_path])
	assert_eq(card_3.scale, Vector3(6.0, 1.0, 8.0))
	user_suit = card_3.user_suit
	assert_eq(user_suit.get_value_variant(), 7)
	user_value = card_3.user_value
	assert_eq(user_value.get_value_variant(), 3)
	
	# TODO: Check Card 4's sound effects haven't changed.
	
	var card_4 = pack.get_entry("cards", "Card 4")
	assert_is(card_4, AssetEntryStackable)
	# TODO: Check the scene_path.
	assert_eq_deep(card_4.texture_overrides, [test_card_path, black_texture_path])
	assert_eq(card_4.scale, Vector3(5.0, 1.0, 8.0))
	user_suit = card_4.user_suit
	assert_eq(user_suit.get_value_variant(), "hey")
	user_value = card_4.user_value
	assert_eq(user_value.get_value_variant(), 4)
	
	# Check that pre-configured stacks are properly imported.
	var stack_cfg := AdvancedConfigFile.new()
	stack_cfg.load(PACK_PATH.plus_file("cards/stacks.cfg"))
	assert_eq_deep(stack_cfg.get_sections(), PoolStringArray(["Test Card Stack"]))
	
	pack_catalog.read_stacks_config(pack, stack_cfg, "cards")
	
	var stack_arr := pack.get_type("stacks")
	assert_eq(stack_arr.size(), 1)
	var stack_entry = stack_arr[0]
	assert_is(stack_entry, AssetEntryCollection)
	assert_eq(stack_entry.id, "Test Card Stack")
	assert_eq(stack_entry.desc, "This is an example of a card stack.")
	assert_eq_shallow(stack_entry.entry_list, [test_card, test_card, card_2,
			card_3])
	
	# Clean the internal pack directory at the end of the test.
	assert_file_exists(black_texture_path)
	pack_catalog.pack_name = PACK_NAME
	pack_catalog.clean_rogue_files()
	assert_file_does_not_exist(black_texture_path)
