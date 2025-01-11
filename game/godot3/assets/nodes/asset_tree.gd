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

extends Node

## An organised tree of all of the assets in the AssetDB.
##
## This allows UI windows like the objects menu to display all imported assets
## in a sorted, organised way. Each node is a directory, which can contain other
## directories, as well as a list of [AssetEntry] from the AssetDB.
##
## TODO: Test this node, as well as [AssetNode], fully once they are complete.


## Fired when the tree is generated after the AssetDB has changed.
signal tree_generated()


## The ID for pack nodes that contain all asset packs.
const ALL_PACKS_ID := "%ALL_PACKS%"

## The ID for the node that contains individual cards.
const INDIVIDUAL_CARDS_ID := "%INDIVIDUAL_CARDS%"

## The ID for the node that contains dice with a non-standard number of faces.
const OTHER_DICE_ID := "%OTHER_DICE%"

## The ID for the node that contains individual tokens.
const INDIVIDUAL_TOKENS_ID := "%INDIVIDUAL_TOKENS%"

## The list of asset types that should not be added to a type directory, since
## they should already be in a category of their own.
const SOLO_TYPE_LIST := [ "games", "skyboxes", "tables", "templates" ]


# The root node, which has an empty ID so that we can have paths that start with
# the "/" character.
var _root := AssetNode.new("")


func _ready():
	AssetDB.connect("content_changed", self, "_on_AssetDB_content_changed")


## Get the [AssetNode] at the given path.
## Returns [code]null[/code] if a node does not exist at that location.
func get_asset_node(full_path: String) -> AssetNode:
	var components := full_path.split("/", true)
	if components.size() < 2:
		push_error("Invalid asset node path '%s'" % full_path)
		return null
	
	if components[0] != "":
		push_error("Expected asset node path to start with '/'")
		return null
	
	# Path is "/".
	if components[1] == "":
		return _root
	
	var current_node := _root
	var component_index := 1
	while component_index < components.size():
		var node_id := components[component_index]
		current_node = current_node.get_child(node_id)
		if current_node == null:
			push_error("Path '%s' is invalid, node '%s' does not exist" % [
					full_path, node_id])
			return null
		
		component_index += 1
	
	return current_node


## Get the translated name for nodes with the given ID.
func get_node_name(node_id: String) -> String:
	match node_id:
		# Categories:
		"objects":
			return tr("Objects")
		"games":
			return tr("Games")
		"audio":
			return tr("Audio")
		"skyboxes":
			return tr("Skyboxes")
		"tables":
			return tr("Tables")
		"templates":
			return tr("Templates")
		
		# Special IDs:
		ALL_PACKS_ID:
			return tr("All Packs")
		INDIVIDUAL_CARDS_ID:
			return tr("Individual Cards")
		OTHER_DICE_ID:
			return tr("Other")
		INDIVIDUAL_TOKENS_ID:
			return tr("Individual Pieces")
		
		# Objects:
		"boards":
			return tr("Boards")
		"cards":
			return tr("Cards")
		"containers":
			return tr("Containers")
		"dice":
			return tr("Dice")
		"music":
			return tr("Music")
		"pieces":
			return tr("Pieces")
		"sounds":
			return tr("Sound Effects")
		"speakers":
			return tr("Speakers")
		"timers":
			return tr("Timers")
		"tokens":
			return tr("Tiles / Tokens")
		
		# Dice:
		"d4":
			return tr("d4")
		"d6":
			return tr("d6")
		"d8":
			return tr("d8")
		"d10":
			return tr("d10")
		"d12":
			return tr("d12")
		"d20":
			return tr("d20")
		_:
			# Check to see if the ID is that of an asset pack.
			for element in AssetDB.get_all_packs():
				var pack: AssetPack = element
				if pack.id == node_id:
					return pack.name
			
			push_error("Could not find name for node with ID '%s'" % node_id)
			return "#ERROR#"


## Get the translated tooltip hint for nodes with the given ID.
func get_node_hint(node_id: String) -> String:
	match node_id:
		# Special IDs:
		ALL_PACKS_ID:
			return tr("Browse assets from all imported asset packs.")
		INDIVIDUAL_CARDS_ID:
			return tr("Browse individual cards, instead of pre-made decks.")
		OTHER_DICE_ID:
			return tr("Browse dice with non-standard numbers of faces.")
		INDIVIDUAL_TOKENS_ID:
			return tr("Browse individual tiles and tokens, instead of pre-made stacks.")
		
		# Objects:
		"boards":
			return tr("Boards are used as a surface to place objects on.")
		"cards":
			return tr("Cards can be stacked on top of each other, and placed in your hand.")
		"containers":
			return tr("Containers can hold any number of other objects.")
		"dice":
			return tr("Dice can be rolled to create random values.")
		"music":
			# TODO: Revisit hint for music and sounds, are they still accurate
			# after v0.2.0 re-write?
			return tr("Music consists of audio tracks that are played on repeat.")
		"pieces":
			return tr("Pieces are generic objects with no special functionality.")
		"sounds":
			return tr("Sound effects are audio tracks that are played one-off.")
		"speakers":
			return tr("Speakers can play music or sound effects.")
		"timers":
			return tr("Timers can be used in stopwatch, timer, or clock mode.")
		"tokens":
			return tr("Tiles and tokens can be stacked on top of each other.")
		_:
			return ""


