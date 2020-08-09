# open-tabletop
# Copyright (c) 2020 drwhut
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

signal cards_in_hand_requested(cards)
signal collect_pieces_requested(pieces)
signal hover_piece_requested(piece)
signal pop_stack_requested(stack)
signal stack_collect_all_requested(stack, collect_stacks)
signal started_hovering_card(card)
signal stopped_hovering_card(card)

onready var _box_selection_rect = $BoxSelectionRect
onready var _camera = $Camera
onready var _piece_context_menu = $PieceContextMenu
onready var _piece_context_menu_container = $PieceContextMenu/VBoxContainer

const GRABBING_SLOW_TIME = 0.25
const HOVER_Y_LEVEL = 5.0
const MOVEMENT_ACCEL_SCALAR = 0.125
const MOVEMENT_DECEL_SCALAR = 0.25
const RAY_LENGTH = 1000
const ROTATION_Y_MAX = -0.2
const ROTATION_Y_MIN = -1.3
const ZOOM_ACCEL_SCALAR = 3.0
const ZOOM_DISTANCE_MIN = 2.0
const ZOOM_DISTANCE_MAX = 200.0

export(float) var max_speed: float = 10.0
export(float) var rotation_sensitivity_x: float = -0.01
export(float) var rotation_sensitivity_y: float = -0.01
export(float) var zoom_sensitivity: float = 1.0

var _box_select_init_pos = Vector2()
var _grabbing_time = 0.0
var _is_box_selecting = false
var _is_grabbing_selected = false
var _is_hovering_selected = false
var _movement_accel = 0.0
var _movement_dir = Vector3()
var _movement_vel = Vector3()
var _perform_box_select = false
var _piece_mouse_is_over: Piece = null
var _right_click_pos = Vector2()
var _rotation = Vector2()
var _selected_pieces = []
var _target_zoom = 0.0

# Append an array of pieces to the list of selected pieces.
# pieces: The array of pieces to now be selected.
func append_selected_pieces(pieces: Array) -> void:
	for piece in pieces:
		if piece is Piece and (not piece in _selected_pieces):
			_selected_pieces.append(piece)
			piece.set_appear_selected(true)

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	var rotation_x_scale = -0.1
	if config.get_value("controls", "mouse_horizontal_invert"):
		rotation_x_scale *= -1
	rotation_sensitivity_x = rotation_x_scale * config.get_value("controls", "mouse_horizontal_sensitivity")
	
	var rotation_y_scale = -0.1
	if config.get_value("controls", "mouse_vertical_invert"):
		rotation_y_scale *= -1
	rotation_sensitivity_y = rotation_y_scale * config.get_value("controls", "mouse_vertical_sensitivity")
	
	var zoom_offset = 1.0
	var zoom_scale = 15.0
	if config.get_value("controls", "zoom_invert"):
		zoom_scale *= -1
		zoom_offset *= -1
	zoom_sensitivity = zoom_offset + zoom_scale * config.get_value("controls", "zoom_sensitivity")
	
	var speed_offset = 10.0
	var speed_scale = 190.0
	max_speed = speed_offset + speed_scale * config.get_value("controls", "camera_movement_speed")

# Clear the list of selected pieces.
func clear_selected_pieces() -> void:
	for piece in _selected_pieces:
		piece.set_appear_selected(false)
	
	_selected_pieces.clear()

# Erase a piece from the list of selected pieces.
# piece: The piece to erase from the list.
func erase_selected_pieces(piece: Piece) -> void:
	if _selected_pieces.has(piece):
		_selected_pieces.erase(piece)
		piece.set_appear_selected(false)

# Get the current position that pieces should hover at, given the camera and
# mouse positions.
# Returns: The position that hovering pieces should hover at.
func get_hover_position() -> Vector3:
	return _calculate_hover_position(get_viewport().get_mouse_position())

