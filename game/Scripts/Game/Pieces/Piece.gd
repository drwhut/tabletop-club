# tabletop-club
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021 Tabletop Club contributors (see game/CREDITS.tres).
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

extends RigidBody

class_name Piece

signal client_set_hover_position(piece)
signal piece_exiting_tree(piece)

const ANGULAR_FORCE_SCALAR = 25.0
const HARMONIC_DAMPENING = 0.5
const HELL_HEIGHT = -50.0
const HOVER_INACTIVE_DURATION = 5.0
const LINEAR_FORCE_SCALAR = 50.0
const ROTATION_LOCK_AT = 0.001
const SHAKING_THRESHOLD = 1000.0
const SPAWN_HEIGHT = 2.0
const TRANSFORM_LERP_ALPHA = 0.9

export(NodePath) var effect_player_path: String

# Set if you know where the mesh instance is, and if there is only one mesh
# instance. Otherwise, the game will try and find it automatically when it
# needs it (e.g. when using a custom piece).
export(NodePath) var mesh_instance_path: String

# TODO: export(RandomAudioSample)
# See: https://github.com/godotengine/godot/pull/44879
# NOTE: Contact reporting needs to be enabled for these sounds to be played.
export(Resource) var table_collide_fast_sounds
export(Resource) var table_collide_slow_sounds

var piece_entry: Dictionary = {}

# When setting these vectors, make sure you call set_angular_lock(false),
# otherwise the piece won't rotate towards the orientation!
var srv_hover_basis = Basis.IDENTITY
var srv_hover_position = Vector3()

var srv_retrieve_from_hell: bool = true

var _srv_hover_offset = Vector3()
var _srv_hover_player = 0

var _srv_hover_time_since_update = 0.0

var _last_server_state = {}
var _last_slow_table_collision = 0.0

var _last_velocity = Vector3()
var _new_velocity = Vector3()

var _outline_material: ShaderMaterial = null

var _expose_albedo_color = true

# Apply a texture to the piece.
# texture: The texture to apply.
# surface: The index of the surface to apply the texture to.
func apply_texture(texture: Texture, surface: int = 0) -> void:
	for mesh_instance in get_mesh_instances():
		var material = SpatialMaterial.new()
		material.albedo_texture = texture
		
		mesh_instance.set_surface_material(surface, material)

# If you are hovering this piece, ask the server to flip the piece vertically.
master func flip_vertically() -> void:
	if get_tree().get_rpc_sender_id() == _srv_hover_player:
		srv_hover_basis = srv_hover_basis.rotated(transform.basis.z, PI)
		srv_wake_up()

# Get the current albedo colour in the piece's material.
# Returns: The current albedo colour.
func get_albedo_color() -> Color:
	if not _expose_albedo_color:
		push_error("Albedo color is not exposed!")
		return Color.white
	
	var mesh_instances = get_mesh_instances()
	if not mesh_instances.empty():
		var mesh_instance = mesh_instances[0]
		if mesh_instance.get_surface_material_count() > 0:
			var material = mesh_instance.get_surface_material(0)
			return material.albedo_color
	
	return Color.white

# Get the piece's collision shapes.
# Returns: An array of the piece's collision shapes.
func get_collision_shapes() -> Array:
	var out = []
	for child in get_children():
		if child is CollisionShape:
			out.append(child)
	return out

# Get the piece's effect player.
# Returns: The piece's effect player if it exists, null if it doesn't.
func get_effect_player() -> AudioStreamPlayer3D:
	if effect_player_path:
		var effect_player = get_node(effect_player_path)
		if effect_player is AudioStreamPlayer3D:
			return effect_player
	
	return null

# Get the piece's mesh instances.
# Returns: An array of the piece's mesh instances.
func get_mesh_instances() -> Array:
	if mesh_instance_path:
		var mesh_instance = get_node(mesh_instance_path)
		if mesh_instance is MeshInstance:
			return [mesh_instance as MeshInstance]
	
	var out = []
	for collision_shape in get_collision_shapes():
		for child in collision_shape.get_children():
			if child is MeshInstance:
				out.append(child)
	return out

