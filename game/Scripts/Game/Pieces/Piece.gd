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

extends RigidBody

class_name Piece

signal client_set_hover_position(piece)
signal scale_changed()

const HARMONIC_DAMPENING = 0.5
const HELL_HEIGHT = -50.0
const HOVER_INACTIVE_DURATION = 5.0
const LINEAR_FORCE_SCALAR = 50.0
const ROTATION_LOCK_AT = 0.001
const ROTATION_SLERP_ALPHA = 0.5
const SHAKING_THRESHOLD = 1000.0
const SHAKE_WAIT_DURATION = 500
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

# Exported so cached pieces save the piece entry, it is not expected to fill
# this manually.
export(Dictionary) var piece_entry: Dictionary = {}

# When setting these vectors, make sure you call set_angular_lock(false),
# otherwise the piece won't rotate towards the orientation!
var hover_offset = Vector3.ZERO
var hover_player = 0 # 0 = Not hovering, > 0 is the player ID.
var hover_position = Vector3.ZERO
var hover_quat = Quat.IDENTITY
var hover_start_time: int = 0

var srv_retrieve_from_hell: bool = true

# The physics state sent by the server is sent as a Basis and a Quat: The basis
# contains the angular velocity, linear velocity, and the origin - the Quat
# contains the rotation. This format reduces the size of the packets that are
# sent to the clients.
var _last_server_state_vecs: Basis
var _last_server_state_quat: Quat
var _last_server_state_invalid: bool = true
var _last_server_state_time: int = 0
var _last_slow_table_collision = 0.0

var _last_velocity = Vector3()
var _new_velocity = Vector3()

# For optimisation purposes, we rarely check if a Basis is orthonormalized
# before converting it into a Quat. Since the game uses frame interpolation,
# the "main thread" transform is not 100% reliable.
var _last_physics_state_transform: Transform = Transform.IDENTITY
var _last_physics_state_transform_set = false

var _outline_material: ShaderMaterial = null

var _expose_albedo_color = true

var _original_shape_scales = []
var _original_shape_scales_saved = false

# Apply a texture to the piece.
# texture: The texture to apply.
# surface: The index of the surface to apply the texture to.
func apply_texture(texture: Texture, surface: int = 0) -> void:
	for mesh_instance in get_mesh_instances():
		var material = SpatialMaterial.new()
		material.albedo_texture = texture
		
		mesh_instance.set_surface_material(surface, material)

# Get the current albedo colour in the piece's material.
# Returns: The current albedo colour.
func get_albedo_color() -> Color:
	if not _expose_albedo_color:
		push_error("Albedo color is not exposed!")
		return Color.white
	
	var current_color = Color.white
	var original_color = Color.white
	for mesh_instance in get_mesh_instances():
		if mesh_instance.get_surface_material_count() > 0:
			var material = mesh_instance.get_surface_material(0)
			
			# Skip if the first surface does not have a material.
			if material == null:
				push_warning("Mesh instance %s has no material for surface 0, ignoring." % mesh_instance.name)
				continue
			
			current_color = material.albedo_color
			original_color = _get_original_albedo(material)
			break
	
	# When we set the albedo colour, it is always relative to the original
	# colour - so we need this to be relative to the original colour as well.
	var r = 1.0 if original_color.r == 0.0 else current_color.r / original_color.r
	var g = 1.0 if original_color.g == 0.0 else current_color.g / original_color.g
	var b = 1.0 if original_color.b == 0.0 else current_color.b / original_color.b
	
	r = min(max(0.0, r), 1.0)
	g = min(max(0.0, g), 1.0)
	b = min(max(0.0, b), 1.0)
	
	return Color(r, g, b)

# Get the piece's collision shapes.
# Returns: An array of the piece's collision shapes.
func get_collision_shapes() -> Array:
	var out = []
	for child in get_children():
		if child is CollisionShape:
			out.append(child)
	return out

