# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
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

extends Reference

class_name PieceCache

var _entry_path: String = ""
var _is_thumbnail: bool = false

# Cache the piece to a scene file, so it can be loaded in quicker.
func cache() -> void:
	if _entry_path.empty():
		push_error("Internal entry path is empty!")
		return
	
	var piece_entry = AssetDB.search_path(_entry_path)
	if piece_entry.empty():
		push_error("Entry path '%s' does not exist in the AssetDB!" % _entry_path)
		return
	
	if piece_entry.has("entry_names"):
		push_error("Cannot cache stack '%s'!" % _entry_path)
		return
	
	# TODO: Can optimise this further if we can just have the mesh instance for
	# thumbnails, since we're just displaying the object.
	# TODO: We save thumbnails of tables as pieces so they can be displayed
	# in previews, similar to the point above, maybe previews should just be
	# able to display mesh instances?
	var piece: RigidBody = null
	if piece_entry.has("hands") and not _is_thumbnail:
		piece = PieceBuilder.build_table(piece_entry)
	else:
		piece = PieceBuilder.build_piece(piece_entry, not _is_thumbnail)
	
	# Set the name of the root node to the name of the piece.
	piece.name = _entry_path.get_file()
	
	var packed_scene = PackedScene.new()
	packed_scene.pack(piece)
	ResourceSaver.save(_cache_path() + "." + _scene_ext(), packed_scene)
	
	ResourceManager.free_object(piece)
	
	if ProjectSettings.has_setting("application/config/version"):
		var version_file = File.new()
		var version_path = _cache_path() + ".version"
		
		var err = version_file.open(version_path, File.WRITE)
		if err == OK:
			version_file.store_line(ProjectSettings.get_setting("application/config/version"))
			version_file.close()
		else:
			push_error("Could not open '%s' (error %d)!" % [version_path, err])

# Checks if the cache for this piece exists.
# Returns: If the cache exists for the given piece, and it is not outdated.
func exists() -> bool:
	if _entry_path.empty():
		push_error("Internal entry path is empty!")
		return false
	
	var scene_path = _cache_path() + "." + _scene_ext()
	
	var file = File.new()
	if not file.file_exists(scene_path):
		return false
	
	if ProjectSettings.has_setting("application/config/version"):
		var version_path = _cache_path() + ".version"
		if not file.file_exists(version_path):
			return false
		
		if file.open(version_path, File.READ) != OK:
			return false
		
		var piece_version = file.get_line()
		file.close()
		
		if piece_version != ProjectSettings.get_setting("application/config/version"):
			return false
	
	return true

# Retrieves a cached piece created by the cache() function.
# Returns: The cached piece. Null if the cache does not exist, or is outdated.
func get_scene() -> RigidBody:
	if not exists():
		return null
	
	var scene_path = _cache_path() + "." + _scene_ext()
	var packed_scene: PackedScene = ResourceManager.load_res(scene_path)
	if not packed_scene.can_instance():
		push_error("Cache '%s' has no nodes!" % scene_path)
		return null
	
	var piece: RigidBody = packed_scene.instance()
	
	# Pieces need their own separate outline shaders.
	if piece is Piece:
		piece.setup_outline_material()
	
	return piece

# Determines if a piece is suitable to be cached.
# Returns: If the piece should be cached or not.
# piece_entry: The entry of the piece to check.
static func should_cache(piece_entry: Dictionary) -> bool:
	if piece_entry.has("scene_path") and piece_entry.has("collision_mode"):
		if piece_entry["scene_path"].begins_with("user://"):
			if piece_entry["collision_mode"] == PieceBuilder.COLLISION_MULTI_CONVEX:
				return true
	
	return false

# entry_path: The entry path of the cached piece we want to access.
# thumbnail: If true, access the thumbnail version of the given piece.
func _init(entry_path: String, thumbnail: bool = false):
	if not AssetDB.search_path(entry_path).empty():
		_entry_path = entry_path
		_is_thumbnail = thumbnail
	else:
		push_error("Entry path '%s' does not exist in the AssetDB!" % entry_path)

# Get the base path for all cache files for this piece.
func _cache_path() -> String:
	var extension = "tmb_cache" if _is_thumbnail else "cache"
	return "user://assets/%s.%s" % [_entry_path, extension]

func _scene_ext() -> String:
	return "tscn" if OS.is_debug_build() else "scn"