# Add all registered packs as directories to the given node that contain the
# specified asset types.
func _add_all(root: AssetNode, types: Array) -> void:
	_add_pack(root, ALL_PACKS_ID, types)
	for element in AssetDB.get_all_packs():
		var asset_pack: AssetPack = element
		_add_pack(root, asset_pack.id, types)


# Add a pack directory to a node, using the contents of the AssetDB.
# If the ID of the pack is [code]%ALL_PACKS%[/code], all of the packs currently
# registered in the AssetDB will be used. If there are no entries for any of the
# given types, the pack is not added as a directory.
func _add_pack(root: AssetNode, pack_id: String, types: Array) -> void:
	var pack_node := AssetNode.new(pack_id)
	
	for element in types:
		var type: String = element
		_add_type(pack_node, type)
	
	if pack_node.entry_list.empty() and pack_node.get_child_count() == 0:
		return
	
	root.add_child(pack_node)


# Add a type directory to a pack node, using the contents of the AssetDB.
# If there are no entries for the given type and pack, then the directory is not
# added.
func _add_type(pack_node: AssetNode, type: String) -> void:
	var type_entries := []
	if pack_node.id == ALL_PACKS_ID:
		type_entries = AssetDB.get_all_entries(type)
	else:
		var pack := AssetDB.get_pack(pack_node.id)
		if pack == null:
			push_error("Pack '%s' does not exist, cannot create type directory" % pack_node.id)
			return
		
		type_entries = pack.get_type(type)
	
	# If there are no compatible entries for this type, don't bother adding a
	# node for it.
	if type_entries.empty():
		return
	
	# If this type will be the only one in it's category, we can just add the
	# entries directly to the pack node, and save the user an extra click.
	if type in SOLO_TYPE_LIST:
		pack_node.entry_list = type_entries
		return
	
	var type_node := AssetNode.new(type)
	
	match type:
		"cards":
			# Create a separate node for individual cards. Stacks of cards will
			# be added as direct children of the type.
			var individual_cards := AssetNode.new(INDIVIDUAL_CARDS_ID)
			individual_cards.entry_list = type_entries
			type_node.add_child(individual_cards)
		"dice":
			# Separate the dice into different directories depending on how many
			# faces it has.
			for element in type_entries:
				var dice_entry: AssetEntryDice = element
				var face_value_list: DiceFaceValueList = dice_entry.face_value_list
				
				var dir_id := OTHER_DICE_ID
				match face_value_list.face_value_list.size():
					4:
						dir_id = "d4"
					6:
						dir_id = "d6"
					8:
						dir_id = "d8"
					10:
						dir_id = "d10"
					12:
						dir_id = "d12"
					20:
						dir_id = "d20"
				
				if not type_node.has_child(dir_id):
					var face_node := AssetNode.new(dir_id)
					type_node.add_child(face_node)
				
				var face_node := type_node.get_child(dir_id)
				# Since the original array is in ID order, this new array will
				# also be in ID order.
				face_node.entry_list.push_back(dice_entry)
		"tokens":
			# Create a separate node for individual tokens. Stacks of tokens
			# will be added as direct children of the type.
			var individual_tokens := AssetNode.new(INDIVIDUAL_TOKENS_ID)
			individual_tokens.entry_list = type_entries
			type_node.add_child(individual_tokens)
		_:
			type_node.entry_list = type_entries
	
	pack_node.add_child(type_node)


func _on_AssetDB_content_changed():
	print("AssetTree: Generating 'objects' directory...")
	if _root.has_child("objects"):
		_root.remove_child("objects")
	
	var objects := AssetNode.new("objects")
	_add_all(objects, [
		"boards",
		"cards",
		"containers",
		"dice",
		"pieces",
		"speakers",
		"timers",
		"tokens"
	])
	_root.add_child(objects)
	# TODO: Add stacks for cards and tokens.
	
	print("AssetTree: Generating 'games' directory...")
	if _root.has_child("games"):
		_root.remove_child("games")
	
	var games := AssetNode.new("games")
	_add_all(games, [ "games" ])
	_root.add_child(games)
	
	print("AssetTree: Generating 'audio' directory...")
	if _root.has_child("audio"):
		_root.remove_child("audio")
	
	var audio := AssetNode.new("audio")
	_add_all(audio, [ "music", "sounds" ])
	_root.add_child(audio)
	
	print("AssetTree: Generating 'skyboxes' directory...")
	if _root.has_child("skyboxes"):
		_root.remove_child("skyboxes")
	
	var skyboxes := AssetNode.new("skyboxes")
	_add_all(skyboxes, [ "skyboxes" ])
	_root.add_child(skyboxes)
	
	print("AssetTree: Generating 'tables' directory...")
	if _root.has_child("tables"):
		_root.remove_child("tables")
	
	var tables := AssetNode.new("tables")
	_add_all(tables, [ "tables" ])
	_root.add_child(tables)
	
	print("AssetTree: Generating 'templates' directory...")
	if _root.has_child("templates"):
		_root.remove_child("templates")
	
	var templates := AssetNode.new("templates")
	_add_all(templates, [ "templates" ])
	_root.add_child(templates)
	
	print("AssetTree: All directories generated.")
	emit_signal("tree_generated")