# Get the list of selected pieces.
# Returns: The list of selected pieces.
func get_selected_pieces() -> Array:
	return _selected_pieces

# Set if the camera is hovering it's selected pieces.
# is_hovering: If the camera is hovering it's selected pieces.
func set_is_hovering(is_hovering: bool) -> void:
	_is_hovering_selected = is_hovering
	
	var cursor = Input.CURSOR_ARROW
	if is_hovering:
		cursor = Input.CURSOR_DRAG
		
		# If we have started hovering, we have stopped grabbing.
		_is_grabbing_selected = false
	
	Input.set_default_cursor_shape(cursor)

# Set the list of selected pieces.
# pieces: The new list of selected pieces.
func set_selected_pieces(pieces: Array) -> void:
	clear_selected_pieces()
	append_selected_pieces(pieces)

func _ready():
	
	# Get the current rotation so we can get our _rotation accumulator set up
	# no matter how the camera is initially positioned.
	_rotation = Vector2(rotation.y, rotation.x)
	
	# Get the current zoom so the camera doesn't try to go to another zoom
	# level.
	_target_zoom = _camera.translation.z

func _process(delta):
	if _is_grabbing_selected:
		_grabbing_time += delta
		
		# Have we been grabbing this piece for a long time?
		if _grabbing_time > GRABBING_SLOW_TIME:
			_start_hovering_grabbed_piece(false)

func _physics_process(delta):
	_process_input(delta)
	_process_movement(delta)
	
	# Perform a raycast out into the world from the camera.
	var mouse_pos = get_viewport().get_mouse_position()
	var from = _camera.project_ray_origin(mouse_pos)
	var to = from + _camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	
	var space_state = get_world().direct_space_state
	var result = space_state.intersect_ray(from, to)
	
	_piece_mouse_is_over = null
	
	# Was the thing that collided a game piece?
	if result.has("collider"):
		if result.collider is Piece:
			_piece_mouse_is_over = result.collider
	
	# Do we need to perform a box select?
	if _perform_box_select:
		var query_params = PhysicsShapeQueryParameters.new()
		
		var box_rect = Rect2(_box_selection_rect.rect_position, _box_selection_rect.rect_size)
		
		# Create a frustum from the box position and size.
		var shape = ConvexPolygonShape.new()
		var points = []
		
		var middle = box_rect.position + box_rect.size / 2
		var box_from = _camera.project_ray_origin(middle)
		points.append(box_from)
		
		for dx in [0, 1]:
			for dy in [0, 1]:
				var size = Vector2(box_rect.size.x * dx, box_rect.size.y * dy)
				var box_pos = box_rect.position + size
				var box_to = box_from + _camera.project_ray_normal(box_pos) * RAY_LENGTH
				points.append(box_to)
		
		shape.points = points
		query_params.set_shape(shape)
		
		var results = space_state.intersect_shape(query_params, 1024)
		
		for box_result in results:
			if box_result.has("collider"):
				if box_result.collider is Piece:
					append_selected_pieces([box_result.collider])
		
		_perform_box_select = false

func _process_input(delta):
	
	# Calculating the direction the user wants to move parallel to the table.
	var movement_input = Vector2()
	
	if Input.is_action_pressed("game_left"):
		movement_input.x -= 1
	if Input.is_action_pressed("game_right"):
		movement_input.x += 1
	if Input.is_action_pressed("game_up"):
		movement_input.y += 1
	if Input.is_action_pressed("game_down"):
		movement_input.y -= 1
	
	movement_input = movement_input.normalized()
	
	_movement_dir = Vector3()
	
	# Moving side-to-side is fine, since the x basis should always be parallel
	# to the table...
	_movement_dir += transform.basis.x * movement_input.x
	
	# ... but we want to move forward along the horizontal plane parallel to
	# the table, and since we can move the camera to be looking at the table,
	# we need to adjust the z basis here.
	var z_basis = transform.basis.z
	z_basis.y = 0
	z_basis = z_basis.normalized()
	_movement_dir += -z_basis * movement_input.y
	
	var is_accelerating = _movement_dir.dot(_movement_vel) > 0
	
	_movement_accel = max_speed
	if is_accelerating:
		_movement_accel *= MOVEMENT_ACCEL_SCALAR
	else:
		_movement_accel *= MOVEMENT_DECEL_SCALAR