# Get the current scale of the piece relative to it's original size.
# Returns: A Vector3 representing the scale in all three axes.
func get_current_scale() -> Vector3:
	if _original_shape_scales_saved:
		var collision_shapes = get_collision_shapes()
		if not collision_shapes.empty():
			# The scale should be consistent across all of the collision shapes,
			# so just compare it against the first one.
			var shape: CollisionShape = collision_shapes[0]
			# We want the local scale, ignoring any rotation from the parent.
			var true_scale = shape.transform.basis.get_scale()
			var x = true_scale.x / _original_shape_scales[0].x
			var y = true_scale.y / _original_shape_scales[0].y
			var z = true_scale.z / _original_shape_scales[0].z
			return Vector3(x, y, z)
		else:
			return Vector3.ZERO
	else:
		return Vector3.ONE

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
	if not is_hovering(): return false
	if hovering_duration() < SHAKE_WAIT_DURATION: return false
	if _last_velocity.length_squared() <= 1.0: return false
	if _new_velocity.dot(_last_velocity) >= 0: return false
	
	return (_new_velocity - _last_velocity).length_squared() > SHAKING_THRESHOLD

# Duration the piece is being hovered
# Returns: Time the piece is being hovered for in msec
func hovering_duration() -> int:
	if hover_player == 0: return 0
	return OS.get_ticks_msec() - hover_start_time

# Is the piece being hovered?
# Returns: If the piece is being hovered.
func is_hovering() -> bool:
	return hover_player > 0

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

# If you are not hovering this piece, ask the server to flip the piece vertically.
master func request_flip_vertically_on_ground() -> void:
	var current_quat = transform.basis.get_rotation_quat()
	var modify_quat = Quat(transform.basis.z, PI)
	request_set_rotation_quat(modify_quat * current_quat)

# If you are hovering this piece, ask the server to flip the piece vertically.
master func request_flip_vertically() -> void:
	var back_basis = hover_quat * Vector3.BACK
	var modify_quat = Quat(back_basis, PI)
	request_set_hover_rotation(modify_quat * hover_quat)

# Request the server to apply an impulse to the piece.
# position: The position to apply the impulse, relative to the piece's origin.
# impulse: The impulse to apply, using the global rotation.
master func request_impulse(position: Vector3, impulse: Vector3) -> void:
	if not (is_hovering() or is_locked()):
		apply_impulse(position, impulse)

# Request the server to lock the piece.
master func request_lock() -> void:
	srv_lock()

# If you are not hovering the piece, ask the server to reset the 
# orientation of the piece.
master func request_reset_orientation_on_ground() -> void:
	request_set_rotation_quat(Quat.IDENTITY)

# If you are hovering the piece, ask the server to reset the orientation of the
# piece.
master func request_reset_orientation() -> void:
	request_set_hover_rotation(Quat.IDENTITY)

# If you are hovering the piece, request the server to rotate it
# around the y-axis by the given rotation.
# rot: The amount to rotate it by in radians.
master func request_rotate_y(rot: float) -> void:
	if is_zero_approx(rot):
		return

	var current_euler = hover_quat.get_euler()
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
	
	request_set_hover_rotation(Quat(target_y_euler))

# If you are not hovering the piece, request the server to
# rotate it around the y-axis by the given rotation.
# rot: The amount to rotate it by in radians.
master func request_rotate_y_on_ground(rot: float) -> void:
	var current_quat = transform.basis.get_rotation_quat()
	var modify_quat = Quat(transform.basis.y, rot)
	request_set_rotation_quat(modify_quat * current_quat)

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

# Request the server to set the hover rotation if you are the client hovering
# the piece.
# new_hover_quat: The quaternion the hovering piece will go towards.
master func request_set_hover_rotation(new_hover_quat: Quat) -> void:
	if get_tree().get_rpc_sender_id() == hover_player:
		srv_set_hover_rotation(new_hover_quat)

# Request the server to set the hover position if you are the client hovering
# the piece.
# new_hover_position: The position the hovering piece will go towards.
master func request_set_hover_position(new_hover_position: Vector3) -> void:
	if get_tree().get_rpc_sender_id() == hover_player:
		srv_set_hover_position(new_hover_position)
		emit_signal("client_set_hover_position", self)

# Request the server to set the rotation of this piece.
# new_rotation: The piece's new rotation.
master func request_set_rotation_quat(new_rotation: Quat) -> void:
	if not is_hovering():
		rpc("set_rotation_quat", new_rotation)

