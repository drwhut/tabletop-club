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


func test_full_import() -> void:
	var pack_catalog := AssetPackCatalog.new(PACK_NAME)
	pack_catalog.scan_dir(PACK_PATH) # Should already have been tested.
	var pack := pack_catalog.perform_full_import()
	assert_eq(pack.id, PACK_NAME)
	assert_eq(pack.name, PACK_NAME)
	assert_eq(pack.origin, PACK_PATH)
	
	assert_eq(pack.boards.size(), 1)
	var test_board: AssetEntryScene = pack.boards[0]
	assert_eq(test_board.id, "My Board")
	assert_eq(test_board.mass, 400.0)
	assert_eq(test_board.scale, Vector3(10.0, 0.5, 10.0))
	assert_true(test_board.avg_point.is_equal_approx(
			Vector3(10.0 / 3, 0.0, 10.0 / 3)))
	assert_true(test_board.bounding_box.is_equal_approx(
			AABB(Vector3.ZERO, Vector3(10.0, 0.0, 10.0))))
	assert_eq(test_board.collision_fast_sounds,
			preload("res://sounds/wood_heavy/wood_heavy_fast_sounds.tres"))
	assert_eq(test_board.collision_slow_sounds,
			preload("res://sounds/wood_heavy/wood_heavy_slow_sounds.tres"))
	
	# TODO: Check scene_path, avg_point, bounding_box, collision_sounds of
	# 'cards' and 'tokens'.
	
	var black_texture_path := "user://assets/%s/cards/black_texture.png" % PACK_NAME
	var test_card_path := "user://assets/%s/cards/test_card.png" % PACK_NAME
	assert_eq(pack.cards.size(), 4)
	var card_1: AssetEntryStackable = pack.cards[0]
	assert_eq(card_1.id, "Card 1")
	assert_eq_deep(card_1.texture_overrides, [test_card_path, black_texture_path])
	assert_eq(card_1.scale, Vector3(6.0, 1.0, 8.0))
	assert_eq(card_1.user_suit.get_value_variant(), 2.5)
	assert_eq(card_1.user_value.get_value_variant(), 1)
	var card_2: AssetEntryStackable = pack.cards[1]
	assert_eq(card_2.id, "Card 2")
	assert_eq_deep(card_2.texture_overrides, [test_card_path, black_texture_path])
	assert_eq(card_2.scale, Vector3(6.0, 1.0, 8.0))
	assert_eq(card_2.user_suit.get_value_variant(), "hey")
	assert_eq(card_2.user_value.get_value_variant(), 2)
	var card_3: AssetEntryStackable = pack.cards[2]
	assert_eq(card_3.id, "Card 3")
	assert_eq_deep(card_3.texture_overrides, [test_card_path, test_card_path])
	assert_eq(card_3.scale, Vector3(6.0, 1.0, 8.0))
	assert_eq(card_3.user_suit.get_value_variant(), 7)
	assert_eq(card_3.user_value.get_value_variant(), 3)
	var card_4: AssetEntryStackable = pack.cards[3]
	assert_eq(card_4.id, "Card 4")
	assert_eq_deep(card_4.texture_overrides, [test_card_path, black_texture_path])
	assert_eq(card_4.scale, Vector3(5.0, 1.0, 8.0))
	assert_eq(card_4.user_suit.get_value_variant(), "hey")
	assert_eq(card_4.user_value.get_value_variant(), 4)
	
	assert_eq(pack.containers.size(), 1)
	var test_container: AssetEntryContainer = pack.containers[0]
	assert_eq(test_container.id, "Test Container")
	assert_eq(test_container.desc, "This is a container... O.O")
	assert_eq(test_container.license, "No.")
	assert_eq(test_container.scale, Vector3(20.0, 25.0, 20.0))
	assert_true(test_container.avg_point.is_equal_approx(
			Vector3(20.0 / 3, 0.0, 20.0 / 3)))
	assert_true(test_container.bounding_box.is_equal_approx(
			AABB(Vector3.ZERO, Vector3(20.0, 0.0, 20.0))))
	assert_eq(test_container.collision_type,
			AssetEntryScene.CollisionType.COLLISION_CONCAVE)
	assert_eq(test_container.com_adjust,
			AssetEntryScene.ComAdjust.COM_ADJUST_OFF)
	assert_eq(test_container.collision_fast_sounds,
			preload("res://sounds/soft/soft_fast_sounds.tres"))
	assert_eq(test_container.collision_slow_sounds,
			preload("res://sounds/soft/soft_slow_sounds.tres"))
	assert_eq(test_container.shakable, true)
	
	assert_eq(pack.dice.size(), 6)
	var test_d10: AssetEntryDice = pack.dice[0]
	assert_eq(test_d10.id, "test_d10")
	assert_eq(test_d10.scene_path, "user://assets/%s/dice/d10/test_d10.obj" % PACK_NAME)
	assert_eq_deep(test_d10.texture_overrides, [])
	var face_value_res: DiceFaceValueList = test_d10.face_value_list
	var face_value_arr: Array = face_value_res.face_value_list
	assert_eq(face_value_arr.size(), 10)
	var face_value: DiceFaceValue = face_value_arr[0]
	assert_true(face_value.normal.is_equal_approx(Vector3.UP))
	assert_eq(face_value.value.get_value_variant(), "")
	face_value = face_value_arr[1]
	assert_true(face_value.normal.is_equal_approx(Vector3.FORWARD))
	assert_eq(face_value.value.get_value_variant(), "two?")
	face_value = face_value_arr[2]
	assert_true(face_value.normal.is_equal_approx(Vector3.RIGHT))
	assert_eq(face_value.value.get_value_variant(), 3)
	face_value = face_value_arr[3]
	assert_true(face_value.normal.is_equal_approx(Vector3.BACK))
	assert_eq(face_value.value.get_value_variant(), 4.0)
	face_value = face_value_arr[4]
	assert_true(face_value.normal.is_equal_approx(Vector3.LEFT))
	assert_eq(face_value.value.get_value_variant(), "5")
	face_value = face_value_arr[5]
	assert_true(face_value.normal.is_equal_approx(Vector3.DOWN))
	assert_eq(face_value.value.get_value_variant(), 6)
	face_value = face_value_arr[6]
	assert_true(face_value.normal.is_equal_approx(Vector3.BACK))
	assert_eq(face_value.value.get_value_variant(), "6+1")
	face_value = face_value_arr[7]
	assert_true(face_value.normal.is_equal_approx(Vector3.LEFT))
	assert_eq(face_value.value.get_value_variant(), "ate")
	face_value = face_value_arr[8]
	assert_true(face_value.normal.is_equal_approx(Vector3.DOWN))
	assert_eq(face_value.value.get_value_variant(), 9)
	face_value = face_value_arr[9]
	assert_true(face_value.normal.is_equal_approx(Vector3.UP))
	assert_eq(face_value.value.get_value_variant(), 10.5)
	
	var test_d12: AssetEntryDice = pack.dice[1]
	assert_eq(test_d12.id, "test_d12")
	assert_eq(test_d12.scene_path, "user://assets/%s/dice/d12/test_d12.obj" % PACK_NAME)
	assert_eq_deep(test_d12.texture_overrides, [])
	face_value_res = test_d12.face_value_list
	face_value_arr = face_value_res.face_value_list
	assert_eq(face_value_arr.size(), 3)
	face_value = face_value_arr[0]
	assert_true(face_value.normal.is_equal_approx(Vector3.UP))
	assert_eq(face_value.value.get_value_variant(), null)
	face_value = face_value_arr[1]
	assert_true(face_value.normal.is_equal_approx(Vector3.LEFT))
	assert_eq(face_value.value.get_value_variant(), null)
	face_value = face_value_arr[2]
	assert_true(face_value.normal.is_equal_approx(Vector3.DOWN))
	assert_eq(face_value.value.get_value_variant(), null)
	
	var test_d20: AssetEntryDice = pack.dice[2]
	assert_eq(test_d20.id, "test_d20")
	assert_eq(test_d20.scene_path, "user://assets/%s/dice/d20/test_d20.obj" % PACK_NAME)
	assert_eq_deep(test_d20.texture_overrides, [])
	face_value_res = test_d20.face_value_list
	face_value_arr = face_value_res.face_value_list
	assert_eq(face_value_arr.size(), 1)
	face_value = face_value_arr[0]
	assert_true(face_value.normal.is_equal_approx(Vector3.UP))
	assert_eq(face_value.value.get_value_variant(), "hi")
	
	var test_d4: AssetEntryDice = pack.dice[3]
	assert_eq(test_d4.id, "test_d4")
	assert_eq(test_d4.scene_path, "user://assets/%s/dice/d4/test_d4.obj" % PACK_NAME)
	assert_eq_deep(test_d4.texture_overrides, [])
	face_value_res = test_d4.face_value_list
	face_value_arr = face_value_res.face_value_list
	assert_eq(face_value_arr.size(), 4)
	face_value = face_value_arr[0]
	assert_true(face_value.normal.is_equal_approx(Vector3.UP))
	assert_eq(face_value.value.get_value_variant(), null)
	face_value = face_value_arr[1]
	assert_true(face_value.normal.is_equal_approx(Vector3.FORWARD))
	assert_eq(face_value.value.get_value_variant(), 2)
	face_value = face_value_arr[2]
	assert_true(face_value.normal.is_equal_approx(Vector3.RIGHT))
	assert_eq(face_value.value.get_value_variant(), 4.5)
	face_value = face_value_arr[3]
	assert_true(face_value.normal.is_equal_approx(Vector3.DOWN))
	assert_eq(face_value.value.get_value_variant(), "wat")
	
	var test_d6: AssetEntryDice = pack.dice[4]
	assert_eq(test_d6.id, "test_d6")
	assert_eq(test_d6.scene_path, "user://assets/%s/dice/d6/test_d6.obj" % PACK_NAME)
	assert_eq_deep(test_d6.texture_overrides, [])
	face_value_res = test_d6.face_value_list
	face_value_arr = face_value_res.face_value_list
	assert_eq(face_value_arr.size(), 6)
	face_value = face_value_arr[0]
	assert_true(face_value.normal.is_equal_approx(Vector3.RIGHT))
	assert_eq(face_value.value.get_value_variant(), 1)
	face_value = face_value_arr[1]
	assert_true(face_value.normal.is_equal_approx(Vector3.UP))
	assert_eq(face_value.value.get_value_variant(), 2)
	face_value = face_value_arr[2]
	assert_true(face_value.normal.is_equal_approx(Vector3.BACK))
	assert_eq(face_value.value.get_value_variant(), 3)
	face_value = face_value_arr[3]
	assert_true(face_value.normal.is_equal_approx(Vector3.LEFT))
	assert_eq(face_value.value.get_value_variant(), 4)
	face_value = face_value_arr[4]
	assert_true(face_value.normal.is_equal_approx(Vector3.DOWN))
	assert_eq(face_value.value.get_value_variant(), 5)
	face_value = face_value_arr[5]
	assert_true(face_value.normal.is_equal_approx(Vector3.FORWARD))
	assert_eq(face_value.value.get_value_variant(), 6)
	
	var test_d8: AssetEntryDice = pack.dice[5]
	assert_eq(test_d8.id, "test_d8")
	assert_eq(test_d8.scene_path, "user://assets/%s/dice/d8/test_d8.obj" % PACK_NAME)
	assert_eq_deep(test_d8.texture_overrides, [])
	face_value_res = test_d8.face_value_list
	face_value_arr = face_value_res.face_value_list
	assert_eq(face_value_arr.size(), 8)
	face_value = face_value_arr[0]
	assert_true(face_value.normal.is_equal_approx(Vector3.UP))
	assert_eq(face_value.value.get_value_variant(), 1)
	face_value = face_value_arr[1]
	assert_true(face_value.normal.is_equal_approx(Vector3.RIGHT))
	assert_eq(face_value.value.get_value_variant(), 2)
	face_value = face_value_arr[2]
	assert_true(face_value.normal.is_equal_approx(Vector3.FORWARD))
	assert_eq(face_value.value.get_value_variant(), 3)
	face_value = face_value_arr[3]
	assert_true(face_value.normal.is_equal_approx(Vector3.LEFT))
	assert_eq(face_value.value.get_value_variant(), 4)
	face_value = face_value_arr[4]
	assert_true(face_value.normal.is_equal_approx(Vector3.BACK))
	assert_eq(face_value.value.get_value_variant(), 5.5)
	face_value = face_value_arr[5]
	assert_true(face_value.normal.is_equal_approx(Vector3.DOWN))
	assert_eq(face_value.value.get_value_variant(), "six")
	face_value = face_value_arr[6]
	assert_true(face_value.normal.is_equal_approx(Vector3.DOWN))
	assert_eq(face_value.value.get_value_variant(), "seven")
	face_value = face_value_arr[7]
	assert_true(face_value.normal.is_equal_approx(Vector3.UP))
	assert_eq(face_value.value.get_value_variant(), "8")
	
	# Since the geometry metadata for all of the dice is the same, check them
	# all at once here.
	# TODO: Also check collision sounds.
	for index in range(pack.dice.size()):
		var die_entry: AssetEntryDice = pack.dice[index]
		assert_eq(die_entry.scale, Vector3.ONE)
		assert_true(die_entry.avg_point.is_equal_approx(
				Vector3(1.0 / 3, 0.0, 1.0 / 3)))
		assert_true(die_entry.bounding_box.is_equal_approx(
				AABB(Vector3.ZERO, Vector3(1.0, 0.0, 1.0))))
	
	assert_eq(pack.games.size(), 1)
	var test_game: AssetEntrySave = pack.games[0]
	assert_eq(test_game.id, "Awesome Game")
	assert_eq(test_game.desc, "This is an awesome game, you should play it.")
	assert_eq(test_game.save_file_path, "user://assets/%s/games/test_game.tc" % PACK_NAME)
	
	assert_eq(pack.music.size(), 1)
	var test_music: AssetEntryAudio = pack.music[0]
	assert_eq(test_music.id, "My Music")
	assert_eq(test_music.desc, "This should be classified as music.")
	assert_eq(test_music.author, "Me.")
	assert_eq(test_music.license, "")
	assert_eq(test_music.modified_by, "Also me.")
	assert_eq(test_music.url, "https://youtu.be/dQw4w9WgXcQ")
	assert_eq(test_music.audio_path, "user://assets/%s/music/test_music.wav" % PACK_NAME)
	
	assert_eq(pack.pieces.size(), 4)
	var red_piece_path := "user://assets/%s/pieces/red_piece.obj" % PACK_NAME
	var white_piece_path := "user://assets/%s/pieces/white_piece.obj" % PACK_NAME
	var another_red_piece: AssetEntryScene = pack.pieces[0]
	assert_eq(another_red_piece.id, "another_red_piece")
	assert_eq(another_red_piece.desc, "This is a triangle. More at 11.")
	assert_eq(another_red_piece.scene_path, red_piece_path)
	assert_eq_deep(another_red_piece.texture_overrides, [])
	assert_eq(another_red_piece.albedo_color, Color.red)
	assert_eq(another_red_piece.scale, Vector3(10.0, 0.1, 10.0))
	assert_true(another_red_piece.avg_point.is_equal_approx(
			Vector3(10.0 / 3, 0.0, 10.0 / 3)))
	assert_true(another_red_piece.bounding_box.is_equal_approx(
			AABB(Vector3.ZERO, Vector3(10.0, 0.0, 10.0))))
	assert_eq(another_red_piece.collision_type,
			AssetEntryScene.CollisionType.COLLISION_MULTI_CONVEX)
	assert_eq(another_red_piece.com_adjust,
			AssetEntryScene.ComAdjust.COM_ADJUST_GEOMETRY)
	assert_eq(another_red_piece.physics_material.bounce, 1.0)
	assert_eq(another_red_piece.collision_fast_sounds,
			preload("res://sounds/metal/metal_fast_sounds.tres"))
	assert_eq(another_red_piece.collision_slow_sounds,
			preload("res://sounds/metal/metal_slow_sounds.tres"))
	var blue_piece: AssetEntryScene = pack.pieces[1]
	assert_eq(blue_piece.id, "blue_piece")
	assert_eq(blue_piece.desc, "This is a triangle. More at 11.")
	assert_eq(blue_piece.scene_path, red_piece_path)
	assert_eq_deep(blue_piece.texture_overrides, [])
	assert_eq(blue_piece.albedo_color, Color.red)
	assert_eq(blue_piece.scale, Vector3(10.0, 0.1, 10.0))
	assert_true(blue_piece.avg_point.is_equal_approx(
			Vector3(10.0 / 3, 0.0, 10.0 / 3)))
	assert_true(blue_piece.bounding_box.is_equal_approx(
			AABB(Vector3.ZERO, Vector3(10.0, 0.0, 10.0))))
	assert_eq(blue_piece.collision_type,
			AssetEntryScene.CollisionType.COLLISION_MULTI_CONVEX)
	assert_eq(blue_piece.com_adjust,
			AssetEntryScene.ComAdjust.COM_ADJUST_GEOMETRY)
	assert_eq(blue_piece.physics_material.bounce, 1.0)
	assert_eq(blue_piece.collision_fast_sounds,
			preload("res://sounds/metal/metal_fast_sounds.tres"))
	assert_eq(blue_piece.collision_slow_sounds,
			preload("res://sounds/metal/metal_slow_sounds.tres"))
	var red_piece: AssetEntryScene = pack.pieces[2]
	assert_eq(red_piece.id, "red_piece")
	assert_eq(red_piece.desc, "This is a triangle. More at 11.")
	assert_eq(red_piece.scene_path, red_piece_path)
	assert_eq_deep(red_piece.texture_overrides, [])
	assert_eq(red_piece.albedo_color, Color.red)
	assert_eq(red_piece.scale, Vector3(10.0, 0.1, 10.0))
	assert_true(red_piece.avg_point.is_equal_approx(
			Vector3(10.0 / 3, 0.0, 10.0 / 3)))
	assert_true(red_piece.bounding_box.is_equal_approx(
			AABB(Vector3.ZERO, Vector3(10.0, 0.0, 10.0))))
	assert_eq(red_piece.collision_type,
			AssetEntryScene.CollisionType.COLLISION_MULTI_CONVEX)
	assert_eq(red_piece.com_adjust,
			AssetEntryScene.ComAdjust.COM_ADJUST_GEOMETRY)
	assert_eq(red_piece.physics_material.bounce, 1.0)
	assert_eq(red_piece.collision_fast_sounds,
			preload("res://sounds/metal/metal_fast_sounds.tres"))
	assert_eq(red_piece.collision_slow_sounds,
			preload("res://sounds/metal/metal_slow_sounds.tres"))
	var white_piece: AssetEntryScene = pack.pieces[3]
	assert_eq(white_piece.id, "white_piece")
	assert_eq(white_piece.desc, "This is a triangle. More at 11.")
	assert_eq(white_piece.scene_path, white_piece_path)
	assert_eq_deep(white_piece.texture_overrides, [])
	assert_eq(white_piece.albedo_color, Color.white)
	assert_eq(white_piece.scale, Vector3(10.0, 0.1, 10.0))
	assert_true(white_piece.avg_point.is_equal_approx(
			Vector3(10.0 / 3, 0.0, 10.0 / 3)))
	assert_true(white_piece.bounding_box.is_equal_approx(
			AABB(Vector3.ZERO, Vector3(10.0, 0.0, 10.0))))
	assert_eq(white_piece.collision_type,
			AssetEntryScene.CollisionType.COLLISION_MULTI_CONVEX)
	assert_eq(white_piece.com_adjust,
			AssetEntryScene.ComAdjust.COM_ADJUST_GEOMETRY)
	assert_eq(white_piece.physics_material.bounce, 1.0)
	assert_eq(white_piece.collision_fast_sounds,
			preload("res://sounds/metal/metal_fast_sounds.tres"))
	assert_eq(white_piece.collision_slow_sounds,
			preload("res://sounds/metal/metal_slow_sounds.tres"))
	
	assert_eq(pack.skyboxes.size(), 1)
	var test_skybox: AssetEntrySkybox = pack.skyboxes[0]
	assert_eq(test_skybox.id, "Cool Skybox")
	assert_eq(test_skybox.texture_path, "user://assets/%s/skyboxes/test_skybox.png" % PACK_NAME)
	assert_eq(test_skybox.energy, 10.0)
	assert_true(test_skybox.rotation.is_equal_approx(Vector3(PI / 2, 0.0, PI)))
	
	assert_eq(pack.sounds.size(), 1)
	var test_sound: AssetEntryAudio = pack.sounds[0]
	assert_eq(test_sound.id, "test_sound")
	assert_eq(test_sound.desc, "This should be recognised as a sound...\n\n... not as a music track.")
	assert_eq(test_sound.author, "you")
	assert_eq(test_sound.license, "go ham")
	assert_eq(test_sound.modified_by, "me")
	assert_eq(test_sound.url, "idunno")
	assert_eq(test_sound.audio_path, "user://assets/%s/sounds/test_sound.wav" % PACK_NAME)
	
	assert_eq(pack.speakers.size(), 1)
	var test_speaker: AssetEntryScene = pack.speakers[0]
	assert_eq(test_speaker.id, "test_speaker_no_config")
	assert_eq(test_speaker.desc, "")
	assert_eq(test_speaker.author, "")
	assert_eq(test_speaker.license, "")
	assert_eq(test_speaker.modified_by, "")
	assert_eq(test_speaker.url, "")
	assert_eq(test_speaker.scene_path, "user://assets/%s/speakers/test_speaker_no_config.obj" % PACK_NAME)
	assert_eq_deep(test_speaker.texture_overrides, [])
	assert_eq(test_speaker.albedo_color, Color.white)
	assert_eq(test_speaker.mass, 1.0)
	assert_eq(test_speaker.scale, Vector3.ONE)
	assert_true(test_speaker.avg_point.is_equal_approx(
			Vector3(1.0 / 3, 0.0, 1.0 / 3)))
	assert_true(test_speaker.bounding_box.is_equal_approx(
			AABB(Vector3.ZERO, Vector3(1.0, 0.0, 1.0))))
	assert_eq(test_speaker.collision_type,
			AssetEntryScene.CollisionType.COLLISION_CONVEX)
	assert_eq(test_speaker.com_adjust,
			AssetEntryScene.ComAdjust.COM_ADJUST_VOLUME)
	assert_eq(test_speaker.physics_material.bounce, 0.0)
	assert_eq(test_speaker.collision_fast_sounds,
			preload("res://sounds/generic/generic_fast_sounds.tres"))
	assert_eq(test_speaker.collision_slow_sounds,
			preload("res://sounds/generic/generic_slow_sounds.tres"))
	
	assert_eq(pack.tables.size(), 1)
	var test_table: AssetEntryTable = pack.tables[0]
	assert_eq(test_table.id, "Gaming Table")
	assert_eq(test_table.desc, "... what if a table had RBG lighting like a PC? Hmm...")
	assert_eq(test_table.hand_transforms.size(), 4)
	var hand_transform = test_table.hand_transforms[0]
	assert_eq(hand_transform.basis, Basis.IDENTITY)
	assert_eq(hand_transform.origin, Vector3.ZERO)
	hand_transform = test_table.hand_transforms[1]
	assert_eq(hand_transform.basis, Basis.IDENTITY)
	assert_eq(hand_transform.origin, Vector3(0.0, 0.0, -50.0))
	hand_transform = test_table.hand_transforms[2]
	assert_eq(hand_transform.basis, Basis.IDENTITY.rotated(Vector3.UP, PI / 2))
	assert_eq(hand_transform.origin, Vector3.ZERO)
	hand_transform = test_table.hand_transforms[3]
	assert_eq(hand_transform.basis, Basis.IDENTITY.rotated(Vector3.UP, PI))
	assert_eq(hand_transform.origin, Vector3(0.0, 10.0, 100.0))
	assert_eq(test_table.paint_plane_transform, Transform(
			Basis.IDENTITY.scaled(Vector3(50.0, 1.0, 100.0)),
			Vector3.ZERO))
	
	assert_eq(pack.templates.size(), 3)
	var old_template: AssetEntryTemplateImage = pack.templates[0]
	assert_eq(old_template.id, "old_template")
	assert_eq(old_template.template_path, "user://assets/%s/templates/old_template.png" % PACK_NAME)
	assert_eq(old_template.textbox_list.size(), 2)
	var textbox: TemplateTextbox = old_template.textbox_list[0]
	assert_eq(textbox.rect, Rect2(0.0, 0.0, 100.0, 100.0))
	assert_eq(textbox.rotation, 0.0)
	assert_eq(textbox.lines, 1)
	assert_eq(textbox.text, "")
	textbox = old_template.textbox_list[1]
	assert_eq(textbox.rect, Rect2(200.0, 100.0, 100.0, 20.0))
	assert_eq(textbox.rotation, 180.0)
	assert_eq(textbox.lines, 1)
	assert_eq(textbox.text, "")
	# There are two files with the name "test_template" in this folder, so one
	# of them will be named "test_template (1)", we just can't guarantee which
	# due to each OS potentially reporting the files in a different order.
	var remaining_templates := pack.templates.slice(1, 2)
	# For simplicity, make the text template the first item in the list.
	if remaining_templates[0] is AssetEntryTemplateImage:
		remaining_templates.invert()
	var text_template: AssetEntryTemplateText = remaining_templates[0]
	var found_duplicate_name := false
	if text_template.id == "test_template (1)":
		found_duplicate_name = true
	else:
		assert_eq(text_template.id, "test_template")
	assert_eq(text_template.template_path, "user://assets/%s/templates/test_template.txt" % PACK_NAME)
	var image_template: AssetEntryTemplateImage = remaining_templates[1]
	if found_duplicate_name:
		assert_eq(image_template.id, "test_template")
	else:
		assert_eq(image_template.id, "test_template (1)")
	assert_eq(image_template.template_path, "user://assets/%s/templates/test_template.png" % PACK_NAME)
	assert_eq(image_template.textbox_list.size(), 5)
	textbox = image_template.textbox_list[0]
	assert_eq(textbox.rect, Rect2(0.0, 0.0, 100.0, 100.0))
	assert_eq(textbox.rotation, 0.0)
	assert_eq(textbox.lines, 1)
	assert_eq(textbox.text, "")
	textbox = image_template.textbox_list[1]
	assert_eq(textbox.rect, Rect2(10.0, 10.0, 200.0, 200.0))
	assert_eq(textbox.rotation, 0.0)
	assert_eq(textbox.lines, 5)
	assert_eq(textbox.text, "")
	textbox = image_template.textbox_list[2]
	assert_eq(textbox.rect, Rect2(0.0, 0.0, 10.0, 10.0))
	assert_eq(textbox.rotation, 0.0)
	assert_eq(textbox.lines, 1)
	assert_eq(textbox.text, "urm...\n... this is awkward.")
	textbox = image_template.textbox_list[3]
	assert_eq(textbox.rect, Rect2(100.0, 100.0, 400.0, 100.0))
	assert_eq(textbox.rotation, 90.0)
	assert_eq(textbox.lines, 1)
	assert_eq(textbox.text, "hi")
	textbox = image_template.textbox_list[4]
	assert_eq(textbox.rect, Rect2(0.0, 0.0, 1000.0, 50.0))
	assert_eq(textbox.rotation, 0.0)
	assert_eq(textbox.lines, 5)
	assert_eq(textbox.text, "")
	
	assert_eq(pack.timers.size(), 2)
	var new_timer: AssetEntryScene = pack.timers[0]
	assert_eq(new_timer.id, "New New Timer")
	assert_eq(new_timer.scene_path, "user://assets/%s/timers/test_timer.obj" % PACK_NAME)
	assert_eq(new_timer.collision_fast_sounds,
			preload("res://sounds/generic/generic_fast_sounds.tres"))
	assert_eq(new_timer.collision_slow_sounds,
			preload("res://sounds/generic/generic_slow_sounds.tres"))
	var test_timer: AssetEntryScene = pack.timers[1]
	assert_eq(test_timer.id, "Test Timer")
	assert_eq(test_timer.scene_path, "user://assets/%s/timers/test_timer.obj" % PACK_NAME)
	assert_eq(test_timer.collision_fast_sounds,
			preload("res://sounds/metal_light/metal_light_fast_sounds.tres"))
	assert_eq(test_timer.collision_slow_sounds,
			preload("res://sounds/metal_light/metal_light_slow_sounds.tres"))
	
	assert_eq(pack.tokens.size(), 3)
	var test_cube: AssetEntryStackable = pack.tokens[0]
	assert_eq(test_cube.id, "Test Cube")
	# TODO: Check 'scene_path'.
	assert_eq_deep(test_cube.texture_overrides, [
			"user://assets/%s/tokens/cube/cube_token.png" % PACK_NAME])
	assert_eq(test_cube.albedo_color, Color.white)
	assert_eq(test_cube.mass, 1.0)
	assert_eq(test_cube.scale, Vector3.ONE)
	assert_eq(test_cube.physics_material.bounce, 0.0)
	assert_eq(test_cube.user_suit.get_value_variant(), "T")
	assert_eq(test_cube.user_value.get_value_variant(), 5)
	var test_cube_2: AssetEntryStackable = pack.tokens[1]
	assert_eq(test_cube_2.id, "Test Cube 2")
	# TODO: Check 'scene_path'.
	assert_eq_deep(test_cube_2.texture_overrides, [
			"user://assets/%s/tokens/cube/cube_token.png" % PACK_NAME])
	assert_eq(test_cube_2.albedo_color, Color.white)
	assert_eq(test_cube_2.mass, 1.0)
	assert_eq(test_cube_2.scale, Vector3.ONE)
	assert_eq(test_cube_2.physics_material.bounce, 0.0)
	assert_eq(test_cube_2.user_suit.get_value_variant(), "T")
	assert_eq(test_cube_2.user_value.get_value_variant(), null)
	var cylinder_token: AssetEntryStackable = pack.tokens[2]
	assert_eq(cylinder_token.id, "cylinder_token")
	# TODO: Check 'scene_path'.
	assert_eq_deep(cylinder_token.texture_overrides, [
			"user://assets/%s/tokens/cylinder/cylinder_token.png" % PACK_NAME])
	assert_eq(cylinder_token.albedo_color, Color.white)
	assert_eq(cylinder_token.mass, 1.0)
	assert_eq(cylinder_token.scale, Vector3.ONE)
	assert_eq(cylinder_token.physics_material.bounce, 0.0)
	assert_eq(cylinder_token.user_suit.get_value_variant(), null)
	assert_eq(cylinder_token.user_value.get_value_variant(), null)
	
	assert_eq(pack.stacks.size(), 3)
	var big_stack: AssetEntryCollection = pack.stacks[0]
	assert_eq(big_stack.id, "Big Stack")
	assert_eq(big_stack.desc, "This stack should be accepted.")
	assert_eq_shallow(big_stack.entry_list, [test_cube, test_cube_2])
	var just_a_few_cylinders: AssetEntryCollection = pack.stacks[1]
	assert_eq(just_a_few_cylinders.id, "Just A Few Cylinders")
	assert_eq(just_a_few_cylinders.desc,
			"Just a selection of unconfigured cylinders, nothing to worry about :)")
	assert_eq_shallow(just_a_few_cylinders.entry_list, [
			cylinder_token, cylinder_token, cylinder_token])
	var test_card_stack: AssetEntryCollection = pack.stacks[2]
	assert_eq(test_card_stack.id, "Test Card Stack")
	assert_eq(test_card_stack.desc, "This is an example of a card stack.")
	assert_eq_shallow(test_card_stack.entry_list, [card_1, card_1, card_2, card_3])
	
	# Clean the internal pack directory at the end of the test.
	pack_catalog.pack_name = PACK_NAME
	pack_catalog.clean_rogue_files()
