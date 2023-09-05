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

## Test the classes that hold data about assets, that being [AssetEntry],
## [AssetPack], and the AssetDB.


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
	
	# This is not how packs are intended to be manipulated, this is purely to
	# test if reset_dictionary() works as expected.
	pack.tables = [c_temp]
	assert_eq_deep(pack.tables, [c_temp])
	assert_eq_deep(pack.get_type("tables"), [a, b])
	
	pack.reset_dictionary()
	assert_eq_deep(pack.tables, [c_temp])
	assert_eq_deep(pack.get_type("tables"), [c_temp])
	
	pack.clear_all_entries()
	assert_true(pack.is_empty())
	
	pack.add_entry("?????", a)
	assert_true(pack.is_empty())
	assert_true(pack.get_type("?????").empty())


func test_default_asset_pack() -> void:
	var ttc_pack := preload("res://assets/default_pack/ttc_pack.tres")
	ttc_pack.reset_dictionary() # Loaded from a file.
	
	assert_eq(ttc_pack.id, "TabletopClub")
	assert_true(ttc_pack.is_bundled())
	
	var type_dict := ttc_pack.get_all()
	for type in type_dict:
		var type_arr: Array = type_dict[type]
		
		# The default pack should contain at least one of each type of item.
		assert_false(type_arr.empty())
		
		for entry_index in range(type_arr.size()):
			var entry: AssetEntry = type_arr[entry_index]
			
			# Entry IDs should not be empty.
			assert_false(entry.id.empty())
			
			# The entry should have the correct pack and type information.
			assert_eq(entry.pack, "TabletopClub")
			assert_eq(entry.type, type)
			
			# Entries must be in a sorted list (by ID, ascending).
			if entry_index > 0:
				var prev_entry: AssetEntry = type_arr[entry_index - 1]
				assert_gt(entry.id, prev_entry.id)
			
			if entry is AssetEntryAudio:
				assert_true(ResourceLoader.exists(entry.audio_path))
			
			if entry is AssetEntryCollection:
				assert_false(entry.is_empty())
				assert_false(entry.get_single_type().empty())
			
			if entry is AssetEntrySave:
				# TODO: Re-enable once the save files have been converted.
				pass #assert_true(ResourceLoader.exists(entry.save_file_path))
			
			if entry is AssetEntryScene:
				assert_true(ResourceLoader.exists(entry.scene_path))
				
				for texture_path in entry.texture_overrides:
					assert_true(ResourceLoader.exists(texture_path))
			
			if entry is AssetEntrySkybox:
				assert_true(ResourceLoader.exists(entry.texture_path))
			
			if entry is AssetEntryTemplate:
				assert_true(ResourceLoader.exists(entry.template_path))


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


func _on_AssetDB_content_changed():
	_asset_db_content_changed_flag = true