# Request the server to set the transform of this piece.
# new_transform: The piece's new transform.
master func request_set_transform(new_transform: Transform) -> void:
	if not is_hovering():
		rpc("set_transform", new_transform)

# Request the server to set the translation of this piece.
# new_translation: The piece's new translation.
master func request_set_translation(new_translation: Vector3) -> void:
	if not is_hovering():
		rpc("set_translation", new_translation)

# Request the server to start hovering the piece.
master func request_start_hovering(init_pos: Vector3, offset_pos: Vector3) -> void:
	srv_start_hovering(get_tree().get_rpc_sender_id(), init_pos, offset_pos)

# If you are hovering the piece, request the server to stop hovering it.
master func request_stop_hovering() -> void:
	var player_id = get_tree().get_rpc_sender_id()
	if player_id == hover_player or player_id == 1:
		rpc("stop_hovering")

# Request the server to unlock the piece.
master func request_unlock() -> void:
	rpc("unlock")

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
			
			# There's a chance the surface does not have a material - if this is
			# the case, then skip this surface.
			if material == null:
				push_warning("Mesh instance %s has no material for surface %d, ignoring." % [
						mesh_instance.name, surface])
				continue
			
			# Some materials will already have an albedo colour set, so keep
			# this colour saved so that we don't overwrite and lose it.
			var original_color = _get_original_albedo(material)
			material.albedo_color = original_color * color

# Set the current scale of the piece.
# new_scale: The scale of the piece in all three axes.
func set_current_scale(new_scale: Vector3) -> void:
	var collision_shapes = get_collision_shapes()
	if not _original_shape_scales_saved:
		var original_scales = []
		for collision_shape in collision_shapes:
			var this_scale = collision_shape.scale
			# Avoid divide-by-zero errors.
			if is_zero_approx(this_scale.x):
				this_scale.x = 1.0
			if is_zero_approx(this_scale.y):
				this_scale.y = 1.0
			if is_zero_approx(this_scale.z):
				this_scale.z = 1.0
			original_scales.append(collision_shape.scale)
		_original_shape_scales = original_scales
		_original_shape_scales_saved = true
	
	var modified_scale = new_scale
	var current_scale = get_current_scale()
	if not is_zero_approx(current_scale.x):
		modified_scale.x /= current_scale.x
	if not is_zero_approx(current_scale.y):
		modified_scale.y /= current_scale.y
	if not is_zero_approx(current_scale.z):
		modified_scale.z /= current_scale.z
	
	for i in range(collision_shapes.size()):
		# Like in get_current_scale, we want to modify the scale locally.
		var old_basis = collision_shapes[i].transform.basis
		if not (old_basis.get_scale().is_equal_approx(new_scale)):
			collision_shapes[i].transform.basis = old_basis.scaled(modified_scale)
	
	emit_signal("scale_changed")

# Set the hover rotation of the piece.
# new_hover_quat: The quaternion the hovering piece will go towards.
remotesync func set_hover_rotation(new_hover_quat: Quat) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var quat_length_sq = new_hover_quat.length_squared()
	if is_zero_approx(quat_length_sq):
		return
	elif not is_equal_approx(quat_length_sq, 1.0): # is_normalized()
		new_hover_quat = new_hover_quat.normalized()
	
	hover_quat = new_hover_quat
	sleeping = false

# Set the hover position of the piece.
# new_hover_position: The position the hovering piece will go towards.
remotesync func set_hover_position(new_hover_position: Vector3) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	hover_position = new_hover_position
	sleeping = false

# Called by the server to store the server's physics state locally.
# NOTE: "ss" stands for "set state", the reason for the short name is to reduce
# the size of the packet that is sent to the clients.
# vecs: The angular velocity, the linear velocity, and the transform origin.
# quat: The rotation.
puppet func ss(vecs: Basis, quat: Quat) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var quat_length_sq = quat.length_squared()
	if is_zero_approx(quat_length_sq):
		return
	elif not is_equal_approx(quat_length_sq, 1.0): # is_normalized()
		quat = quat.normalized()
	
	_last_server_state_vecs = vecs
	_last_server_state_quat = quat
	_last_server_state_invalid = false
	_last_server_state_time = OS.get_ticks_msec()
	sleeping = false