# Get the radius of the bounding sphere of the piece.
# Returns: The radius of the bounding sphere.
func get_radius() -> float:
	var size = get_size()
	var diameter = max(size.x, max(size.y, size.z))
	
	return diameter / 2.0

# Get the size of the piece.
# NOTE: If you know the piece is not a custom piece, then you can just use the
# "scale" key in the piece entry.
# Returns: A Vector3 representing the size of the piece in all three axes.
func get_size() -> Vector3:
	if piece_entry.has("bounding_box"):
		return piece_entry["bounding_box"][1] - piece_entry["bounding_box"][0]
	
	return piece_entry["scale"]

# Is the albedo colour of the piece able to be changed?
# Returns: If the albedo colour can be changed.
func is_albedo_color_exposed() -> bool:
	return _expose_albedo_color

# Determines if the piece is being shaked.
# Returns: If the piece is being shaked.
func is_being_shaked() -> bool:
	if _new_velocity.dot(_last_velocity) < 0:
		return (_new_velocity - _last_velocity).length_squared() > SHAKING_THRESHOLD
	return false

# Is the piece locked, i.e. unable to move?
# Returns: If the piece is locked.
func is_locked() -> bool:
	return mode == MODE_STATIC

# Called by the server to lock the piece on all clients, with the given
# transform.
puppet func lock_client(locked_transform: Transform) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	mode = MODE_STATIC
	transform = locked_transform

# Play a sound effect from the effect player, if it exists.
# sound: The sound effect to play.
func play_effect(sound: AudioStream) -> void:
	if sound == null:
		return
	
	var effect_player = get_effect_player()
	if effect_player == null:
		return
	
	if effect_player.playing:
		return
	
	effect_player.stream = sound
	effect_player.play()

# Called by the server to remove the piece from the game.
remotesync func remove_self() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if get_parent():
		get_parent().remove_child(self)
		queue_free()

# Request the server to lock the piece.
master func request_lock() -> void:
	srv_lock()

# Request the server to remove the piece.
master func request_remove_self() -> void:
	rpc("remove_self")

# Request the server to set the material's albedo color.
# color: The new albedo color.
# unreliable: Should the server send the RPC unreliably?
master func request_set_albedo_color(color: Color, unreliable: bool = false) -> void:
	if not _expose_albedo_color:
		push_error("Albedo color is not exposed!")
		return
	
	if unreliable:
		rpc_unreliable("set_albedo_color", color)
	else:
		rpc("set_albedo_color", color)

# Request the server to unlock the piece.
master func request_unlock() -> void:
	rpc("unlock")

# If you are hovering the piece, ask the server to reset the orientation of the
# piece.
master func reset_orientation() -> void:
	if get_tree().get_rpc_sender_id() == _srv_hover_player:
		srv_hover_basis = Basis.IDENTITY
		srv_wake_up()

# If you are hovering the piece, rotate it on the y-axis.
# rot: The amount to rotate it by in radians.
master func rotate_y(rot: float) -> void:
	if get_tree().get_rpc_sender_id() == _srv_hover_player:
		if rot == 0.0:
			return
		
		var current_euler = srv_hover_basis.get_euler()
		var current_y_scale = current_euler.y / abs(rot)
		# The .001 is to avoid floating point errors.
		var offset = 1.001
		var target_y_scale = current_y_scale
		if rot > 0.0:
			target_y_scale = floor(current_y_scale + offset)
		else:
			target_y_scale = ceil(current_y_scale - offset)
		var target_y_euler = current_euler
		target_y_euler.y = wrapf(target_y_scale * abs(rot), -PI, PI)
		srv_hover_basis = Basis(target_y_euler)
		
		srv_wake_up()

# Called by the server to set the material's albedo color.
# color: The new albedo color.
remotesync func set_albedo_color(color: Color) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	set_albedo_color_client(color)

# Set the material's albedo color.
# color: The new albedo color.
func set_albedo_color_client(color: Color) -> void:
	if not _expose_albedo_color:
		push_error("Albedo color is not exposed!")
		return
	
	for mesh_instance in get_mesh_instances():
		for surface in range(mesh_instance.get_surface_material_count()):
			var material = mesh_instance.get_surface_material(surface)
			
			# Some materials will already have an albedo colour set, so keep
			# this colour saved so that we don't overwrite and lose it.
			var original_color = material.albedo_color
			var meta_key = "original_color_" + str(surface)
			if material.has_meta(meta_key):
				original_color = material.get_meta(meta_key)
			else:
				material.set_meta(meta_key, original_color)
			
			material.albedo_color = original_color * color