func _process_movement(delta):
	var target_vel = _movement_dir * max_speed
	_movement_vel = _movement_vel.linear_interpolate(target_vel, _movement_accel * delta)
	
	# A global translation, as we want to move on the plane parallel to the
	# table, regardless of the direction we are facing.
	var old_translation = translation
	translation += _movement_vel * delta
	
	# If we ended up moving...
	if translation != old_translation:
		_start_moving()
	
	# Go towards the target zoom level.
	var target_offset = Vector3(0, 0, _target_zoom)
	var zoom_accel = zoom_sensitivity * ZOOM_ACCEL_SCALAR
	_camera.translation = _camera.translation.linear_interpolate(target_offset, zoom_accel * delta)

func _unhandled_input(event):
	if _is_hovering_selected:
		if event.is_action_pressed("game_flip"):
			for piece in _selected_pieces:
				piece.rpc_id(1, "flip_vertically")
		elif event.is_action_pressed("game_reset"):
			for piece in _selected_pieces:
				piece.rpc_id(1, "reset_orientation")
	
	if event is InputEventMouseButton:
		
		if event.button_index == BUTTON_LEFT:
			if event.is_pressed():
				if _piece_mouse_is_over:
					if event.control:
						append_selected_pieces([_piece_mouse_is_over])
					else:
						if not _selected_pieces.has(_piece_mouse_is_over):
							set_selected_pieces([_piece_mouse_is_over])
						_is_grabbing_selected = true
						_grabbing_time = 0.0
				else:
					if not event.control:
						clear_selected_pieces()
					
					# Start box selecting.
					_box_select_init_pos = event.position
					_is_box_selecting = true
					
					_box_selection_rect.rect_position = _box_select_init_pos
					_box_selection_rect.rect_size = Vector2()
					_box_selection_rect.visible = true
			else:
				_is_grabbing_selected = false
				
				if _is_hovering_selected:
					for piece in _selected_pieces:
						piece.rpc_id(1, "stop_hovering")
						
						if piece is Card:
							emit_signal("stopped_hovering_card", piece)
					
					set_is_hovering(false)
				
				# Stop box selecting.
				if _is_box_selecting:
					_box_selection_rect.visible = false
					_is_box_selecting = false
					_perform_box_select = true
		
		elif event.button_index == BUTTON_RIGHT:
			# Only bring up the context menu if the mouse didn't move between
			# the press and the release of the RMB.
			if event.is_pressed():
				if _piece_mouse_is_over:
					if not _selected_pieces.has(_piece_mouse_is_over):
						set_selected_pieces([_piece_mouse_is_over])
				else:
					clear_selected_pieces()
				_right_click_pos = event.position
			else:
				if event.position == _right_click_pos:
					_popup_piece_context_menu()
		
		elif event.is_pressed() and (event.button_index == BUTTON_WHEEL_UP or
			event.button_index == BUTTON_WHEEL_DOWN):
		
			# Zooming the camera in and away from the controller.
			var offset = 0
			
			if event.button_index == BUTTON_WHEEL_UP:
				offset = -zoom_sensitivity
			else:
				offset = zoom_sensitivity
			
			var new_zoom = _target_zoom + offset
			_target_zoom = max(min(new_zoom, ZOOM_DISTANCE_MAX), ZOOM_DISTANCE_MIN)
			
			get_tree().set_input_as_handled()
	
	elif event is InputEventMouseMotion:
		# Check if by moving the mouse, we either started hovering a piece, or
		# we have moved the hovered pieces position.
		if _start_moving():
			pass
		
		elif Input.is_action_pressed("game_rotate"):
		
			# Rotating the controller-camera system to get the camera to rotate
			# around a point, where the controller is.
			_rotation.x += event.relative.x * rotation_sensitivity_x
			_rotation.y += event.relative.y * rotation_sensitivity_y
			
			# Bound the rotation along the X axis.
			_rotation.y = max(_rotation.y, ROTATION_Y_MIN)
			_rotation.y = min(_rotation.y, ROTATION_Y_MAX)
			
			transform.basis = Basis()
			rotate_x(_rotation.y)
			rotate_y(_rotation.x)
			
			get_tree().set_input_as_handled()
		
		elif _is_box_selecting:
			
			var pos = _box_select_init_pos
			var size = event.position - _box_select_init_pos
			
			if size.x < 0:
				pos.x += size.x
				size.x = -size.x
			
			if size.y < 0:
				pos.y += size.y
				size.y = -size.y
			
			_box_selection_rect.rect_position = pos
			_box_selection_rect.rect_size = size
			
			get_tree().set_input_as_handled()

