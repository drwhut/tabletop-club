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

extends Spatial

onready var _camera = $Camera
onready var _pieces = $Pieces
onready var _world_environment = $WorldEnvironment

const BALANCE_ASSETS_RATIO = 0.5
const CAMERA_ROTATION_RATE = 0.05
const DESPAWN_PLANE = -40.0
const FALL_SPEED = 10.0
const SPAWN_PLANE = 40.0

var _camera_distance: float = 1.0
var _time_in_scene: float = 0.0

var _asset_chances = {}
var _rng = RandomNumberGenerator.new()

func _ready():
	_camera_distance = _camera.translation.z
	_rng.randomize()
	
	var db = AssetDB.get_db()
	for pack in db:
		var pack_meta = {}
		var pack_total = 0
		var num_types = 0
		for type in db[pack]:
			var file_type = AssetDB.ASSET_PACK_SUBFOLDERS[type]["type"]
			if file_type == AssetDB.ASSET_TEXTURE or file_type == AssetDB.ASSET_SCENE:
				if type != "tables":
					var approved_assets = {
						"chances": 0,
						"assets": []
					}
					for i in range(db[pack][type].size()):
						var asset: Dictionary = db[pack][type][i]
						if asset.has("main_menu"):
							if asset["main_menu"] == true:
								approved_assets["assets"].append(i)
								approved_assets["chances"] += 1
					
					var type_total = approved_assets["chances"]
					pack_meta[type] = approved_assets
					pack_total += type_total
					num_types += 1
		
		if pack_total > 0:
			pack_meta["/total"] = pack_total
			pack_meta["/chances"] = pack_total
			pack_meta["/average"] = ceil(float(pack_total) / num_types)
			_asset_chances[pack] = pack_meta
	
	if not _asset_chances.empty():
		var overall_total = 0
		for pack in _asset_chances:
			overall_total += _asset_chances[pack]["/total"]
		_asset_chances["/average"] = overall_total / _asset_chances.size()
		_asset_chances["/total"] = overall_total
		
		# Adjust the chances of picking certain types of assets, so
		# under-populated assets appear a bit more often.
		var new_pack_total = 0
		var pack_average = _asset_chances["/average"]
		for pack in _asset_chances:
			if not pack.begins_with("/"):
				var new_type_total = 0
				var pack_type_average = _asset_chances[pack]["/average"]
				for type in _asset_chances[pack]:
					if not type.begins_with("/"):
						var old_type_chances = _asset_chances[pack][type]["chances"]
						if old_type_chances > 0:
							var adjustment = BALANCE_ASSETS_RATIO * (pack_type_average - old_type_chances)
							var new_type_chances = int(old_type_chances + adjustment)
							
							_asset_chances[pack][type]["chances"] = new_type_chances
							new_type_total += new_type_chances
				
				_asset_chances[pack]["/total"] = new_type_total
				
				var old_pack_chances = _asset_chances[pack]["/chances"]
				if old_pack_chances > 0:
					var adjustment = BALANCE_ASSETS_RATIO * (pack_average - old_pack_chances)
					var new_pack_chances = int(old_pack_chances + adjustment)
					
					_asset_chances[pack]["/chances"] = new_pack_chances
					new_pack_total += new_pack_chances
		
		_asset_chances["/total"] = new_pack_total
	
	# Pick a random default skybox from the default asset pack.
	# TODO: Maybe add a method to AssetDB for returning an environment based on
	# a given skybox entry?
	var skybox_entry = AssetDB.random_asset("TabletopClub", "skyboxes", true)
	if not skybox_entry.empty():
		var skybox = PanoramaSky.new()
		
		if skybox_entry.has("texture_path"):
			var texture_path = skybox_entry["texture_path"]
			if not texture_path.empty():
				var texture: Texture = ResourceManager.load_res(texture_path)
				skybox.panorama = texture
		
		var env = _world_environment.environment
		var radiance = env.background_sky.radiance_size
		skybox.radiance_size = radiance
		env.background_sky = skybox
		
		env.background_sky_rotation_degrees = skybox_entry["rotation"]
		env.background_energy = skybox_entry["strength"]
		
		_world_environment.environment = env
	
	PieceFactory.connect("finished", self, "_on_PieceFactory_finished")

func _process(delta):
	_time_in_scene += delta
	
	var camera_x = _camera_distance * sin(_time_in_scene * CAMERA_ROTATION_RATE)
	var camera_z = _camera_distance * cos(_time_in_scene * CAMERA_ROTATION_RATE)
	
	_camera.transform.origin.x = camera_x
	_camera.transform.origin.z = camera_z
	
	_camera.transform = _camera.transform.looking_at(Vector3.ZERO, Vector3.UP)

func _decide_next_piece() -> Dictionary:
	if not _asset_chances.empty():
		var pack_total = _asset_chances["/total"]
		var rand_pack = _rng.randi_range(1, pack_total)
		
		var pack_running_total = 0
		var pack_selected = ""
		for pack in _asset_chances:
			if not pack.begins_with("/"):
				pack_running_total += _asset_chances[pack]["/chances"]
				if pack_running_total >= rand_pack:
					pack_selected = pack
					break
		
		if not pack_selected.empty():
			var type_total = _asset_chances[pack_selected]["/total"]
			var rand_type = _rng.randi_range(1, type_total)
			
			var type_running_total = 0
			var type_selected = ""
			for type in _asset_chances[pack_selected]:
				if not type.begins_with("/"):
					type_running_total += _asset_chances[pack_selected][type]["chances"]
					if type_running_total >= rand_type:
						type_selected = type
						break
			
			if not type_selected.empty():
				var possible_objects = _asset_chances[pack_selected][type_selected]["assets"]
				var random_db_index = possible_objects[_rng.randi() % possible_objects.size()]
				return AssetDB.get_db()[pack_selected][type_selected][random_db_index]
	
	return {}

func _on_PieceFactory_finished(order: int, piece: Piece):
	# This should be the only node using the PieceFactory at the time, so
	# accept all pieces that come out.
	PieceFactory.accept(order)
	
	piece.gravity_scale = 0.0
	
	# Determine a random position and rotation for the piece.
	var rot = 2 * PI * _rng.randf()
	var dst = max(_camera_distance - 2*piece.get_radius(), 0.0)
	var new_origin = Vector3(dst*cos(rot), SPAWN_PLANE, dst*sin(rot))
	piece.transform.origin = new_origin
	
	var new_basis = piece.transform.basis
	new_basis = new_basis.rotated(Vector3.UP, 2 * PI * _rng.randf())
	new_basis = new_basis.rotated(Vector3.RIGHT, 2 * PI * _rng.randf())
	piece.transform.basis = new_basis
	
	piece.linear_velocity = Vector3(0, -FALL_SPEED, 0)
	
	# Stop sound effects from playing if the pieces collide with each other.
	piece.contact_monitor = false
	
	_pieces.add_child(piece)

func _on_SpawnTimer_timeout():
	var next_piece = _decide_next_piece()
	if not next_piece.empty():
		PieceFactory.request(next_piece)
	
	# De-spawn any pieces that have fallen off the screen.
	for piece in _pieces.get_children():
		if piece.translation.y < DESPAWN_PLANE:
			_pieces.remove_child(piece)
			ResourceManager.queue_free_object(piece)

func _on_FallingWorld_tree_exiting():
	PieceFactory.disconnect("finished", self, "_on_PieceFactory_finished")