# Set the color of the piece's outline.
# NOTE: This requires setup_outline_material() to be called first.
# color: The color of the outline.
func set_outline_color(color: Color) -> void:
	if _outline_material:
		_outline_material.set_shader_param("OutlineColor", color)
	else:
		push_error("Outline material has not been created!")

# Called by the server to set the rotation of the piece.
# new_rotation: The piece's new rotation.
remotesync func set_rotation_quat(new_rotation: Quat) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var quat_length_sq = new_rotation.length_squared()
	if is_zero_approx(quat_length_sq):
		return
	elif not is_equal_approx(quat_length_sq, 1.0): # is_normalized()
		new_rotation = new_rotation.normalized()
	
	transform.basis = Basis(new_rotation)
	sleeping = false

# Called by the server to set the transform of the piece.
# new_transform: The piece's new transform.
remotesync func set_transform(new_transform: Transform) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	set_translation(new_transform.origin)
	set_rotation_quat(new_transform.basis.get_rotation_quat())
	set_current_scale(new_transform.basis.get_scale())

# Called by the server to set the translation of the piece.
# new_translation: The new translation.
remotesync func set_translation(new_translation: Vector3) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	translation = new_translation
	sleeping = false

# Add the outline material to all mesh instances in this piece.
func setup_outline_material():
	var outline_shader = preload("res://Shaders/OutlineShader.shader")
	
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = outline_shader
	_outline_material.set_shader_param("OutlineColor", Color.transparent)
	
	for mesh_instance in get_mesh_instances():
		if mesh_instance is MeshInstance:
			for surface in range(mesh_instance.get_surface_material_count()):
				var material = mesh_instance.get_surface_material(surface)
				if material:
					material.next_pass = _outline_material

# Called by the server to start hovering the piece.
# player_id: The ID of the player hovering the piece.
# init_pos: The initial hover position.
# offset_pos: The hover position offset.
remotesync func start_hovering(player_id: int, init_pos: Vector3, offset_pos: Vector3) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	# There is a chance this function could be called immediately after the
	# piece was added to the scene, before a physics pass could be completed.
	# If that is the case, we need to manually orthonormalize the current
	# transform.
	if not _last_physics_state_transform_set:
		_last_physics_state_transform = transform.orthonormalized()
	
	hover_quat = Quat(_last_physics_state_transform.basis)
	hover_position = init_pos
	
	hover_offset = offset_pos
	hover_player = player_id
	
	hover_start_time = OS.get_ticks_msec()
	
	sleeping = false
	
	collision_layer = 2
	custom_integrator = true

# Called by the server to stop hovering the piece.
remotesync func stop_hovering() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	hover_player = 0
	collision_layer = 1
	sleeping = false
	
	# If the piece is still in the process to reach its hover position, the
	# velocity in Y would let it fly away. Tossing pieces are not using the Y
	# axis either, so we reset it to 0
	linear_velocity.y = 0
	
	# Only the server gets to turn off the custom integrator, since it is the
	# authority for the physics simulation.
	if get_tree().is_network_server():
		custom_integrator = false
	
	# The last server state will be out of date, so reset it here.
	_last_server_state_invalid = true

# Lock the piece server-side.
func srv_lock() -> void:
	mode = MODE_STATIC
	rpc("lock_client", transform)

# As the server, set the hover rotation of the piece.
# new_hover_quat: The quaternion the hovering piece will go towards.
func srv_set_hover_rotation(new_hover_quat: Quat) -> void:
	rpc_unreliable("set_hover_rotation", new_hover_quat)

# As the server, set the hover position of the piece.
# new_hover_position: The position the hovering piece will go towards.
func srv_set_hover_position(new_hover_position: Vector3) -> void:
	rpc_unreliable("set_hover_position", new_hover_position)

# As the server, start hovering the piece.
# Returns: If the piece started hovering.
# player_id: The ID of the player hovering the piece.
# init_pos: The initial hover position.
# offset_pos: The hover position offset.
func srv_start_hovering(player_id: int, init_pos: Vector3, offset_pos: Vector3) -> bool:
	if (not is_hovering() or hover_player == player_id) and (not is_locked()):
		rpc("start_hovering", player_id, init_pos, offset_pos)
		return true
	
	return false