# Calculate the hover position of a piece, given a mouse position on the screen.
# Returns: The hover position of a piece, based on the given mouse position.
# mouse_position: The mouse position on the screen.
func _calculate_hover_position(mouse_position: Vector2) -> Vector3:
	# Get vectors representing a raycast from the camera.
	var from = _camera.project_ray_origin(mouse_position)
	var to = from + _camera.project_ray_normal(mouse_position) * RAY_LENGTH
	
	# Figure out at which point along this line the piece should hover at,
	# given we want it to hover at a particular Y-level.
	var lambda = (HOVER_Y_LEVEL - from.y) / (to.y - from.y)
	
	var x = from.x + lambda * (to.x - from.x)
	var z = from.z + lambda * (to.z - from.z)
	
	return Vector3(x, HOVER_Y_LEVEL, z)

# Get the inheritance of a piece, which is the array of classes represented as
# strings, that the piece is based on. The last element of the array should
# always represent the Piece class.
# Returns: The array of inheritance of the piece.
# piece: The piece to get the inheritance of.
func _get_piece_inheritance(piece: Piece) -> Array:
	var inheritance = []
	var script = piece.get_script()
	
	while script:
		inheritance.append(script.resource_path)
		script = script.get_base_script()
	
	return inheritance

# Hide the context menu.
func _hide_context_menu():
	_piece_context_menu.visible = false

# Check if an inheritance array has a particular class.
# Returns: If the queried class is in the inheritance array.
# inheritance: The inheritance array to check. Generated with
# _get_piece_inheritance.
# query: The class to query, as a string.
func _inheritance_has(inheritance: Array, query: String) -> bool:
	for piece_class in inheritance:
		if piece_class.ends_with("/" + query + ".gd"):
			return true
	return false

func _on_context_collect_all_pressed() -> void:
	if _selected_pieces.size() == 1:
		var piece = _selected_pieces[0]
		if piece is Stack:
			emit_signal("stack_collect_all_requested", piece, true)

func _on_context_collect_individuals_pressed() -> void:
	if _selected_pieces.size() == 1:
		var piece = _selected_pieces[0]
		if piece is Stack:
			emit_signal("stack_collect_all_requested", piece, false)

func _on_context_collect_selected_pressed() -> void:
	if _selected_pieces.size() > 1:
		emit_signal("collect_pieces_requested", _selected_pieces)

func _on_context_delete_pressed() -> void:
	# Go in reverse order, as we are removing the pieces as we go.
	for i in range(_selected_pieces.size() - 1, -1, -1):
		var piece = _selected_pieces[i]
		if piece is Piece:
			piece.rpc_id(1, "request_remove_self")

func _on_context_lock_pressed() -> void:
	for piece in _selected_pieces:
		if piece is Piece:
			piece.rpc_id(1, "request_lock")