# If you are hovering the piece, ask the server to set the hover position of the
# piece.
# hover_position: The position the hovering piece will go towards.
master func set_hover_position(hover_position: Vector3) -> void:
	# Only allow the hover position to be set if the request is coming from the
	# player that is hovering the piece.
	if get_tree().get_rpc_sender_id() == _srv_hover_player:
		srv_hover_position = hover_position
		srv_wake_up()
		emit_signal("client_set_hover_position", self)

# Called by the server to store the server's physics state locally.
# state: The server's physics state for this piece.
puppet func set_latest_server_physics_state(state: Dictionary) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_last_server_state = state
	sleeping = false

# Set the color of the piece's outline.
# NOTE: This requires setup_outline_material() to be called first.
# color: The color of the outline.
func set_outline_color(color: Color) -> void:
	if _outline_material:
		_outline_material.set_shader_param("Color", color)
	else:
		push_error("Outline material has not been created!")

# Called by the server to set the translation of the piece.
# new_translation: The new translation.
remotesync func set_translation(new_translation: Vector3) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	translation = new_translation
	sleeping = false

# Add the outline material to all mesh instances in this piece.
func setup_outline_material():
	var outline_shader = preload("res://Shaders/OutlineShader.tres")
	
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = outline_shader
	_outline_material.set_shader_param("Color", Color.transparent)
	
	for mesh_instance in get_mesh_instances():
		if mesh_instance is MeshInstance:
			for surface in range(mesh_instance.get_surface_material_count()):
				var material = mesh_instance.get_surface_material(surface)
				if material:
					material.next_pass = _outline_material

# Get the hover offset of the piece.
# Returns: The hover offset of the piece.
func srv_get_hover_offset() -> Vector3:
	return _srv_hover_offset

# Get the ID of the player that is hovering the piece.
# Returns: The ID of the player hovering the piece. 0 if the piece is not being
# hovered.
func srv_get_hover_player() -> int:
	return _srv_hover_player

# Is the piece being hovered?
# Returns: If the piece is being hovered.
func srv_is_hovering() -> bool:
	return _srv_hover_player > 0

# Lock the piece server-side.
func srv_lock() -> void:
	mode = MODE_STATIC
	rpc("lock_client", transform)

# Start hovering the piece server-side.
# Returns: If the piece started hovering.
# player_id: The ID of the player hovering the piece.
# init_pos: The initial hover position.
# offset_pos: The hover position offset.
func srv_start_hovering(player_id: int, init_pos: Vector3, offset_pos: Vector3) -> bool:
	if not (srv_is_hovering() or is_locked()):
		srv_hover_basis = transform.basis
		srv_hover_position = init_pos
		
		_srv_hover_offset = offset_pos
		_srv_hover_player = player_id
		
		srv_wake_up()
		
		collision_layer = 2
		custom_integrator = true
		
		return true
	
	# If the piece is hovering, and it's the client that is hovering the piece,
	# send them the all clear, since they are already in control.
	if not is_locked():
		if player_id == _srv_hover_player:
			srv_hover_position = init_pos
			_srv_hover_offset = offset_pos
			return true
	
	return false

# Wake the piece up if it is sleeping.
func srv_wake_up() -> void:
	sleeping = false
	_srv_hover_time_since_update = 0.0

# If you are hovering the piece, ask the server to stop hovering it. The server
# can also stop hovering the piece regardless of who is currently hovering it.
master func stop_hovering() -> void:
	var id = get_tree().get_rpc_sender_id()
	if id == _srv_hover_player or id == 1:
		_srv_hover_player = 0
		collision_layer = 1
		custom_integrator = false
		sleeping = false

# Called by the server to unlock the piece.
remotesync func unlock() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	mode = MODE_RIGID

func _ready():
	if not get_tree().is_network_server():
		# The clients are at the mercy of the server.
		custom_integrator = true
	
	connect("body_entered", self, "_on_body_entered")
	connect("tree_entered", self, "_on_tree_entered")
	connect("tree_exiting", self, "_on_tree_exiting")