# Called by the server to unlock the piece.
remotesync func unlock() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	mode = MODE_RIGID
	sleeping = false

func _ready():
	if not get_tree().is_network_server():
		# The clients are at the mercy of the server.
		custom_integrator = true
	
	connect("body_entered", self, "_on_body_entered")
	connect("tree_entered", self, "_on_tree_entered")

func _process(delta):
	_last_slow_table_collision += delta

func _physics_process(_delta):
	_last_velocity = _new_velocity
	_new_velocity  = linear_velocity
	
	if get_tree().is_network_server():
		if Engine.get_physics_frames() % Global.srv_num_physics_frames_per_state_update == 0:
			if not _last_server_state_invalid:
				if not (sleeping or is_hovering() or is_locked()):
					for id in Lobby.get_player_list():
						if id != 1 and (not id in Global.srv_state_update_blacklist):
							rpc_unreliable_id(id, "ss", _last_server_state_vecs,
									_last_server_state_quat)

# Apply forces to the piece to get it to the desired hover position and
# orientation.
# state: The direct physics state of the piece.
func _apply_hover_to_state(state: PhysicsDirectBodyState) -> void:
	# Force the piece to the given location.
	var pos = state.transform.origin
	var linear_dir = hover_position + hover_offset - pos
	state.linear_velocity = LINEAR_FORCE_SCALAR * linear_dir
	
	# Force the piece to the given quaternion.
	var current_quat = Quat(state.transform.basis)
	var new_quat = hover_quat
	if not current_quat.is_equal_approx(hover_quat):
		new_quat = current_quat.slerp(hover_quat, ROTATION_SLERP_ALPHA).normalized()
	state.transform.basis = Basis(new_quat)
	
	state.angular_velocity = Vector3.ZERO

func _integrate_forces(state):
	# Overwrite the physics forces if the piece is hovering, so we can control
	# where the piece goes.
	if is_hovering():
		_apply_hover_to_state(state)
	else:
		if get_tree().is_network_server():
			# If the piece has fallen off the table and decended into hell, recover
			# it so the devil doesn't tickle it to death.
			if srv_retrieve_from_hell and state.transform.origin.y < HELL_HEIGHT:
				state.transform = Transform.IDENTITY
				state.transform.origin.y = get_size().y / 2.0
				
				state.angular_velocity = Vector3.ZERO
				state.linear_velocity = Vector3.ZERO
			
			# The server piece needs to keep track of its physics properties in
			# order to send it to the client.
			_last_server_state_vecs = Basis(state.angular_velocity,
				state.linear_velocity, state.transform.origin)
			_last_server_state_quat = Quat(state.transform.basis)
			_last_server_state_invalid = false
			_last_server_state_time = OS.get_ticks_msec()
		
		else:
			# The client, if it has received a new physics state from the
			# server, needs to update it here.
			if not _last_server_state_invalid:
				state.angular_velocity = _last_server_state_vecs.x
				state.linear_velocity = _last_server_state_vecs.y
				
				# For the transform, we want to lerp into the new state to make
				# it as smooth as possible, even if the server fails to send
				# the state.
				var server_origin = _last_server_state_vecs.z
				var lerp_origin = state.transform.origin.linear_interpolate(
						server_origin, TRANSFORM_LERP_ALPHA)
				
				var client_quat = Quat(state.transform.basis)
				var lerp_quat = client_quat.slerp(_last_server_state_quat,
						TRANSFORM_LERP_ALPHA).normalized()
				
				var new_transform = Transform(lerp_quat)
				new_transform.origin = lerp_origin
				state.transform = new_transform
				
				_last_server_state_invalid = true
	
	_last_physics_state_transform = state.transform
	_last_physics_state_transform_set = true

# Get the starting albedo colour of a given material.
# Returns: The starting albedo of the material.
# material: The material to get the albedo from.
func _get_original_albedo(material: SpatialMaterial) -> Color:
	var original_color = material.albedo_color
	
	if material.has_meta("original_color"):
		original_color = material.get_meta("original_color")
	else:
		material.set_meta("original_color", original_color)
	
	return original_color

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
	_last_server_state_invalid = true