func _on_context_orient_down_pressed() -> void:
	for piece in _selected_pieces:
		if piece is Stack:
			piece.rpc_id(1, "request_orient_pieces", false)

func _on_context_orient_up_pressed() -> void:
	for piece in _selected_pieces:
		if piece is Stack:
			piece.rpc_id(1, "request_orient_pieces", true)

func _on_context_put_in_hand_pressed() -> void:
	emit_signal("cards_in_hand_requested", _selected_pieces)

func _on_context_shuffle_pressed() -> void:
	for piece in _selected_pieces:
		if piece is Stack:
			piece.rpc_id(1, "request_shuffle")

func _on_context_sort_pressed() -> void:
	for piece in _selected_pieces:
		if piece is Stack:
			piece.rpc_id(1, "request_sort")

func _on_context_unlock_pressed() -> void:
	for piece in _selected_pieces:
		if piece is Piece:
			piece.rpc_id(1, "request_unlock")

# Popup the context menu.
func _popup_piece_context_menu() -> void:
	if _selected_pieces.size() == 0:
		return
	
	# Get the inheritance (e.g. Dice <- Piece) of the first piece in the array,
	# then reduce the inheritance down to the most common inheritance of all of
	# the pieces in the array.
	var inheritance = _get_piece_inheritance(_selected_pieces[0])
	
	for i in range(1, _selected_pieces.size()):
		if inheritance.size() <= 1:
			break
		
		var other_inheritance = _get_piece_inheritance(_selected_pieces[i])
		var cut_off = 0
		for piece_class in inheritance:
			if other_inheritance.has(piece_class):
				break
			cut_off += 1
		inheritance = inheritance.slice(cut_off, inheritance.size() - 1)
	
	# Populate the context menu, given the inheritance.
	for child in _piece_context_menu_container.get_children():
		_piece_context_menu_container.remove_child(child)
		child.queue_free()
	
	########
	# INFO #
	########
	
	if _inheritance_has(inheritance, "Stack"):
		
		# TODO: Figure out a way to update this label if the count changes.
		var count = 0
		for stack in _selected_pieces:
			count += stack.get_piece_count()
		
		var count_label = Label.new()
		count_label.text = "Count: %d" % count
		_piece_context_menu_container.add_child(count_label)
	
	###########
	# LEVEL 2 #
	###########
	
	if _inheritance_has(inheritance, "Card"):
		var put_in_hand_button = Button.new()
		put_in_hand_button.text = "Put in hand"
		put_in_hand_button.connect("pressed", self, "_on_context_put_in_hand_pressed")
		_piece_context_menu_container.add_child(put_in_hand_button)
	
	if _inheritance_has(inheritance, "Stack"):
		if _selected_pieces.size() == 1:
			var collect_individuals_button = Button.new()
			collect_individuals_button.text = "Collect individuals"
			collect_individuals_button.connect("pressed", self, "_on_context_collect_individuals_pressed")
			_piece_context_menu_container.add_child(collect_individuals_button)
			
			var collect_all_button = Button.new()
			collect_all_button.text = "Collect all"
			collect_all_button.connect("pressed", self, "_on_context_collect_all_pressed")
			_piece_context_menu_container.add_child(collect_all_button)
		
		var orient_up_button = Button.new()
		orient_up_button.text = "Orient all up"
		orient_up_button.connect("pressed", self, "_on_context_orient_up_pressed")
		_piece_context_menu_container.add_child(orient_up_button)
		
		var orient_down_button = Button.new()
		orient_down_button.text = "Orient all down"
		orient_down_button.connect("pressed", self, "_on_context_orient_down_pressed")
		_piece_context_menu_container.add_child(orient_down_button)
		
		var shuffle_button = Button.new()
		shuffle_button.text = "Shuffle"
		shuffle_button.connect("pressed", self, "_on_context_shuffle_pressed")
		_piece_context_menu_container.add_child(shuffle_button)
		
		var sort_button = Button.new()
		sort_button.text = "Sort"
		sort_button.connect("pressed", self, "_on_context_sort_pressed")
		_piece_context_menu_container.add_child(sort_button)
	
	###########
	# LEVEL 1 #
	###########
	
	if _inheritance_has(inheritance, "StackablePiece"):
		if _selected_pieces.size() > 1:
			var collect_selected_button = Button.new()
			collect_selected_button.text = "Collect selected"
			collect_selected_button.connect("pressed", self, "_on_context_collect_selected_pressed")
			_piece_context_menu_container.add_child(collect_selected_button)
	
	###########
	# LEVEL 0 #
	###########
	
	if _inheritance_has(inheritance, "Piece"):
		var num_locked = 0
		var num_unlocked = 0
		
		for piece in _selected_pieces:
			if piece.is_locked():
				num_locked += 1
			else:
				num_unlocked += 1
		
		if num_unlocked == _selected_pieces.size():
			var lock_button = Button.new()
			lock_button.text = "Lock"
			lock_button.connect("pressed", self, "_on_context_lock_pressed")
			_piece_context_menu_container.add_child(lock_button)
		
		if num_locked == _selected_pieces.size():
			var unlock_button = Button.new()
			unlock_button.text = "Unlock"
			unlock_button.connect("pressed", self, "_on_context_unlock_pressed")
			_piece_context_menu_container.add_child(unlock_button)
		
		var delete_button = Button.new()
		delete_button.text = "Delete"
		delete_button.connect("pressed", self, "_on_context_delete_pressed")
		_piece_context_menu_container.add_child(delete_button)
	
	# If a button in the context menu is clicked, stop showing the context menu.
	# TODO: Apply to sub-children?
	for child in _piece_context_menu_container.get_children():
		if child is Button:
			child.connect("pressed", self, "_hide_context_menu")
	
	# We've connected a signal elsewhere that will change the size of the popup
	# to match the container.
	_piece_context_menu.rect_position = get_viewport().get_mouse_position()
	_piece_context_menu.popup()