func _process(delta):
	_last_slow_table_collision += delta
	
	if get_tree().is_network_server():
		if srv_is_hovering() and not sleeping:
			_srv_hover_time_since_update += delta
			
			# If the hovering piece has not had a transform update in a certain
			# amount of time, put it to sleep so it doesn't send unnessesary
			# updates to all the clients.
			if _srv_hover_time_since_update > HOVER_INACTIVE_DURATION:
				sleeping = true

func _physics_process(_delta):
	_last_velocity = _new_velocity
	_new_velocity  = linear_velocity
	
	if get_tree().is_network_server():
		if not (sleeping or is_locked()):
			rpc_unreliable("set_latest_server_physics_state", _last_server_state)

func _integrate_forces(state):
	if get_tree().is_network_server():
		
		# Only the server can apply what happens when a piece is hovered.
		if srv_is_hovering():
			_srv_apply_hover_to_state(state)
		
		# If the piece has fallen off the table and decended into hell, recover
		# it so the devil doesn't tickle it to death.
		elif srv_retrieve_from_hell and state.transform.origin.y < HELL_HEIGHT:
			state.transform = Transform.IDENTITY
			state.transform.origin.y += SPAWN_HEIGHT
			
			state.angular_velocity = Vector3.ZERO
			state.linear_velocity = Vector3.ZERO
		
		# The server piece needs to keep track of its physics properties in
		# order to send it to the client.
		_last_server_state = {
			"angular_velocity": state.angular_velocity,
			"linear_velocity": state.linear_velocity,
			"transform": state.transform
		}
	
	else:
		# The client, if it has received a new physics state from the
		# server, needs to update it here.
		
		if _last_server_state.has("angular_velocity"):
			state.angular_velocity = _last_server_state["angular_velocity"]
		if _last_server_state.has("linear_velocity"):
			state.linear_velocity = _last_server_state["linear_velocity"]
		if _last_server_state.has("transform"):
			
			# For the transform, we want to lerp into the new state to make it
			# as smooth as possible, even if the server fails to send the state.
			var server_transform = _last_server_state["transform"]
			var origin = transform.origin.linear_interpolate(server_transform.origin, TRANSFORM_LERP_ALPHA)
			var client_quat = Quat(transform.basis)
			var server_quat = Quat(server_transform.basis)
			var lerp_quat = client_quat.slerp(server_quat, TRANSFORM_LERP_ALPHA).normalized()
			
			var new_transform = Transform(lerp_quat)
			new_transform.origin = origin
			state.transform = new_transform

func _on_body_entered(body):
	# If we collided with another object...
	if body is RigidBody:
		# ... play a sound effect depending on our angular velocity.
		if angular_velocity.length_squared() > 100.0:
			if table_collide_fast_sounds != null:
				play_effect(table_collide_fast_sounds.random_stream())
		
		# Workaround for slow collisions being set off multiple times if the
		# piece "floats" down to the table.
		elif _last_slow_table_collision > 1.0:
			_last_slow_table_collision = 0.0
			if table_collide_slow_sounds != null:
				play_effect(table_collide_slow_sounds.random_stream())

func _on_tree_entered() -> void:
	# If the piece just entered the tree, then reset the last server state,
	# because it's very likely that it's wrong now.
	_last_server_state = {}

func _on_tree_exiting() -> void:
	emit_signal("piece_exiting_tree", self)

# Apply forces to the piece to get it to the desired hover position and
# orientation.
# state: The direct physics state of the piece.
func _srv_apply_hover_to_state(state: PhysicsDirectBodyState) -> void:
	# Force the piece to the given location.
	var pos = state.transform.origin
	var linear_dir = srv_hover_position + _srv_hover_offset - pos
	state.linear_velocity = LINEAR_FORCE_SCALAR * linear_dir
	
	# Force the piece to the given basis.
	var current_basis = state.transform.basis.orthonormalized()
	var target_basis = srv_hover_basis.orthonormalized()
	var rotation_basis = target_basis * current_basis.inverse()
	var rotation_euler = rotation_basis.get_euler()
	state.angular_velocity = ANGULAR_FORCE_SCALAR * rotation_euler
