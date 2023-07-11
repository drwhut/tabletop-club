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

## Test the [AssetPackTypeCatalog] class.


## The directory to use to test [AssetPackTypeCatalog].
const TYPE_CATALOG_TEST_LOCATION := "user://assets/__type_catalog__"


func test_collecting_and_importing() -> void:
	var test_dir := Directory.new()
	if not test_dir.dir_exists(TYPE_CATALOG_TEST_LOCATION):
		test_dir.make_dir_recursive(TYPE_CATALOG_TEST_LOCATION)
	
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

func test_configuring_entries() -> void:
	# Even though it will be empty the entire time, the catalog needs an
	# existing directory under user://assets to not throw an error.
	var test_dir := Directory.new()
	if not test_dir.dir_exists(TYPE_CATALOG_TEST_LOCATION):
		test_dir.make_dir_recursive(TYPE_CATALOG_TEST_LOCATION)
	
	var test := TestConfigureSettings.new()
	test.catalog = AssetPackTypeCatalog.new(TYPE_CATALOG_TEST_LOCATION)
	
	if test.catalog.dir_path.empty():
		fail_test("Failed to open directory: '%s'" % TYPE_CATALOG_TEST_LOCATION)
		return
	
	test.entry = AssetEntrySingle.new()
	test.section_name = "__name__.txt"
	
	# AssetEntrySingle.id
	test.cfg_name = "" # Test when name is not overwritten.
	test.prop_name = "id"
	test.prop_value = "__name__"
	_check_entry_configured(test)
	
	test.cfg_name = "name" # Test when name is overwritten.
	test.cfg_value = "__test__"
	test.prop_value = "__test__"
	_check_entry_configured(test)
	
	for key in ["desc", "author", "license", "modified_by", "url"]:
		for setting_value in [false, true]:
			if setting_value:
				test.cfg_name = key
				test.cfg_value = "__VALUE__"
			else:
				test.cfg_name = ""
			
			test.prop_name = key
			test.prop_value = "__VALUE__" if setting_value else ""
			_check_entry_configured(test)
	
	# AssetEntryScene.albedo_color
	test.entry = AssetEntryScene.new()
	test.cfg_name = "" # Default colour should be #ffffff.
	test.prop_name = "albedo_color"
	test.prop_value = Color.white
	_check_entry_configured(test)
	
	test.cfg_name = "color"
	test.cfg_value = "#2b|!2b" # Invalid characters.
	_check_entry_configured(test)
	
	test.cfg_value = "#00f" # Needs to be six characters long.
	_check_entry_configured(test)
	
	test.cfg_value = "#ab0025"
	test.prop_value = Color("#ab0025")
	_check_entry_configured(test)
	
	test.cfg_value = "13bb13"
	test.prop_value = Color("#13bb13")
	_check_entry_configured(test)
	
	# AssetEntryScene.mass
	test.cfg_name = "" # Default mass should be 1.0 grams.
	test.prop_name = "mass"
	test.prop_value = 1.0
	_check_entry_configured(test)
	
	test.cfg_name = "mass"
	test.cfg_value = 32.0
	test.prop_value = 32.0
	_check_entry_configured(test)
	
	test.cfg_value = -2.5 # Negative mass is not allowed.
	test.prop_value = 0.0
	_check_entry_configured(test)
	
	test.cfg_value = NAN # Invalid floating-point value.
	_check_entry_configured(test)
	
	# AssetEntrySingle.scale
	test.cfg_name = ""
	test.prop_name = "scale"
	test.prop_value = Vector3.ONE
	_check_entry_configured(test)
	
	test.cfg_name = "scale"
	test.cfg_value = Vector3(1.0, INF, -2.0) # Invalid float inside Vector3.
	_check_entry_configured(test)
	
	test.cfg_value = Vector2(2.5, 5.0) # Using Vector2 in Vector3 mode.
	_check_entry_configured(test)
	
	test.cfg_value = Vector3(1.5, 0.5, 2.5)
	test.prop_value = Vector3(1.5, 0.5, 2.5)
	_check_entry_configured(test)
	
	test.scale_is_vec2 = true
	test.cfg_value = Vector3.ZERO # Using Vector3 in Vector2 mode.
	test.prop_value = Vector3.ONE
	_check_entry_configured(test)
	
	# Set these properties up for later so we can check how scale affects them.
	test.entry.avg_point = Vector3(1.0, 0.25, 0.0)
	test.entry.bounding_box = AABB(Vector3(-1.0, -2.0, -5.0),
			Vector3(3.0, 4.0, 10.0))
	
	test.cfg_value = Vector2(5.0, 8.0)
	test.prop_value = Vector3(5.0, 1.0, 8.0)
	_check_entry_configured(test)
	
	assert_eq(test.entry.avg_point, Vector3(5.0, 0.25, 0.0))
	assert_eq(test.entry.bounding_box, AABB(Vector3(-5.0, -2.0, -40.0),
			Vector3(15.0, 4.0, 80.0)))
	
	# AssetEntryScene.collision_type
	test.cfg_name = ""
	test.prop_name = "collision_type"
	test.prop_value = AssetEntryScene.CollisionType.COLLISION_CONVEX
	_check_entry_configured(test)
	
	test.cfg_name = "collision_mode"
	test.cfg_value = 7 # Invalid value.
	_check_entry_configured(test)
	
	test.cfg_value = "1" # Integers only.
	_check_entry_configured(test)
	
	test.cfg_value = 0 # Default value.
	_check_entry_configured(test)
	
	test.cfg_value = 1
	test.prop_value = AssetEntryScene.CollisionType.COLLISION_MULTI_CONVEX
	_check_entry_configured(test)
	
	test.cfg_value = 2
	test.prop_value = AssetEntryScene.CollisionType.COLLISION_CONCAVE
	_check_entry_configured(test)
	
	# TODO: Test config doesn't affect collision for internal scenes.
	#test.entry.scene_path = "res://assets/fake.tscn"
	#test.prop_value = AssetEntryScene.CollisionType.COLLISION_NONE
	#_check_entry_configured(test)
	
	# AssetEntryScene.com_adjust
	#test.entry.scene_path = "user://assets/fake.tscn"
	test.cfg_name = ""
	test.prop_name = "com_adjust"
	test.prop_value = AssetEntryScene.ComAdjust.COM_ADJUST_VOLUME
	_check_entry_configured(test)
	
	test.cfg_name = "com_adjust"
	test.cfg_value = "haha" # Invalid value.
	_check_entry_configured(test)
	
	test.cfg_value = 0 # Strings only.
	_check_entry_configured(test)
	
	test.cfg_value = "off"
	test.prop_value = AssetEntryScene.ComAdjust.COM_ADJUST_OFF
	_check_entry_configured(test)
	
	test.cfg_value = "volume"
	test.prop_value = AssetEntryScene.ComAdjust.COM_ADJUST_VOLUME
	_check_entry_configured(test)
	
	test.cfg_value = "geometry"
	test.prop_value = AssetEntryScene.ComAdjust.COM_ADJUST_GEOMETRY
	_check_entry_configured(test)
	
	# TODO: Test config doesn't affect COM for internal scenes.
	#test.entry.scene_path = "res://assets/fake.tscn"
	#test.prop_value = AssetEntryScene.ComAdjust.COM_ADJUST_OFF
	#_check_entry_configured(test)
	
	var physics_mat := PhysicsMaterial.new()
	
	# AssetEntryScene.physics_material
	test.cfg_name = ""
	test.prop_name = "physics_material"
	test.prop_value = physics_mat
	_check_entry_configured(test)
	
	test.cfg_name = "bounce"
	test.cfg_value = 0.0
	_check_entry_configured(test)
	
	test.cfg_value = 0.5
	physics_mat.bounce = 0.5
	_check_entry_configured(test)
	
	test.cfg_value = NAN
	physics_mat.bounce = 0.0
	_check_entry_configured(test)
	
	test.cfg_value = 1.2
	physics_mat.bounce = 1.0
	_check_entry_configured(test)
	
	test.cfg_value = -0.1
	physics_mat.bounce = 0.0
	_check_entry_configured(test)
	
	# AssetEntryScene.collision_*_sounds
	test.cfg_name = ""
	test.prop_name = "collision_fast_sounds"
	test.prop_value = preload("res://sounds/generic/generic_fast_sounds.tres")
	_check_entry_configured(test)
	
	test.prop_name = "collision_slow_sounds"
	test.prop_value = preload("res://sounds/generic/generic_slow_sounds.tres")
	_check_entry_configured(test)
	
	test.cfg_name = "sfx"
	test.cfg_value = "metal_heavy"
	test.prop_name = "collision_fast_sounds"
	test.prop_value = preload("res://sounds/generic/generic_fast_sounds.tres")
	_check_entry_configured(test)
	
	test.prop_name = "collision_slow_sounds"
	test.prop_value = preload("res://sounds/generic/generic_slow_sounds.tres")
	_check_entry_configured(test)
	
	# The reason the previous tests don't change the entry is because the
	# catalog sees that there are already sound effects in the entry, and
	# assumes the developer doesn't want them to be overwritten.
	test.entry.collision_fast_sounds = AudioStreamList.new()
	test.entry.collision_slow_sounds = AudioStreamList.new()
	
	test.prop_name = "collision_fast_sounds"
	test.prop_value = preload("res://sounds/metal_heavy/metal_heavy_fast_sounds.tres")
	_check_entry_configured(test)
	
	test.prop_name = "collision_slow_sounds"
	test.prop_value = preload("res://sounds/metal_heavy/metal_heavy_slow_sounds.tres")
	_check_entry_configured(test)
	
	test.entry.collision_fast_sounds = AudioStreamList.new()
	test.entry.collision_slow_sounds = AudioStreamList.new()
	
	test.cfg_value = "1337" # Invalid sound effect name.
	test.prop_name = "collision_fast_sounds"
	test.prop_value = preload("res://sounds/generic/generic_fast_sounds.tres")
	_check_entry_configured(test)
	
	test.prop_name = "collision_slow_sounds"
	test.prop_value = preload("res://sounds/generic/generic_slow_sounds.tres")
	_check_entry_configured(test)
	
	# AssetEntryContainer.shakable
	test.entry = AssetEntryContainer.new()
	test.cfg_name = ""
	test.prop_name = "shakable"
	test.prop_value = false
	_check_entry_configured(test)
	
	test.cfg_name = "shakable"
	test.cfg_value = true
	test.prop_value = true
	_check_entry_configured(test)
	
	# AssetEntryDice.face_value_list
	# TODO: Check if a warning was generated if the number of given values did
	# not match the number of expected faces.
	var expected_value_list := DiceFaceValueList.new()
	
	test.entry = AssetEntryDice.new()
	test.cfg_value = ""
	test.prop_name = "face_value_list"
	test.prop_value = expected_value_list
	_check_entry_configured(test)
	
	test.cfg_name = "face_values"
	test.cfg_value = { Vector2.ZERO: Vector3.ONE } # Invalid custom value.
	var null_value := CustomValue.new()
	null_value.value_type = CustomValue.ValueType.TYPE_NULL
	var null_face := DiceFaceValue.new()
	null_face.normal = Vector3.UP
	null_face.value = null_value
	expected_value_list.face_value_list = [ null_face ]
	_check_entry_configured(test)
	
	test.cfg_value = { Vector2(NAN, 90.0): 69 } # Invalid rotation Vector2.
	expected_value_list.face_value_list = []
	_check_entry_configured(test)
	
	test.cfg_value = { Vector2(90.0, 0.0): "Hello, there!" }
	var str_value := CustomValue.new()
	str_value.value_string = "Hello, there!"
	var valid_face_back := DiceFaceValue.new()
	valid_face_back.normal = Vector3.FORWARD
	valid_face_back.value = str_value
	expected_value_list.face_value_list = [ valid_face_back ]
	_check_entry_configured(test)
	
	# For v0.1.x backwards compatibility.
	test.cfg_value = { Transform.IDENTITY: Vector2.ZERO } # Invalid custom value.
	expected_value_list.face_value_list = [ null_face ]
	_check_entry_configured(test)
	
	test.cfg_value = { "lol": Vector3.ZERO } # Rotation is not Vector2.
	expected_value_list.face_value_list = []
	_check_entry_configured(test)
	
	test.cfg_value = { 20: Vector2(90.0, INF) } # Invalid rotation data.
	_check_entry_configured(test)
	
	test.cfg_value = { 6: Vector2(0.0, 270.0), 2.5: Vector2(180.0, 0.0) }
	var int_value := CustomValue.new()
	int_value.value_int = 6
	var valid_face_right := DiceFaceValue.new()
	valid_face_right.normal = Vector3.LEFT
	valid_face_right.value = int_value
	var float_value := CustomValue.new()
	float_value.value_float = 2.5
	var valid_face_down := DiceFaceValue.new()
	valid_face_down.normal = Vector3.DOWN
	valid_face_down.value = float_value
	expected_value_list.face_value_list = [ valid_face_right, valid_face_down ]
	_check_entry_configured(test)
	
	test.entry = AssetEntryStackable.new()
	for property_name in [ "suit", "value" ]:
		test.prop_name = "user_" + property_name
		
		var expected_value := CustomValue.new()
		expected_value.value_type = CustomValue.ValueType.TYPE_NULL
		
		test.cfg_name = ""
		test.prop_value = expected_value
		_check_entry_configured(test)
		
		test.cfg_name = property_name
		test.cfg_value = null
		_check_entry_configured(test)
		
		test.cfg_value = 360
		expected_value.value_int = 360
		_check_entry_configured(test)
		
		test.cfg_value = 0.25
		expected_value.value_float = 0.25
		_check_entry_configured(test)
		
		test.cfg_value = INF # Invalid floats are allowed in CustomValue.
		expected_value.value_float = INF
		_check_entry_configured(test)
		
		test.cfg_value = "lmao"
		expected_value.value_string = "lmao"
		_check_entry_configured(test)
		
		test.cfg_value = [ 1, 2, 3 ] # Arrays not allowed as custom value.
		expected_value.value_type = CustomValue.ValueType.TYPE_NULL
		_check_entry_configured(test)
	
	# AssetEntryTable.hand_transforms
	test.entry = AssetEntryTable.new()
	test.cfg_name = ""
	test.prop_name = "hand_transforms"
	test.prop_value = []
	_check_entry_configured(test)
	
	test.cfg_name = "hands"
	test.cfg_value = { "pos": Vector3.ZERO, "dir": 0 } # Needs to be an array.
	_check_entry_configured(test)
	
	# Skip over non-dictionary element.
	test.cfg_value = [ Vector3.ONE, { "pos": Vector3.ZERO, "dir": 0 } ]
	test.prop_value = [ Transform.IDENTITY ]
	_check_entry_configured(test)
	
	# Invalid floating point values.
	test.cfg_value = [
		{ "pos": Vector3(0.0, INF, -10.0), "dir": 180 },
		{ "pos": Vector3(-2.0, 0.5, 0.0), "dir": -NAN }
	]
	test.prop_value = []
	_check_entry_configured(test)
	
	test.cfg_value = [ { "pos": Vector3(0.0, 0.0, 100.0), "dir": 180.0 } ]
	var hand_transform := Transform.IDENTITY.rotated(Vector3.UP, PI)
	hand_transform.origin = Vector3(0.0, 0.0, 100.0)
	test.prop_value = [ hand_transform ]
	_check_entry_configured(test)
	
	# AssetEntryTable.paint_plane_transform
	test.cfg_name = ""
	test.prop_name = "paint_plane_transform"
	test.prop_value = Transform.IDENTITY.scaled(Vector3(100.0, 1.0, 100.0))
	_check_entry_configured(test)
	
	test.cfg_name = "paint_plane"
	test.cfg_value = Vector2(NAN, INF) # Invalid floating-point data.
	_check_entry_configured(test)
	
	test.cfg_value = Vector2(20.0, 10.0)
	test.prop_value = Transform.IDENTITY.scaled(Vector3(20.0, 1.0, 10.0))
	_check_entry_configured(test)
	
	test.cfg_value = Vector2(-4.0, -32.0) # Negatives are ignored.
	test.prop_value = Transform.IDENTITY.scaled(Vector3(4.0, 1.0, 32.0))
	_check_entry_configured(test)
	
	# AssetEntrySkybox.energy
	test.entry = AssetEntrySkybox.new()
	test.cfg_name = ""
	test.prop_name = "energy"
	test.prop_value = 1.0
	_check_entry_configured(test)
	
	test.cfg_name = "strength"
	test.cfg_value = INF
	_check_entry_configured(test)
	
	test.cfg_value = 128.0
	test.prop_value = 128.0
	_check_entry_configured(test)
	
	test.cfg_value = -1.0 # Minimum energy is 0.
	test.prop_value = 0.0
	_check_entry_configured(test)
	
	# AssetEntrySkybox.rotation
	test.cfg_name = ""
	test.prop_name = "rotation"
	test.prop_value = Vector3.ZERO
	_check_entry_configured(test)
	
	test.cfg_name = "rotation"
	test.cfg_value = Vector3(0.0, INF, 90.0)
	_check_entry_configured(test)
	
	test.cfg_value = Vector3(-90.0, 0.0, 180.0)
	test.prop_value = Vector3(-PI / 2, 0.0, PI)
	_check_entry_configured(test)
	
	# AssetEntryTemplateImage.textbox_list
	test.entry = AssetEntryTemplateImage.new()
	test.cfg_name = ""
	test.prop_name = "textbox_list"
	test.prop_value = []
	_check_entry_configured(test)
	
	test.cfg_name = "textboxes"
	test.cfg_value = Rect2(0.0, 0.0, 50.0, 25.0) # Needs to be array or dict.
	_check_entry_configured(test)
	
	test.cfg_value = [ {} ] # Check default values for textbox.
	var default_textbox := TemplateTextbox.new()
	default_textbox.rect = Rect2(0.0, 0.0, 100.0, 100.0)
	test.prop_value = [ default_textbox ]
	_check_entry_configured(test)
	
	test.cfg_value = { "t1": {}, "t2": {} } # v0.1.x backwards compatibility.
	test.prop_value = [ default_textbox, default_textbox ]
	_check_entry_configured(test)
	
	# All valid inputs.
	test.cfg_value = [{ "x": 10, "y": 10, "w": 205, "h": 100, "rot": 90,
			"lines": 2, "text": "Default text!" }]
	var valid_textbox := TemplateTextbox.new()
	valid_textbox.rect = Rect2(10.0, 10.0, 205.0, 100.0)
	valid_textbox.rotation = 90.0
	valid_textbox.lines = 2
	valid_textbox.text = "Default text!"
	test.prop_value = [ valid_textbox ]
	_check_entry_configured(test)
	
	# Floats in place of integers, invalid floating point data,
	# minimum number of lines.
	test.cfg_value = [{ "x": 0, "y": 0, "w": 155.25, "h": 70, "rot": NAN,
			"lines": -1, "text": "*surprised pikachu face*" }]
	valid_textbox.rect = Rect2(0.0, 0.0, 100.0, 70.0)
	valid_textbox.rotation = 0.0
	valid_textbox.lines = 1
	valid_textbox.text = "*surprised pikachu face*"
	_check_entry_configured(test)
	
	# Maximum number of lines.
	test.cfg_value = [{ "x": 100, "y": 100, "w": 550, "h": 52, "rot": 720,
			"lines": 100, "text": "O.O" }]
	valid_textbox.rect = Rect2(100.0, 100.0, 550.0, 52.0)
	valid_textbox.rotation = 720.0
	valid_textbox.lines = 5
	valid_textbox.text = "O.O"
	_check_entry_configured(test)
	
	# This should already be tested in AdvancedConfigFile, but just check to
	# see if the pattern matching works as we expect.
	var cfg_file := AdvancedConfigFile.new()
	cfg_file.set_value("white_texture.jpg", "name", "NEW_NAME_0")
	cfg_file.set_value("*_texture.???", "name", "NEW_NAME_1")
	cfg_file.set_value("*.png", "name", "NEW_NAME_2")
	cfg_file.set_value("*", "name", "NEW_NAME_3")
	
	var entry := AssetEntrySingle.new()
	test.catalog.apply_config_to_entry(entry, cfg_file, "white_texture.png", false, 0)
	assert_eq(entry.name, "NEW_NAME_1")
	test.catalog.apply_config_to_entry(entry, cfg_file, "white_texture.jpg", false, 0)
	assert_eq(entry.name, "NEW_NAME_0")
	test.catalog.apply_config_to_entry(entry, cfg_file, "black_texture.png", false, 0)
	assert_eq(entry.name, "NEW_NAME_1")
	test.catalog.apply_config_to_entry(entry, cfg_file, "texture_black.png", false, 0)
	assert_eq(entry.name, "NEW_NAME_2")
	test.catalog.apply_config_to_entry(entry, cfg_file, "texture_black.jpg", false, 0)
	assert_eq(entry.name, "NEW_NAME_3")
	
	# Remove the directory now that we are done with this test.
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