# Start hovering the grabbed pieces.
# fast: Did the user hover them quickly after grabbing them? If so, this may
# have differing behaviour, e.g. if the piece is a stack.
func _start_hovering_grabbed_piece(fast: bool) -> void:
	if _is_grabbing_selected:
		# NOTE: The server might not accept our request to hover a particular
		# piece, so we'll clear the list of selected pieces, and add the pieces
		# that are accepted back in to the list. For this reason, we'll need to
		# make a copy of the list.
		var selected = []
		for piece in _selected_pieces:
			selected.append(piece)
		
		clear_selected_pieces()
		
		for piece in selected:
			if selected.size() == 1 and piece is Stack and fast:
				emit_signal("pop_stack_requested", piece)
			else:
				emit_signal("hover_piece_requested", piece)
		
		_is_grabbing_selected = false

# Called when the camera starts moving either positionally or rotationally.
func _start_moving() -> bool:
	# If we were grabbing a piece while moving...
	if _is_grabbing_selected:
		
		# ... then send out a signal to start hovering the piece fast.
		_start_hovering_grabbed_piece(true)
		return true
	
	# Or if we were hovering a piece already...
	if _is_hovering_selected:
		
		# ... then send out a signal with the new hover position.
		for piece in _selected_pieces:
			piece.rpc_unreliable_id(1, "set_hover_position", get_hover_position())
		return true
	
	return false

func _on_VBoxContainer_item_rect_changed():
	if _piece_context_menu and _piece_context_menu_container:
		var size = _piece_context_menu_container.rect_size
		size.x += _piece_context_menu_container.margin_left
		size.y += _piece_context_menu_container.margin_top
		size.x -= _piece_context_menu_container.margin_right
		size.y -= _piece_context_menu_container.margin_bottom
		_piece_context_menu.rect_min_size = size
		_piece_context_menu.rect_size = size