class TestConfigureSettings:
	extends Reference
	
	var catalog: AssetPackTypeCatalog
	var entry: AssetEntrySingle
	
	var section_name: String
	
	# Emulate a property in a config file - if name is empty, then emulate the
	# file being completely empty.
	var cfg_name: String
	var cfg_value
	
	# The property we are checking to see if the value is what we expect.
	var prop_name: String
	var prop_value
	
	var scale_is_vec2: bool = false
	var die_num_faces: int = 0


func _check_entry_configured(settings: TestConfigureSettings):
	var cfg_file := AdvancedConfigFile.new()
	if not settings.section_name.empty():
		cfg_file.set_value(settings.section_name, settings.cfg_name,
				settings.cfg_value)
	
	settings.catalog.apply_config_to_entry(settings.entry, cfg_file,
			settings.section_name, settings.scale_is_vec2,
			settings.die_num_faces)
	
	var true_value = settings.entry.get(settings.prop_name)
	var expected_value = settings.prop_value
	
	# When Gut checks for the equality of objects, it checks to see if the
	# pointers are equal, which we don't want - we want to check if all of the
	# relevant properties are equal to each other.
	if expected_value is PhysicsMaterial:
		assert_is(true_value, PhysicsMaterial)
		assert_eq(true_value.friction, expected_value.friction)
		assert_eq(true_value.rough, expected_value.rough)
		assert_eq(true_value.bounce, expected_value.bounce)
		assert_eq(true_value.absorbent, expected_value.absorbent)
	elif expected_value is DiceFaceValueList:
		assert_is(true_value, DiceFaceValueList)
		var true_list: Array = true_value.face_value_list
		var expected_list: Array = expected_value.face_value_list
		assert_eq(true_list.size(), expected_list.size())
		
		for index in range(true_list.size()):
			var true_face_value = true_list[index]
			var expected_face_value = expected_list[index]
			assert_is(true_face_value, DiceFaceValue)
			assert_is(expected_face_value, DiceFaceValue)
			
			# Can't use assert_eq here, there's too much floating point error
			# that can occur when converting rotation to normal.
			assert_true(true_face_value.normal.is_equal_approx(
					expected_face_value.normal))
			_check_custom_value_eq(true_face_value.value,
					expected_face_value.value)
	elif expected_value is CustomValue:
		assert_is(true_value, CustomValue)
		_check_custom_value_eq(true_value, expected_value)
	elif settings.entry is AssetEntryTemplateImage and \
			settings.prop_name == "textbox_list":
		assert_eq(typeof(true_value), TYPE_ARRAY)
		assert_eq(typeof(expected_value), TYPE_ARRAY)
		assert_eq(true_value.size(), expected_value.size())
		for index in range(true_value.size()):
			var true_textbox = true_value[index]
			var expected_textbox = expected_value[index]
			assert_is(true_textbox, TemplateTextbox)
			assert_is(expected_textbox, TemplateTextbox)
			assert_eq(true_textbox.rect, expected_textbox.rect)
			assert_eq(true_textbox.rotation, expected_textbox.rotation)
			assert_eq(true_textbox.lines, expected_textbox.lines)
			assert_eq(true_textbox.text, expected_textbox.text)
	else:
		assert_eq_deep(true_value, expected_value)


func _check_custom_value_eq(a: CustomValue, b: CustomValue):
	assert_eq(a.value_type, b.value_type)
	match a.value_type:
		CustomValue.ValueType.TYPE_INT:
			assert_eq(a.value_int, b.value_int)
		CustomValue.ValueType.TYPE_FLOAT:
			assert_eq(a.value_float, b.value_float)
		CustomValue.ValueType.TYPE_STRING:
			assert_eq(a.value_string, b.value_string)
