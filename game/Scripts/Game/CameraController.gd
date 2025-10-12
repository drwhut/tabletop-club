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

enum {
	CONTEXT_CARDS_PUT_IN_HAND = 1,
	
	CONTEXT_PIECE_COPY,
	CONTEXT_PIECE_CUT,
	CONTEXT_PIECE_DELETE,
	CONTEXT_PIECE_DETAILS,
	CONTEXT_PIECE_LOCK,
	CONTEXT_PIECE_PASTE,
	CONTEXT_PIECE_UNLOCK,
	
	CONTEXT_PIECE_CONTAINER_ADD,
	CONTEXT_PIECE_CONTAINER_ADD_SELECTED,
	CONTEXT_PIECE_CONTAINER_PEEK,
	
	CONTEXT_STACK_COLLECT_ALL,
	CONTEXT_STACK_COLLECT_INDIVIDUALS,
	CONTEXT_STACK_ORIENT_ALL_DOWN,
	CONTEXT_STACK_ORIENT_ALL_UP,
	CONTEXT_STACK_SHUFFLE,
	
	CONTEXT_STACK_SORT_NAME,
	CONTEXT_STACK_SORT_SUIT,
	CONTEXT_STACK_SORT_VALUE,
	
	CONTEXT_STACKABLE_PIECE_COLLECT_SELECTED
}

enum {
	CONTEXT_TABLE_PASTE = 1,
	CONTEXT_TABLE_SET_SPAWN_POINT,
	CONTEXT_TABLE_SPAWN_OBJECT
}

enum {
	TOOL_CURSOR,
	TOOL_FLICK,
	TOOL_RULER,
	TOOL_HIDDEN_AREA,
	TOOL_PAINT,
	TOOL_ERASE
}

signal adding_cards_to_hand(cards, id) # If id is 0, add to nearest hand.
signal adding_pieces_to_container(container, pieces)
signal clipboard_paste(position)
signal clipboard_yank(pieces)
signal collect_pieces_requested(pieces)
signal container_release_random_requested(container, n)
signal container_release_these_requested(container, names)
signal dealing_cards(stack, n)
signal erasing(pos1, pos2, size)
signal hover_piece_requested(piece, offset)
signal hover_pieces_requested(pieces, offsets)
signal painting(pos1, pos2, color, size)
signal placing_hidden_area(point1, point2)
signal pop_stack_requested(stack, n)
signal removing_hidden_area(hidden_area)
signal removing_pieces(pieces)
signal selecting_all_pieces()
signal setting_hidden_area_preview_points(point1, point2)
signal setting_hidden_area_preview_visible(is_visible)
signal setting_hover_position_multiple(position)
signal setting_spawn_point(position)
signal spawning_fast_circle()
signal spawning_piece_at(position)
signal spawning_piece_in_container(container_name)
signal stack_collect_all_requested(stack, collect_stacks)


onready var _box_selection_rect = $CanvasLayer/BoxSelectionRect
onready var _brush_color_picker = $CanvasLayer/PaintToolMenu/MarginContainer/VBoxContainer/BrushColorPickerButton
onready var _brush_size_label = $CanvasLayer/PaintToolMenu/MarginContainer/VBoxContainer/HBoxContainer/BrushSizeValueLabel
onready var _brush_size_slider = $CanvasLayer/PaintToolMenu/MarginContainer/VBoxContainer/HBoxContainer/BrushSizeValueSlider
onready var _camera = $Camera
onready var _camera_ui = $CanvasLayer/CameraUI
onready var _color_picker = $CanvasLayer/PieceContextMenu/ColorMenu/ColorPicker
onready var _container_content_dialog = $CanvasLayer/ContainerContentDialog
onready var _control_hint_label = $CanvasLayer/CameraUI/ControlHintLabel
onready var _cursors = $Cursors
onready var _deal_cards_spin_box_button = $CanvasLayer/PieceContextMenu/DealCardsMenu/DealCardsSpinBoxButton
onready var _debug_info_label = $CanvasLayer/CameraUI/DebugInfoLabel
onready var _details_dialog = $CanvasLayer/DetailsDialog
onready var _dice_value_button = $CanvasLayer/PieceContextMenu/DiceValueMenu/VBoxContainer/HBoxContainer/DiceValueButton
onready var _erase_tool_menu = $CanvasLayer/EraseToolMenu
onready var _eraser_size_label = $CanvasLayer/EraseToolMenu/MarginContainer/VBoxContainer/HBoxContainer/EraserSizeValueLabel
onready var _eraser_size_slider = $CanvasLayer/EraseToolMenu/MarginContainer/VBoxContainer/HBoxContainer/EraserSizeValueSlider
onready var _flick_line = $CanvasLayer/FlickLine
onready var _flick_strength_value_label = $CanvasLayer/FlickToolMenu/MarginContainer/VBoxContainer/HBoxContainer/FlickStrengthValueLabel
onready var _flick_strength_value_slider = $CanvasLayer/FlickToolMenu/MarginContainer/VBoxContainer/HBoxContainer/FlickStrengthValueSlider
onready var _flick_tool_menu = $CanvasLayer/FlickToolMenu
onready var _hand_preview_rect = $HandPreviewRect
onready var _mouse_grab = $MouseGrab
onready var _paint_tool_menu = $CanvasLayer/PaintToolMenu
onready var _piece_context_menu = $CanvasLayer/PieceContextMenu
onready var _ruler_scale_slider = $CanvasLayer/RulerToolMenu/MarginContainer/VBoxContainer/HBoxContainer/RulerScaleSlider
onready var _ruler_scale_spin_box = $CanvasLayer/RulerToolMenu/MarginContainer/VBoxContainer/HBoxContainer/RulerScaleSpinBox
onready var _ruler_system_button = $CanvasLayer/RulerToolMenu/MarginContainer/VBoxContainer/SystemButton
onready var _ruler_tool_menu = $CanvasLayer/RulerToolMenu
onready var _rulers = $CanvasLayer/Rulers
onready var _sort_menu = $CanvasLayer/PieceContextMenu/SortMenu
onready var _speaker_menu = $CanvasLayer/PieceContextMenu/SpeakerMenu
onready var _speaker_pause_button = $CanvasLayer/PieceContextMenu/SpeakerMenu/VBoxContainer/HBoxContainer/SpeakerPauseButton
onready var _speaker_play_stop_button = $CanvasLayer/PieceContextMenu/SpeakerMenu/VBoxContainer/HBoxContainer/SpeakerPlayStopButton
onready var _speaker_positional_button = $CanvasLayer/PieceContextMenu/SpeakerMenu/VBoxContainer/SpeakerPositionalButton
onready var _speaker_track_label = $CanvasLayer/PieceContextMenu/SpeakerMenu/VBoxContainer/SpeakerTrackLabel
onready var _speaker_volume_slider = $CanvasLayer/PieceContextMenu/SpeakerMenu/VBoxContainer/SpeakerVolumeSlider
onready var _table_context_menu = $CanvasLayer/TableContextMenu
onready var _take_off_top_spin_box_button = $CanvasLayer/PieceContextMenu/TakeOffTopMenu/TakeOffTopSpinBoxButton
onready var _timer_countdown_time = $CanvasLayer/PieceContextMenu/TimerMenu/VBoxContainer/CountdownContainer/TimerCountdownTime
onready var _timer_menu = $CanvasLayer/PieceContextMenu/TimerMenu
onready var _timer_pause_button = $CanvasLayer/PieceContextMenu/TimerMenu/VBoxContainer/TimerPauseButton
onready var _timer_start_stop_countdown_button = $CanvasLayer/PieceContextMenu/TimerMenu/VBoxContainer/CountdownContainer/StartStopCountdownButton
onready var _timer_start_stop_stopwatch_button = $CanvasLayer/PieceContextMenu/TimerMenu/VBoxContainer/StartStopStopwatchButton
onready var _timer_time_label = $CanvasLayer/PieceContextMenu/TimerMenu/VBoxContainer/TimerTimeLabel
onready var _track_dialog = $CanvasLayer/TrackDialog
onready var _transform_piece_pos_x = $CanvasLayer/PieceContextMenu/TransformMenu/VBoxContainer/PositionContainer/PosXSpinBox
onready var _transform_piece_pos_y = $CanvasLayer/PieceContextMenu/TransformMenu/VBoxContainer/PositionContainer/PosYSpinBox
onready var _transform_piece_pos_z = $CanvasLayer/PieceContextMenu/TransformMenu/VBoxContainer/PositionContainer/PosZSpinBox
onready var _transform_piece_rot_x = $CanvasLayer/PieceContextMenu/TransformMenu/VBoxContainer/RotationContainer/RotXSpinBox
onready var _transform_piece_rot_y = $CanvasLayer/PieceContextMenu/TransformMenu/VBoxContainer/RotationContainer/RotYSpinBox
onready var _transform_piece_rot_z = $CanvasLayer/PieceContextMenu/TransformMenu/VBoxContainer/RotationContainer/RotZSpinBox
onready var _transform_piece_sca_x = $CanvasLayer/PieceContextMenu/TransformMenu/VBoxContainer/ScaleContainer/ScaXSpinBox
onready var _transform_piece_sca_y = $CanvasLayer/PieceContextMenu/TransformMenu/VBoxContainer/ScaleContainer/ScaYSpinBox
onready var _transform_piece_sca_z = $CanvasLayer/PieceContextMenu/TransformMenu/VBoxContainer/ScaleContainer/ScaZSpinBox

const CURSOR_LERP_SCALE = 100.0
const CURSOR_MAX_DIST = 10000.0
const FLICK_MODIFIER = 10.0
const GRABBING_FAST_MIN_MOUSE_SPEED_SQ = 1000.0
const GRABBING_SLOW_TIME = 0.25
const HOVER_Y_MIN = 1.0
const MOVEMENT_ACCEL_SCALAR = 0.125
const MOVEMENT_DECEL_SCALAR = 0.25
const RAY_LENGTH = 1000
const ROTATION_Y_MAX = -0.2
const ROTATION_Y_MIN = -1.5
const TIMER_UPDATE_INTERVAL = 0.5
const ZOOM_ACCEL_SCALAR = 3.0
const ZOOM_CAMERA_NEAR_SCALAR = 0.01
const ZOOM_DISTANCE_MIN = 2.0
const ZOOM_DISTANCE_MAX = 200.0

export(bool) var hand_preview_enabled: bool = true
export(float) var hand_preview_delay: float = 0.5
export(bool) var hold_left_click_to_move: bool = false
export(float) var lift_sensitivity: float = 1.0
export(float) var max_speed: float = 10.0
export(bool) var piece_rotate_invert: bool = false
export(float) var rotation_sensitivity_x: float = -0.01
export(float) var rotation_sensitivity_y: float = -0.01
export(float) var zoom_sensitivity: float = 1.0

var clipboard_contents: Dictionary = {}
var clipboard_yank_position: Vector3 = Vector3()
var send_cursor_position: bool = false

var _box_select_init_pos = Vector2()
var _container_multi_context: PieceContainer = null
var _cursor_on_table = false
var _cursor_position = Vector3()
var _drag_camera_anchor = Vector3()
var _fast_circle_seq = []
var _flick_piece_origin = Vector3()
var _flick_placing_point2 = false
var _future_clipboard_position = Vector3()
var _grabbing_time = 0.0
var _hidden_area_mouse_is_over: HiddenArea = null
var _hidden_area_placing_point2 = false
var _hidden_area_point1 = Vector3()
var _hidden_area_point2 = Vector3()
var _hover_y_pos_base = 7.0
var _hover_y_pos_offset = 0.0
var _initial_transform = Transform.IDENTITY
var _initial_zoom = 0.0
var _is_box_selecting = false
var _is_dragging_camera = false
var _is_erasing = false
var _is_grabbing_selected = false
var _is_hovering_selected = false
var _is_painting = false
var _last_paint_position = Vector3()
var _last_sent_cursor_position = Vector3()
var _move_down = false
var _move_left = false
var _move_right = false
var _move_up = false
var _moved_piece_this_frame = false
var _movement_accel = 0.0
var _movement_dir = Vector3()
var _movement_vel = Vector3()
var _perform_box_select = false
var _piece_mouse_is_over: Piece = null
var _piece_mouse_is_over_last: Piece = null
var _piece_mouse_is_over_time: float = 0.0
var _piece_rotation_amount = 1.0
var _right_click_pos = Vector2()
var _rotation = Vector2()
var _ruler_placing_point2 = false
var _ruler_scale_value_changed_lock = false
var _selected_pieces = []
var _send_erase_position = false
var _send_paint_position = false
var _spawn_point_position = Vector3()
var _speaker_connected: SpeakerPiece = null
var _speaker_ignore_control_signals = false
var _stackable_piece_multi_context: StackablePiece = null
var _target_zoom = 0.0
var _timer_connected: TimerPiece = null
var _timer_last_time_update = 0
var _tool = TOOL_CURSOR
var _use_last_paint_position = false
var _viewport_size_original = Vector2()

# Append an array of pieces to the list of selected pieces.
# pieces: The array of pieces to now be selected.
func append_selected_pieces(pieces: Array) -> void:
	for piece in pieces:
		if piece is Piece and (not piece in _selected_pieces):
			# If a piece is not visible (e.g. if it is in a hidden area), do
			# not allow for it to be selected, otherwise players could just
			# select it and drag it out of the hidden area.
			if piece.visible:
				_selected_pieces.append(piece)
				
				var color = Color.white
				var player = Lobby.get_player(get_tree().get_network_unique_id())
				if player.has("color"):
					color = player["color"]
				piece.set_outline_color(color)

# Apply options from the options menu.
# config: The options to apply.
func apply_options(config: ConfigFile) -> void:
	_camera.fov = config.get_value("video", "fov")
	
	rotation_sensitivity_x = -0.1 * config.get_value("controls", "mouse_horizontal_sensitivity")
	if config.get_value("controls", "mouse_horizontal_invert"):
		rotation_sensitivity_x *= -1
	
	rotation_sensitivity_y = -0.1 * config.get_value("controls", "mouse_vertical_sensitivity")
	if config.get_value("controls", "mouse_vertical_invert"):
		rotation_sensitivity_y *= -1
	
	max_speed = 10.0 + 190.0 * config.get_value("controls", "camera_movement_speed")
	
	hold_left_click_to_move = config.get_value("controls", "left_click_to_move")
	
	zoom_sensitivity = 1.0 + 15.0 * config.get_value("controls", "zoom_sensitivity")
	if config.get_value("controls", "zoom_invert"):
		zoom_sensitivity *= -1
	
	lift_sensitivity = 0.5 + 4.5 * config.get_value("controls", "piece_lift_sensitivity")
	if config.get_value("controls", "piece_lift_invert"):
		lift_sensitivity *= -1
	
	piece_rotate_invert = config.get_value("controls", "piece_rotation_invert")
	
	hand_preview_enabled = config.get_value("controls", "hand_preview_enabled")
	hand_preview_delay = config.get_value("controls", "hand_preview_delay")
	_hand_preview_rect.rect_size.y = int(50 + 250 * config.get_value("controls", "hand_preview_size"))
	
	_control_hint_label.visible = not config.get_value("controls", "hide_control_hints")
	_cursors.visible = not config.get_value("multiplayer", "hide_cursors")

# Clear the list of selected pieces.
func clear_selected_pieces() -> void:
	for piece in _selected_pieces:
		if is_instance_valid(piece):
			piece.set_outline_color(Color.transparent)
	
	_selected_pieces.clear()

# Erase a piece from the list of selected pieces.
# piece: The piece to erase from the list.
func erase_selected_pieces(piece: Piece) -> void:
	if _selected_pieces.has(piece):
		_selected_pieces.erase(piece)
		piece.set_outline_color(Color.transparent)

# Get the current position that pieces should hover at, given the camera and
# mouse positions.
# Returns: The position that hovering pieces should hover at.
func get_hover_position() -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	var hover_pos = _calculate_hover_position(mouse_pos, _hover_y_pos_base)
	hover_pos.y += _hover_y_pos_offset
	return hover_pos

# Get the list of selected pieces.
# Returns: The list of selected pieces.
func get_selected_pieces() -> Array:
	return _selected_pieces

# Nullify references to the given piece. Call this if you know a piece is about
# to be freed from memory.
# ref: The reference to remove.
func remove_piece_ref(ref: Piece) -> void:
	erase_selected_pieces(ref)
	
	# TODO: Check if there is a more elegant solution - it may be problamatic
	# relying on the room to tell us if a piece is about to go out of memory.
	if _container_multi_context == ref:
		_container_multi_context = null
	if _piece_mouse_is_over == ref:
		_piece_mouse_is_over = null
	if _piece_mouse_is_over_last == ref:
		_piece_mouse_is_over_last = null
	if _speaker_connected == ref:
		_speaker_connected = null
	if _stackable_piece_multi_context == ref:
		_stackable_piece_multi_context = null
	if _timer_connected == ref:
		_timer_connected = null

# Request the server to set your cursor image on all other clients.
# cursor_type: The shape of the cursor to set, e.g. Input.CURSOR_ARROW.
master func request_set_cursor(cursor_shape: int) -> void:
	var id = get_tree().get_rpc_sender_id()
	rpc("set_player_cursor", id, cursor_shape)

# Request the server to set your 3D cursor position to all other players.
# position: Your new 3D cursor position.
# x_basis: The x-basis of your camera.
master func request_set_cursor_position(position: Vector3, x_basis: Vector3) -> void:
	var id = get_tree().get_rpc_sender_id()
	for other_id in Lobby.get_player_list():
		if other_id != id:
			rpc_unreliable_id(other_id, "set_player_cursor_position", id, position, x_basis)

# Set if the camera is hovering it's selected pieces.
# is_hovering: If the camera is hovering it's selected pieces.
func set_is_hovering(is_hovering: bool) -> void:
	_is_hovering_selected = is_hovering
	
	var cursor = Input.CURSOR_ARROW
	if is_hovering:
		cursor = Input.CURSOR_DRAG
		
		# If we have started hovering, we have stopped grabbing.
		_is_grabbing_selected = false
	
	_mouse_grab.mouse_default_cursor_shape = cursor
	rpc_id(1, "request_set_cursor", cursor)

# Set the height the controller hovers pieces at.
# hover_height: The height pieces are hovered at by the controller.
remotesync func set_hover_height(hover_height: float) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_hover_y_pos_base = max(0, hover_height)
	_hover_y_pos_offset = 0.0

# Called by the server when a player changes their cursor shape.
# id: The ID of the player.
# cursor_shape: The cursor shape to display.
remotesync func set_player_cursor(id: int, cursor_shape: int) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if id == get_tree().get_network_unique_id():
		return
	
	if not _cursors.has_node(str(id)):
		return
	
	var cursor = _cursors.get_node(str(id))
	if not cursor:
		return
	if not cursor is TextureRect:
		return
	
	cursor.texture = _create_player_cursor_texture(id, cursor_shape)

# Called by the server when a player updates their 3D cursor position.
# id: The ID of the player.
# position: The position of the player's 3D cursor.
# x_basis: The x-basis of the player's camera.
remotesync func set_player_cursor_position(id: int, position: Vector3, x_basis: Vector3) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	if id == get_tree().get_network_unique_id():
		return
	
	if not _cursors.has_node(str(id)):
		return
	
	var cursor = _cursors.get_node(str(id))
	if not cursor:
		return
	if not cursor is TextureRect:
		return
	
	if is_nan(position.x) or is_nan(position.y) or is_nan(position.z):
		return
	elif position.length_squared() > CURSOR_MAX_DIST * CURSOR_MAX_DIST:
		position = CURSOR_MAX_DIST * position.normalized()
	
	if is_nan(x_basis.x) or is_nan(x_basis.y) or is_nan(x_basis.z):
		return
	elif x_basis == Vector3.ZERO:
		x_basis = Vector3.RIGHT
	else:
		x_basis = x_basis.normalized()
	
	cursor.set_meta("cursor_position", position)
	cursor.set_meta("x_basis", x_basis)

# Set the controller's piece rotation amount.
# rotation_amount: The piece rotation amount in radians.
func set_piece_rotation_amount(rotation_amount: float) -> void:
	_piece_rotation_amount = min(max(rotation_amount, 0.0), 2 * PI)

# Set the list of selected pieces.
# pieces: The new list of selected pieces.
func set_selected_pieces(pieces: Array) -> void:
	clear_selected_pieces()
	append_selected_pieces(pieces)

func _ready():
	_viewport_size_original.x = ProjectSettings.get_setting("display/window/size/width")
	_viewport_size_original.y = ProjectSettings.get_setting("display/window/size/height")
	get_viewport().connect("size_changed", self, "_on_Viewport_size_changed")
	
	Lobby.connect("player_added", self, "_on_Lobby_player_added")
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")
	Lobby.connect("player_removed", self, "_on_Lobby_player_removed")
	
	# Get the initial transform and zoom of the camera so we can set it back
	# to these values later.
	_initial_transform = transform
	_initial_zoom = _camera.translation.z
	_reset_camera()
	
	_flick_line.set_label_visible(false)

func _process(delta):
	_moved_piece_this_frame = false
	
	_process_input(delta)
	_process_movement(delta)
	
	if _is_grabbing_selected:
		_grabbing_time += delta
		
		# Have we been grabbing this piece for a long time?
		if _grabbing_time > GRABBING_SLOW_TIME:
			_start_hovering_grabbed_piece(false)
	
	if _piece_mouse_is_over == _piece_mouse_is_over_last:
		_piece_mouse_is_over_time += delta
	else:
		_piece_mouse_is_over_time = 0.0
	_piece_mouse_is_over_last = _piece_mouse_is_over
	
	_hand_preview_rect.visible = false
	if hand_preview_enabled:
		if _piece_mouse_is_over_time > hand_preview_delay:
			if _piece_mouse_is_over is Card:
				if _piece_mouse_is_over.over_hands == [ get_tree().get_network_unique_id() ]:
					if not _selected_pieces.has(_piece_mouse_is_over):
						_hand_preview_rect.visible = true
	
	if _hand_preview_rect.visible:
		var card_entry = _piece_mouse_is_over.piece_entry
		
		var texture_path_key = "texture_path"
		if _piece_mouse_is_over.transform.basis.y.y < 0.0:
			texture_path_key = "texture_path_1"
		var texture_path = card_entry[texture_path_key]
		
		var texture_changed = true
		if _hand_preview_rect.texture:
			if _hand_preview_rect.texture.resource_path == texture_path:
				texture_changed = false
		
		if texture_changed:
			_hand_preview_rect.texture = ResourceManager.load_res(texture_path)
		
		var preview_height = _hand_preview_rect.rect_size.y
		var card_scale = card_entry["scale"]
		var aspect_ratio = card_scale.x / card_scale.z
		_hand_preview_rect.rect_size.x = aspect_ratio * preview_height
		
		var position = get_viewport().get_mouse_position()
		position.y -= preview_height
		_hand_preview_rect.rect_position = position
	
	# TODO: Only do this if the state of the camera changes.
	if _control_hint_label.visible:
		_set_control_hint_label()
	
	if _debug_info_label.visible:
		_set_debug_info_label()
	
	for cursor in _cursors.get_children():
		if cursor is TextureRect:
			if cursor.has_meta("cursor_position") and cursor.has_meta("x_basis"):
				var current_position = cursor.rect_position
				# We check if the cursor position is valid when it is sent to
				# us by the server.
				var target_position = _camera.unproject_position(cursor.get_meta("cursor_position"))
				var lerp_amount = min(CURSOR_LERP_SCALE * delta, 1.0)
				cursor.rect_position = current_position.linear_interpolate(target_position, lerp_amount)
				
				var our_basis = transform.basis.x.normalized()
				var their_basis = cursor.get_meta("x_basis")
				var cos_theta = our_basis.dot(their_basis)
				var cross = our_basis.cross(their_basis)
				
				# Since we normalise the vectors, this should always be true,
				# but just in case, since acos would give NaN otherwise!
				if cos_theta >= -1.0 and cos_theta <= 1.0:
					var target_theta = acos(cos_theta)
					# If the camera goes one way, the cursor needs to go the other
					# way. This is why the if statement isn't < 0.
					if cross.y > 0:
						target_theta = -target_theta
					var current_theta = deg2rad(cursor.rect_rotation)
					cursor.rect_rotation = rad2deg(lerp_angle(current_theta, target_theta, lerp_amount))
	
	if _flick_placing_point2:
		var flick_y = _flick_line.point1.y
		var point2 = _cursor_position
		point2.y = flick_y
		_flick_line.point2 = point2
		_flick_line.update_ruler(_camera)
	
	if _ruler_placing_point2:
		var num_rulers = _rulers.get_child_count()
		if num_rulers > 0:
			var last_ruler = _rulers.get_child(num_rulers - 1)
			last_ruler.point2 = _cursor_position
		else:
			push_error("Placing point two of ruler, but no rulers exist!")
	
	for ruler in _rulers.get_children():
		ruler.update_ruler(_camera)
	
	if _hidden_area_placing_point2:
		_hidden_area_point2 = _cursor_position
		var point1_v2 = Vector2(_hidden_area_point1.x, _hidden_area_point1.z)
		var point2_v2 = Vector2(_hidden_area_point2.x, _hidden_area_point2.z)
		emit_signal("setting_hidden_area_preview_points", point1_v2, point2_v2)
	
	if _timer_connected:
		if _timer_time_label:
			_timer_last_time_update += delta
			if _timer_last_time_update > TIMER_UPDATE_INTERVAL:
				_timer_time_label.text = _timer_connected.get_time_string()
				_timer_last_time_update -= TIMER_UPDATE_INTERVAL

func _physics_process(_delta):
	# Perform a raycast out into the world from the camera.
	var mouse_pos = get_viewport().get_mouse_position()
	var from = _camera.project_ray_origin(mouse_pos)
	var to = from + _camera.project_ray_normal(mouse_pos) * RAY_LENGTH
	
	var space_state = get_world().direct_space_state
	var result = space_state.intersect_ray(from, to)
	
	_cursor_on_table = result.has("collider")
	_hidden_area_mouse_is_over = null
	_piece_mouse_is_over = null
	
	if _cursor_on_table:
		_cursor_position = result["position"]
		if result.collider is Piece:
			_piece_mouse_is_over = result.collider
		
		var area_result = space_state.intersect_ray(from, to, [], 1, false, true)
		if area_result.has("collider"):
			if area_result.collider is HiddenArea:
				_hidden_area_mouse_is_over = area_result.collider
	else:
		_cursor_position = _calculate_hover_position(mouse_pos, 0.0)
	
	if send_cursor_position and _cursor_position:
		if _cursor_position != _last_sent_cursor_position:
			if _is_hovering_selected and (not _selected_pieces.empty()):
				if _piece_mouse_is_over and _selected_pieces.has(_piece_mouse_is_over):
					_cursor_position = _piece_mouse_is_over.transform.origin
				else:
					var total = Vector3()
					for piece in _selected_pieces:
						total += piece.transform.origin
					_cursor_position = total / _selected_pieces.size()
			rpc_unreliable_id(1, "request_set_cursor_position", _cursor_position,
				transform.basis.x)
			_last_sent_cursor_position = _cursor_position
	
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
	
	var paint_pos1 = _last_paint_position if _use_last_paint_position else _cursor_position
	
	if _send_paint_position:
		emit_signal("painting", paint_pos1, _cursor_position, _brush_color_picker.color,
			_brush_size_slider.value)
		_send_paint_position = false
		_use_last_paint_position = true
	
	if _send_erase_position:
		emit_signal("erasing", paint_pos1, _cursor_position, _eraser_size_slider.value)
		_send_erase_position = false
		_use_last_paint_position = true
	
	_last_paint_position = _cursor_position

func _process_input(_delta):
	
	# Calculating the direction the user wants to move parallel to the table.
	var movement_input = Vector2()
	
	if _move_left:
		movement_input.x -= 1
	if _move_right:
		movement_input.x += 1
	if _move_up:
		movement_input.y += 1
	if _move_down:
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
	var delta_vel = clamp(_movement_accel * delta, 0.0, 1.0)
	_movement_vel = _movement_vel.linear_interpolate(target_vel, delta_vel)
	
	# A global translation, as we want to move on the plane parallel to the
	# table, regardless of the direction we are facing.
	var old_translation = translation
	translation += _movement_vel * delta
	
	# If we ended up moving...
	if translation != old_translation:
		_on_moving()
	
	# Go towards the target zoom level.
	var target_offset = Vector3(0, 0, _target_zoom)
	var zoom_accel = zoom_sensitivity * ZOOM_ACCEL_SCALAR
	var zoom_delta = clamp(zoom_accel * delta, 0.0, 1.0)
	_camera.translation = _camera.translation.linear_interpolate(target_offset, zoom_delta)
	
	# Adjust the near value of the camera based on how far away the camera is
	# from the table. If the camera is really far away, it probably won't have
	# anything directly in front of it, so we can make the depth buffer more
	# accurate by having it cover a smaller area.
	_camera.near = clamp(ZOOM_CAMERA_NEAR_SCALAR * _target_zoom, 0.05, 2.0)

func _unhandled_input(event):
	if not (Input.is_key_pressed(KEY_CONTROL) or Input.is_key_pressed(KEY_META)):
		if event.is_action_pressed("game_left"):
			_move_left = true
		elif event.is_action_released("game_left"):
			_move_left = false
		
		elif event.is_action_pressed("game_right"):
			_move_right = true
		elif event.is_action_released("game_right"):
			_move_right = false
		
		elif event.is_action_pressed("game_up"):
			_move_up = true
		elif event.is_action_released("game_up"):
			_move_up = false
		
		elif event.is_action_pressed("game_down"):
			_move_down = true
		elif event.is_action_released("game_down"):
			_move_down = false
	
	if event.is_action_pressed("game_reset_camera"):
		_reset_camera()
	elif event.is_action_pressed("game_delete_piece"):
		_delete_selected_pieces()
	elif event.is_action_pressed("game_lock_piece"):
		var all_locked = true
		for piece in _selected_pieces:
			if piece is Piece:
				if not piece.is_locked():
					all_locked = false
					break
		if all_locked:
			_unlock_selected_pieces()
		else:
			_lock_selected_pieces()
	elif event.is_action_pressed("game_flip_piece"):
		if _selected_pieces.empty():
			if _piece_mouse_is_over != null:
				if is_piece_allowed_modify(_piece_mouse_is_over):
					if _piece_mouse_is_over.is_hovering():
						_piece_mouse_is_over.rpc_id(1, "request_flip_vertically")
					else:
						_piece_mouse_is_over.rpc_id(1, "request_flip_vertically_on_ground")
		else:
			for piece in _selected_pieces:
				if piece is Piece:
					if is_piece_allowed_modify(piece):
						if piece.is_hovering():
							piece.rpc_id(1, "request_flip_vertically")
						else:
							piece.rpc_id(1, "request_flip_vertically_on_ground")
	elif event.is_action_pressed("game_rotate_piece"):
		var amount = _piece_rotation_amount
		if piece_rotate_invert:
				amount *= -1
		if _selected_pieces.empty():
			if _piece_mouse_is_over != null:
				if is_piece_allowed_modify(_piece_mouse_is_over, false):
					if _piece_mouse_is_over.is_hovering():
						_piece_mouse_is_over.rpc_id(1, "request_rotate_y", amount)
					else:
						_piece_mouse_is_over.rpc_id(1, "request_rotate_y_on_ground", amount)
		else:
			for piece in _selected_pieces:
				if piece is Piece:
					if is_piece_allowed_modify(piece, false):
						if piece.is_hovering():
							piece.rpc_id(1, "request_rotate_y", amount)
						else:
							piece.rpc_id(1, "request_rotate_y_on_ground", amount)
	elif event.is_action_pressed("game_reset_piece"):
		if _selected_pieces.empty():
			if _piece_mouse_is_over != null:
				if is_piece_allowed_modify(_piece_mouse_is_over):
					if _piece_mouse_is_over.is_hovering():
						_piece_mouse_is_over.rpc_id(1, "request_reset_orientation")
					else:
						_piece_mouse_is_over.rpc_id(1, "request_reset_orientation_on_ground")
		else:
			for piece in _selected_pieces:
				if piece is Piece:
					if is_piece_allowed_modify(piece):
						if piece.is_hovering():
							piece.rpc_id(1, "request_reset_orientation")
						else:
							piece.rpc_id(1, "request_reset_orientation_on_ground")
	elif event.is_action_pressed("game_shuffle_stack"):
		if _selected_pieces.empty():
			if _piece_mouse_is_over != null and _piece_mouse_is_over is Stack:
				_piece_mouse_is_over.rpc_id(1, "request_shuffle")
		else:
			for piece in _selected_pieces:
				if piece is Stack:
					piece.rpc_id(1, "request_shuffle")
	elif event.is_action_pressed("game_toggle_debug_info"):
		_debug_info_label.visible = not _debug_info_label.visible
	elif event.is_action_pressed("game_toggle_ui"):
		_camera_ui.visible = not _camera_ui.visible
	
	# Allow echo events for zooming in and out so the player doesn't have to
	# spam the input.
	elif event.is_action_pressed("game_zoom_in", true) or event.is_action_pressed("game_zoom_out", true):
		var delta = -1.0 if event.is_action_pressed("game_zoom_in", true) else 1.0
		var ctrl = false
		var alt = false
		
		if event is InputEventWithModifiers:
			ctrl = event.command if OS.get_name() == "OSX" else event.control
			alt = event.control if OS.get_name() == "OSX" else event.alt
		
		_on_scroll(delta, ctrl, alt)
	
						
	if event is InputEventKey:
		var ctrl = event.command if OS.get_name() == "OSX" else event.control
		if event.pressed and ctrl:
			if event.scancode == KEY_A:
				if not _is_hovering_selected:
					emit_signal("selecting_all_pieces")
			elif event.scancode == KEY_X:
				_future_clipboard_position = _cursor_position
				_cut_selected_pieces()
			elif event.scancode == KEY_C:
				_future_clipboard_position = _cursor_position
				_copy_selected_pieces()
			elif event.scancode == KEY_V:
				_future_clipboard_position = _cursor_position
				_paste_clipboard()
		
		if event.pressed:
			var add_true = false
			var add_false = false
			
			if event.scancode == KEY_1 or event.scancode == KEY_KP_1:
				add_false = true
			elif event.scancode == KEY_4 or event.scancode == KEY_KP_4:
				add_true = true
			
			if add_true or add_false:
				if _fast_circle_seq.size() < 7:
					_fast_circle_seq.append(add_true)
				else:
					for i in range(6):
						_fast_circle_seq[i] = _fast_circle_seq[i+1]
					_fast_circle_seq[6] = add_true
				
				if _fast_circle_seq == [true, true, true, false, true, true, true]:
					emit_signal("spawning_fast_circle")
					_fast_circle_seq = []
			elif not _fast_circle_seq.empty():
				_fast_circle_seq[-1] = false
	
	# NOTE: Mouse events are caught by the MouseGrab node, see
	# _on_MouseGrab_gui_input().

# Checks if a piece is allowed to be modified by the current player.
# E.g. to rotate, flip etc
# piece: The piece to check
# in_hand: If the piece is allowed to be modified if in hand
# Returns true if piece can be modified by current player
func is_piece_allowed_modify( piece: Piece, in_hand: bool = true ) -> bool:
	if piece.is_locked():
		return false
	
	var can_modify = not bool(piece is Card)
	if piece is Card:
		if piece.over_hands.empty():
			can_modify = true
		elif in_hand:
			can_modify = bool(piece.over_hands == [ get_tree().get_network_unique_id() ])
	return can_modify

# Calculate the hover position of a piece, given a mouse position on the screen.
# Returns: The hover position of a piece, based on the given mouse position.
# mouse_position: The mouse position on the screen.
# y_position: The y-position of the hover position.
func _calculate_hover_position(mouse_position: Vector2, y_position: float) -> Vector3:
	# Get vectors representing a raycast from the camera.
	var from = _camera.project_ray_origin(mouse_position)
	var to = from + _camera.project_ray_normal(mouse_position) * RAY_LENGTH
	
	# Figure out at which point along this line the piece should hover at,
	# given we want it to hover at a particular Y-level.
	if to.y == from.y:
		return Vector3.ZERO
	var lambda = (y_position - from.y) / (to.y - from.y)
	
	var x = from.x + lambda * (to.x - from.x)
	var z = from.z + lambda * (to.z - from.z)
	
	return Vector3(x, y_position, z)

# Create a cursor texture representing a given player.
# Returns: A cursor texture representing a given player.
# id: The ID of the player.
# cursor_shape: The cursor shape to display.
func _create_player_cursor_texture(id: int, cursor_shape: int) -> ImageTexture:
	var cursor_image: Image = null
	match cursor_shape:
		Input.CURSOR_ARROW:
			cursor_image = preload("res://Images/ArrowCursor.png")
		Input.CURSOR_DRAG:
			cursor_image = preload("res://Images/GrabbingCursor.png")
		Input.CURSOR_POINTING_HAND:
			cursor_image = preload("res://Images/PointingCursor.png")
		Input.CURSOR_HSIZE:
			cursor_image = preload("res://Images/HResizeCursor.png")
		Input.CURSOR_FORBIDDEN:
			cursor_image = preload("res://Images/ForbiddenCursor.png")
		Input.CURSOR_CROSS:
			cursor_image = preload("res://Images/CrossCursor.png")
		_:
			push_error("Invalid index for cursor shape (%d)!" % cursor_shape)
			return null
	
	# Create a clone of the image, so we don't modify the original.
	var clone_image = Image.new()
	cursor_image.lock()
	clone_image.create_from_data(cursor_image.get_width(),
		cursor_image.get_height(), false, cursor_image.get_format(),
		cursor_image.get_data())
	cursor_image.unlock()
	
	# Get the player's color.
	var mask_color = Color.white
	if Lobby.player_exists(id):
		var player = Lobby.get_player(id)
		if player.has("color"):
			mask_color = player["color"]
			mask_color.a = 1.0
	
	# Perform a multiply operation on the image.
	clone_image.lock()
	for x in range(clone_image.get_width()):
		for y in range(clone_image.get_height()):
			var pixel = clone_image.get_pixel(x, y)
			clone_image.set_pixel(x, y, pixel * mask_color)
	clone_image.unlock()
	
	var new_texture = ImageTexture.new()
	new_texture.create_from_image(clone_image)
	return new_texture

# Copy the selected pieces to the clipboard.
func _copy_selected_pieces() -> void:
	_hide_context_menu()
	clipboard_yank_position = _future_clipboard_position
	
	# Adjust the y value of the yank position, such that we yank from the
	# lowest point of the selection - this way, when the objects are pasted on
	# the surface of the table (y = 0), they do not spawn in the ground.
	var min_y = clipboard_yank_position.y
	for piece in _selected_pieces:
		var height = piece.get_size().y
		var lowest_y = piece.translation.y - (height / 2.0)
		if lowest_y < min_y:
			if lowest_y < 0.0:
				min_y = 0.0
				break
			else:
				min_y = lowest_y
	
	clipboard_yank_position.y = min_y
	
	emit_signal("clipboard_yank", _selected_pieces)

# Cut the selected pieces to the clipboard.
func _cut_selected_pieces() -> void:
	_copy_selected_pieces()
	_delete_selected_pieces()

# Delete the currently selected pieces from the game.
func _delete_selected_pieces() -> void:
	_hide_context_menu()
	emit_signal("removing_pieces", _selected_pieces)

# Get the scale nessesary to make cursors appear the same size regardless of
# resolution.
# Returns: The scale.
func _get_cursor_scale() -> Vector2:
	var from = get_viewport().size
	var to = _viewport_size_original
	
	var out = Vector2(to.x / from.x, to.y / from.y)
	
	return out

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
	
	# Force submenus to hide as well.
	for child in _piece_context_menu.get_children():
		if child is PopupPanel:
			child.visible = false

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

# Lock the currently selected pieces.
func _lock_selected_pieces() -> void:
	_hide_context_menu()
	for piece in _selected_pieces:
		if piece is Piece:
			piece.rpc_id(1, "request_lock")

func _on_speaker_is_positional_changed(_is_positional: bool) -> void:
	_set_speaker_controls()

func _on_speaker_started_playing() -> void:
	_set_speaker_controls()

func _on_speaker_stopped_playing() -> void:
	_set_speaker_controls()

func _on_speaker_track_changed(_track_entry: Dictionary, _music: bool) -> void:
	_set_speaker_controls()

func _on_speaker_track_paused() -> void:
	_set_speaker_controls()

func _on_speaker_track_resumed() -> void:
	_set_speaker_controls()

func _on_speaker_unit_size_changed(_unit_size: float) -> void:
	_set_speaker_controls()

func _on_timer_mode_changed(_new_mode: int) -> void:
	_set_timer_controls()

func _on_timer_paused() -> void:
	_set_timer_controls()

func _on_timer_resumed() -> void:
	_set_timer_controls()

# Paste the contents of the clipboard.
func _paste_clipboard() -> void:
	_hide_context_menu()
	
	if not clipboard_contents.empty():
		emit_signal("clipboard_paste", _future_clipboard_position)

# Popup the piece context menu.
func _popup_piece_context_menu() -> void:
	if _selected_pieces.empty():
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
	_piece_context_menu.clear()
	var prev_num_items = 0
	
	# TODO: Show size of stack, as well as general info like the description.
	
	################
	# MULTI-OBJECT #
	################
	
	_container_multi_context = null
	if _piece_mouse_is_over is PieceContainer:
		if _selected_pieces.size() > 1:
			_piece_context_menu.add_item(tr("Add selected objects..."), CONTEXT_PIECE_CONTAINER_ADD_SELECTED)
			_container_multi_context = _piece_mouse_is_over
	
	##############
	# STACK INFO #
	##############
	
	if _inheritance_has(inheritance, "StackablePiece"):
		var size = 0
		var value = 0
		var show_value = true
		
		for stack in _selected_pieces:
			if stack is Stack:
				size += stack.get_piece_count()
			else:
				size += 1
			
			if show_value:
				var piece_entry_list = []
				if stack is Stack:
					for piece_meta in stack.get_pieces():
						piece_entry_list.append(piece_meta["piece_entry"])
				else:
					piece_entry_list = [stack.piece_entry]
				
				for piece_entry in piece_entry_list:
					var piece_suit  = piece_entry["suit"]
					var piece_value = piece_entry["value"]
					
					var value_is_num = (typeof(piece_value) == TYPE_INT or
							typeof(piece_value) == TYPE_REAL)
					
					if typeof(piece_suit) == TYPE_NIL and value_is_num:
						value += piece_value
					else:
						show_value = false
						break
		
		_piece_context_menu.add_item(tr("Count: %d") % size)
		if show_value:
			_piece_context_menu.add_item(tr("Value: %d") % value)
	
	###########
	# LEVEL 2 #
	###########
	
	if _piece_context_menu.get_item_count() > prev_num_items:
		_piece_context_menu.add_separator()
	prev_num_items = _piece_context_menu.get_item_count()
	
	# If the pieces consist of both cards and stacks of cards, then the
	# inheritance should include the StackablePiece class.
	if _inheritance_has(inheritance, "StackablePiece"):
		var only_cards = true
		for piece in _selected_pieces:
			if not (piece is Card or (piece is Stack and piece.is_card_stack())):
				only_cards = false
				break
		
		if only_cards:
			_piece_context_menu.add_item(tr("Put in hand"), CONTEXT_CARDS_PUT_IN_HAND)
	
	if _inheritance_has(inheritance, "Stack"):
		if _selected_pieces.size() == 1:
			_piece_context_menu.add_item(tr("Collect individuals"), CONTEXT_STACK_COLLECT_INDIVIDUALS)
			_piece_context_menu.add_item(tr("Collect all"), CONTEXT_STACK_COLLECT_ALL)
			
			var stack = _selected_pieces[0]
			if stack.is_card_stack():
				_piece_context_menu.add_submenu_item(tr("Deal cards"), "DealCardsMenu")
				_deal_cards_spin_box_button.max_value = stack.get_piece_count()
			
			_piece_context_menu.add_submenu_item(tr("Take off top"), "TakeOffTopMenu")
			_take_off_top_spin_box_button.max_value = stack.get_piece_count()
		
		_piece_context_menu.add_item(tr("Orient all up"), CONTEXT_STACK_ORIENT_ALL_UP)
		_piece_context_menu.add_item(tr("Orient all down"), CONTEXT_STACK_ORIENT_ALL_DOWN)
		_piece_context_menu.add_item(tr("Shuffle"), CONTEXT_STACK_SHUFFLE)
		
		_sort_menu.clear()
		var optional_keys = [ "suit", "value" ]
		for stack in _selected_pieces:
			for piece_meta in stack.get_pieces():
				var piece_entry = piece_meta["piece_entry"]
				for key_index in range(optional_keys.size()-1, -1, -1):
					var key = optional_keys[key_index]
					var keep_key = false
					if piece_entry.has(key):
						if piece_entry[key] != null:
							keep_key = true
					
					if not keep_key:
						optional_keys.remove(key_index)
		
		_sort_menu.add_item(tr("Name"), CONTEXT_STACK_SORT_NAME)
		if optional_keys.has("suit"):
			_sort_menu.add_item(tr("Suit"), CONTEXT_STACK_SORT_SUIT)
		if optional_keys.has("value"):
			_sort_menu.add_item(tr("Value"), CONTEXT_STACK_SORT_VALUE)
		_sort_menu.set_as_minsize()
		_piece_context_menu.add_submenu_item(tr("Sort by"), "SortMenu")
	
	elif _inheritance_has(inheritance, "TimerPiece"):
		if _selected_pieces.size() == 1:
			_timer_connected = _selected_pieces[0]
			_timer_connected.connect("mode_changed", self, "_on_timer_mode_changed")
			_timer_connected.connect("timer_paused", self, "_on_timer_paused")
			_timer_connected.connect("timer_resumed", self, "_on_timer_resumed")
			
			_piece_context_menu.add_submenu_item(tr("Timer"), "TimerMenu")
			_set_timer_controls()
			
			# Start updating the time label in _process().
			_timer_last_time_update = 0
	
	###########
	# LEVEL 1 #
	###########
	
	_stackable_piece_multi_context = null
	
	if _piece_context_menu.get_item_count() > prev_num_items:
		_piece_context_menu.add_separator()
	prev_num_items = _piece_context_menu.get_item_count()
	
	if _inheritance_has(inheritance, "Dice"):
		var single_dice_value := ""
		var total := 0.0
		var available_values := []
		for dice in _selected_pieces:
			var value: String = dice.get_face_value()
			single_dice_value = value
			if value.is_valid_float():
				total += float(value)
			
			var face_value_dict: Dictionary = dice.piece_entry["face_values"]
			for possible_value in face_value_dict.keys():
				if not available_values.has(possible_value):
					available_values.append(possible_value)
		available_values.sort()
		
		if len(_selected_pieces) == 1:
			# If there's a single piece, we should show value text (if any).
			# (There are various symbol dice that benefit, i.e. Zombie Dice)
			if single_dice_value == "":
				_piece_context_menu.add_item(tr("Value: (None)"))
			else:
				_piece_context_menu.add_item(tr("Value: %s") % single_dice_value)
		else:
			var is_int = (round(total) == total)
			if is_int:
				_piece_context_menu.add_item(tr("Total: %d") % total)
			else:
				_piece_context_menu.add_item(tr("Total: %f") % total)
		
		var prev_value := single_dice_value
		if _dice_value_button.selected >= 0:
			prev_value = _dice_value_button.get_item_metadata(
					_dice_value_button.selected)
		
		_dice_value_button.clear()
		for value in available_values:
			var new_index = _dice_value_button.get_item_count()
			_dice_value_button.add_item(str(value))
			_dice_value_button.set_item_metadata(new_index, value)
			if value == prev_value and typeof(value) == typeof(prev_value):
				_dice_value_button.select(new_index)
		_piece_context_menu.add_submenu_item(tr("Set value"), "DiceValueMenu")
	
	elif _inheritance_has(inheritance, "StackablePiece"):
		if _piece_mouse_is_over != null and _piece_mouse_is_over is StackablePiece:
			_stackable_piece_multi_context = _piece_mouse_is_over
		if _selected_pieces.size() > 1:
			_piece_context_menu.add_item(tr("Collect selected"), CONTEXT_STACKABLE_PIECE_COLLECT_SELECTED)
	
	elif _inheritance_has(inheritance, "PieceContainer"):
		if _selected_pieces.size() == 1:
			_piece_context_menu.add_item(tr("Add objects..."), CONTEXT_PIECE_CONTAINER_ADD)
			_piece_context_menu.add_item(tr("Peek inside"), CONTEXT_PIECE_CONTAINER_PEEK)
			
			_piece_context_menu.add_submenu_item(tr("Take objects out"), "TakeOutMenu")
			# We don't set the maximum number of things we can take out here,
			# as we don't want the player knowing how many items are in the
			# container.
	
	elif _inheritance_has(inheritance, "SpeakerPiece"):
		if _selected_pieces.size() == 1:
			_speaker_connected = _selected_pieces[0]
			_speaker_connected.connect("is_positional_changed", self, "_on_speaker_is_positional_changed")
			_speaker_connected.connect("started_playing", self, "_on_speaker_started_playing")
			_speaker_connected.connect("stopped_playing", self, "_on_speaker_stopped_playing")
			_speaker_connected.connect("track_changed", self, "_on_speaker_track_changed")
			_speaker_connected.connect("track_paused", self, "_on_speaker_track_paused")
			_speaker_connected.connect("track_resumed", self, "_on_speaker_track_resumed")
			_speaker_connected.connect("unit_size_changed", self, "_on_speaker_unit_size_changed")
			
			_piece_context_menu.add_submenu_item(tr("Speaker"), "SpeakerMenu")
			_set_speaker_controls()
	
	###########
	# LEVEL 0 #
	###########
	
	if _piece_context_menu.get_item_count() > prev_num_items:
		_piece_context_menu.add_separator()
	prev_num_items = _piece_context_menu.get_item_count()
	
	if _inheritance_has(inheritance, "Piece"):
		_piece_context_menu.add_item(tr("Details…"), CONTEXT_PIECE_DETAILS)
		
		var all_albedo_color_exposed = true
		for piece in _selected_pieces:
			if not piece.is_albedo_color_exposed():
				all_albedo_color_exposed = false
				break
		
		if all_albedo_color_exposed:
			_piece_context_menu.add_submenu_item(tr("Color"), "ColorMenu")
			_color_picker.color = _selected_pieces[0].get_albedo_color()
		
		_piece_context_menu.add_item(tr("Cut"), CONTEXT_PIECE_CUT)
		_piece_context_menu.add_item(tr("Copy"), CONTEXT_PIECE_COPY)
		
		_piece_context_menu.add_item(tr("Paste"), CONTEXT_PIECE_PASTE)
		var paste_idx = _piece_context_menu.get_item_count() - 1
		_piece_context_menu.set_item_disabled(paste_idx, clipboard_contents.empty())
		_future_clipboard_position = _cursor_position
		
		var num_locked = 0
		for piece in _selected_pieces:
			if piece.is_locked():
				num_locked += 1
		
		if num_locked == _selected_pieces.size():
			_piece_context_menu.add_item(tr("Unlock"), CONTEXT_PIECE_UNLOCK)
		else:
			_piece_context_menu.add_item(tr("Lock"), CONTEXT_PIECE_LOCK)
		
		_piece_context_menu.add_item(tr("Delete"), CONTEXT_PIECE_DELETE)
		
		_piece_context_menu.add_submenu_item(tr("Transform"), "TransformMenu")
		var first_transform: Transform = _selected_pieces[0].transform
		_transform_piece_pos_x.value = first_transform.origin.x
		_transform_piece_pos_y.value = first_transform.origin.y
		_transform_piece_pos_z.value = first_transform.origin.z
		var euler = first_transform.basis.get_euler()
		_transform_piece_rot_x.value = rad2deg(euler[0])
		_transform_piece_rot_y.value = rad2deg(euler[1])
		_transform_piece_rot_z.value = rad2deg(euler[2])
		var current_scale = _selected_pieces[0].get_current_scale()
		_transform_piece_sca_x.value = current_scale.x
		_transform_piece_sca_y.value = current_scale.y
		_transform_piece_sca_z.value = current_scale.z
	
	_piece_context_menu.rect_position = get_viewport().get_mouse_position()
	_piece_context_menu.set_as_minsize()
	_piece_context_menu.popup()

# Popup the table context menu.
func _popup_table_context_menu() -> void:
	_table_context_menu.clear()
	
	_table_context_menu.add_item(tr("Paste"), CONTEXT_TABLE_PASTE)
	var paste_idx = _table_context_menu.get_item_count() - 1
	_table_context_menu.set_item_disabled(paste_idx, clipboard_contents.empty())
	_future_clipboard_position = _cursor_position
	
	_table_context_menu.add_item(tr("Set spawn point here"), CONTEXT_TABLE_SET_SPAWN_POINT)
	_table_context_menu.add_item(tr("Spawn object here"), CONTEXT_TABLE_SPAWN_OBJECT)
	
	_table_context_menu.rect_position = get_viewport().get_mouse_position()
	_table_context_menu.set_as_minsize()
	_table_context_menu.popup()

# Reset the camera transform and zoom to their initial states.
func _reset_camera() -> void:
	transform = _initial_transform
	var euler = transform.basis.get_euler()
	_rotation = Vector2(euler.y, euler.x)
	
	_camera.translation.z = _initial_zoom
	_target_zoom = _initial_zoom

# Set the control hint label's text based on the camera's state.
func _set_control_hint_label() -> void:
	var text = "[right][table=2]"
	
	var alt     = tr("Alt + %s")
	var ctrl    = tr("Ctrl + %s")
	var cmd     = tr("Cmd + %s")
	var hold    = tr("Hold %s")
	var release = tr("Release %s")
	
	var hovering = _is_hovering_selected or _is_grabbing_selected
	
	############
	# MOVEMENT #
	############
	var sw = tr("Scroll Wheel")
	
	if not hold_left_click_to_move:
		text += _set_control_hint_label_row_actions(tr("Move camera"),
			["game_up", "game_left", "game_down", "game_right"])
	
	if not hovering:
		text += _set_control_hint_label_row_actions(tr("Rotate camera"),
			["game_rotate"], tr("Hold %s + Move Mouse"))
		
		# Only show the zoom in and zoom out actions when in the "default"
		# camera state - otherwise, the hint label will get quite large.
		var zi = BindManager.get_action_input_event_text("game_zoom_in")
		var zo = BindManager.get_action_input_event_text("game_zoom_out")
		var sw_extra = "%s / %s / %s" % [sw, zi, zo]
		
		text += _set_control_hint_label_row(tr("Zoom camera"), sw_extra)
	
	#####################
	# LEFT MOUSE BUTTON #
	#####################
	var lmb = tr("Left Mouse Button")
	
	if _tool == TOOL_CURSOR:
		
		if hovering:
			text += _set_control_hint_label_row(tr("Release selected"), lmb, release)
		elif _is_box_selecting:
			text += _set_control_hint_label_row(tr("Stop box selecting"), lmb, release)
		elif _piece_mouse_is_over:
			if not _piece_mouse_is_over in _selected_pieces:
				text += _set_control_hint_label_row(tr("Select object"), lmb)
				if not _selected_pieces.empty():
					text += _set_control_hint_label_row(tr("Add to selection"), lmb, ctrl)
			
			if _piece_mouse_is_over is PieceContainer:
				text += _set_control_hint_label_row(tr("Take random object"), lmb,
					tr("%s + Move Mouse"))
			elif _piece_mouse_is_over is Stack:
				text += _set_control_hint_label_row(tr("Take top object"), lmb,
					tr("%s + Move Mouse"))
			
			var name = tr("Grab selected") if _piece_mouse_is_over in _selected_pieces else tr("Grab object")
			text += _set_control_hint_label_row(name, lmb, hold)
		elif hold_left_click_to_move:
			var name = tr("Stop moving") if _is_dragging_camera else tr("Start moving")
			var mod  = release if _is_dragging_camera else hold
			text += _set_control_hint_label_row(name, lmb, mod)
		else:
			text += _set_control_hint_label_row(tr("Box select"), lmb, hold)
	
	elif _tool == TOOL_FLICK:
		if _flick_placing_point2:
			text += _set_control_hint_label_row(tr("Flick object"), lmb)
		elif _piece_mouse_is_over:
			text += _set_control_hint_label_row(tr("Prepare to flick"), lmb)
	
	elif _tool == TOOL_RULER:
		if _ruler_placing_point2:
			text += _set_control_hint_label_row(tr("Stop measuring"), lmb)
		else:
			text += _set_control_hint_label_row(tr("Start measuring"), lmb)
	
	elif _tool == TOOL_HIDDEN_AREA:
		if _hidden_area_placing_point2:
			text += _set_control_hint_label_row(tr("Create hidden area"), lmb)
		else:
			text += _set_control_hint_label_row(tr("Draw hidden area"), lmb)
	
	elif _tool == TOOL_PAINT:
		text += _set_control_hint_label_row(tr("Paint Table"), lmb, hold)
	
	elif _tool == TOOL_ERASE:
		text += _set_control_hint_label_row(tr("Erase Paint"), lmb, hold)
	
	######################
	# RIGHT MOUSE BUTTON #
	######################
	var rmb = tr("Right Mouse Button")
	
	if _tool == TOOL_CURSOR and (not hovering):
		
		if _piece_mouse_is_over:
			text += _set_control_hint_label_row(tr("Object menu"), rmb)
		elif _cursor_on_table:
			text += _set_control_hint_label_row(tr("Table menu"), rmb)
	
	elif _tool == TOOL_FLICK:
		if _flick_placing_point2:
			text += _set_control_hint_label_row(tr("Stop flicking"), rmb)
	
	elif _tool == TOOL_RULER:
		if _rulers.get_child_count() > 0:
			text += _set_control_hint_label_row(tr("Remove last ruler"), rmb)
	
	elif _tool == TOOL_HIDDEN_AREA:
		if _hidden_area_mouse_is_over:
			text += _set_control_hint_label_row(tr("Remove hidden area"), rmb)
	
	elif _tool == TOOL_PAINT:
		pass
	
	elif _tool == TOOL_ERASE:
		pass
	
	#########
	# OTHER #
	#########
	var is_card_in_hand = false
	if not _selected_pieces.empty():
		if _is_hovering_selected:
			text += _set_control_hint_label_row_actions(tr("Shuffle"), 
				["game_shuffle_stack"])
			
			var ctrl_mod = cmd if OS.get_name() == "OSX" else ctrl
			var alt_mod = ctrl if OS.get_name() == "OSX" else alt
			
			text += _set_control_hint_label_row(tr("Lift selected"), sw)
			text += _set_control_hint_label_row(tr("Zoom selected"), sw, ctrl_mod)
			text += _set_control_hint_label_row(tr("Rotate selected"), sw, alt_mod)
		
		var all_locked = true
		for piece in _selected_pieces:
			if is_instance_valid(piece):
				if piece is Piece:
					if not piece.is_locked():
						all_locked = false
						break
		var lock = tr("Unlock selected") if all_locked else tr("Lock selected")
		text += _set_control_hint_label_row_actions(lock, ["game_lock_piece"])
		
		text += _set_control_hint_label_row_actions(tr("Delete selected"),
			["game_delete_piece"])
		
		# Check if all pieces are in hand or if one piece is not in hand
		for piece in _selected_pieces:
			if piece is Card:
				if piece.over_hands == [ get_tree().get_network_unique_id() ]:
					is_card_in_hand = true
				else:
					is_card_in_hand = false
					break
		if is_card_in_hand:
			text += _set_control_hint_label_row_actions(tr("Reset orientation"),
				["game_reset_piece"])
			text += _set_control_hint_label_row_actions(tr("Flip orientation"),
				["game_flip_piece"])
	
	elif _piece_mouse_is_over != null and _piece_mouse_is_over is Card:
		if _piece_mouse_is_over.over_hands == [ get_tree().get_network_unique_id() ]:
			if not _piece_mouse_is_over.is_collisions_on():
				text += _set_control_hint_label_row_actions(tr("Flip card"),
						["game_flip_piece"])
				text += _set_control_hint_label_row_actions(tr("Face card up"),
						["game_reset_piece"])
				is_card_in_hand = true
	
	if (not _selected_pieces.empty() or _piece_mouse_is_over != null) and not is_card_in_hand:
		text += _set_control_hint_label_row_actions(tr("Rotate Piece"),
			["game_rotate_piece"])
		text += _set_control_hint_label_row_actions(tr("Reset orientation"),
			["game_reset_piece"])
		text += _set_control_hint_label_row_actions(tr("Flip orientation"),
			["game_flip_piece"])
	
	if _piece_mouse_is_over != null and _piece_mouse_is_over is Stack:
		text += _set_control_hint_label_row_actions(tr("Shuffle"),
				["game_shuffle_stack"])
	
	text += _set_control_hint_label_row_actions(tr("Reset camera"), ["game_reset_camera"])
	
	text += "[/table][/right]"
	
	# Make sure the label is flush with the bottom of the frame.
	var old_height = _control_hint_label.rect_size.y
	_control_hint_label.bbcode_text = ""
	# This doesn't actually set the height to 0, it just sets it to the
	# smallest height possible.
	_control_hint_label.rect_size.y = 0
	_control_hint_label.rect_position.y += old_height - _control_hint_label.rect_size.y
	_control_hint_label.bbcode_text = text

# Generate a row of text for the control hint label.
# Returns: A row of text formatted with BBCode.
# name: The name of the row.
# desc: The description of the row.
# mod: String to modify the row description - should contain one '%s'.
func _set_control_hint_label_row(name: String, desc: String, mod: String = "%s") -> String:
	return "[cell][b]%s:[/b][/cell][cell]%s[/cell]" % [name, mod % desc]

# Generate a row of text for the control hint label using an array of actions.
# Returns: A row of text formatted with BBCode.
# name: The name of the row.
# actions: An array of action strings, which will be converted into their input
# event bindings.
# mod: String to modify the row description - should contain one '%s'.
func _set_control_hint_label_row_actions(name: String, actions: Array,
	mod: String = "%s") -> String:
	
	var desc = ""
	var first = true
	for action in actions:
		if not first:
			desc += "/"
		desc += BindManager.get_action_input_event_text(action)
		first = false
	
	return _set_control_hint_label_row(name, desc, mod)

# Set the debug info label's text based on the state of the game.
func _set_debug_info_label() -> void:
	var text = ""
	
	#######################
	# GAME/ENGINE VERSION #
	#######################
	
	text += ProjectSettings.get_setting("application/config/name")
	if ProjectSettings.has_setting("application/config/version"):
		text += " " + ProjectSettings.get_setting("application/config/version")
	text += " (%s)\n" % ("Debug" if OS.is_debug_build() else "Release")
	
	text += "Godot %s\n" % Engine.get_version_info()["string"]
	
	##########
	# DEVICE #
	##########
	
	text += "Video Adapter: %s\n" % VisualServer.get_video_adapter_name()
	
	###############
	# PERFORMANCE #
	###############
	
	text += "FPS: %.0f\n" % Performance.get_monitor(Performance.TIME_FPS)
	text += "Frame Time: %.3fms\n" % (1000 * Performance.get_monitor(Performance.TIME_PROCESS))
	text += "Physics Frame Time: %.3fms\n" % (1000 * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	
	###########
	# OBJECTS #
	###########
	
	text += "Objects: %.0f\n" % Performance.get_monitor(Performance.OBJECT_COUNT)
	text += "Resources: %.0f\n" % Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
	text += "Nodes: %.0f\n" % Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	text += "Orphan Nodes: %.0f\n" % Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	
	###########
	# PHYSICS #
	###########
	
	text += "Physics Objects: %.0f\n" % Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS)
	
	##########
	# MEMORY #
	##########
	
	if OS.is_debug_build():
		var static_used = Performance.get_monitor(Performance.MEMORY_STATIC)
		var static_max = Performance.get_monitor(Performance.MEMORY_STATIC_MAX)
		var dynamic_used = Performance.get_monitor(Performance.MEMORY_DYNAMIC)
		var dynamic_max = Performance.get_monitor(Performance.MEMORY_DYNAMIC_MAX)
		
		text += "Static Memory: %s/%s\n" % [String.humanize_size(static_used),
			String.humanize_size(static_max)]
		text += "Dynamic Memory: %s/%s\n" % [String.humanize_size(dynamic_used),
			String.humanize_size(dynamic_max)]
	
	var video_memory = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)
	text += "Video Memory: %s\n" % String.humanize_size(video_memory)
	
	###########
	# NETWORK #
	###########
	
	text += "Network ID: %d\n" % get_tree().get_network_unique_id()
	
	##########
	# CAMERA #
	##########
	
	var camera_pos = _camera.global_transform.origin
	text += "Camera Position: %s\n" % str(camera_pos)
	var camera_rot = (180.0 / PI) * _camera.global_transform.basis.get_euler()
	text += "Camera Rotation: %s\n" % str(camera_rot)
	text += "Cursor Position: %s\n" % str(_cursor_position)
	
	var cursor_over = "None"
	if _piece_mouse_is_over:
		var piece_name = _piece_mouse_is_over.name
		var piece_entry = _piece_mouse_is_over.piece_entry
		var entry_path: String = piece_entry["entry_path"]
		
		# Hide the identity of a card if it is in someone else's hand.
		if _piece_mouse_is_over is Card:
			var hand_id_arr = _piece_mouse_is_over.over_hands
			if not hand_id_arr.empty():
				if not get_tree().get_network_unique_id() in hand_id_arr:
					entry_path = "???"
		
		cursor_over = "Piece %s (%s)" % [piece_name, entry_path]
	elif _hidden_area_mouse_is_over:
		var area_name = _hidden_area_mouse_is_over.name
		cursor_over = "Hidden Area %s" % area_name
	elif _cursor_on_table:
		cursor_over = "Table"
	text += "Cursor Over: %s\n" % cursor_over
	
	var hovering_text = "No"
	if _is_hovering_selected:
		hovering_text = "Yes %s" % str(get_hover_position())
	text += "Hovering: %s\n" % hovering_text
	
	_debug_info_label.text = text

# Set the properties of controls relating to the selected speaker.
func _set_speaker_controls() -> void:
	if _speaker_connected:
		_speaker_ignore_control_signals = true
		
		if _speaker_pause_button:
			_speaker_pause_button.disabled = true
			_speaker_pause_button.text = tr("Pause track")
			
			if _speaker_connected.is_playing_track():
				_speaker_pause_button.disabled = false
				if _speaker_connected.is_track_paused():
					_speaker_pause_button.text = tr("Resume track")
		
		if _speaker_play_stop_button:
			if _speaker_connected.is_playing_track():
				_speaker_play_stop_button.text = tr("Stop track")
			else:
				_speaker_play_stop_button.text = tr("Play track")
		
		if _speaker_track_label:
			var track_entry = _speaker_connected.get_track()
			if track_entry.empty():
				_speaker_track_label.text = tr("No track loaded")
			elif _speaker_connected.is_playing_track():
				_speaker_track_label.text = tr("Playing: %s") % track_entry["name"]
			else:
				_speaker_track_label.text = tr("Loaded: %s") % track_entry["name"]
		
		if _speaker_positional_button:
			_speaker_positional_button.pressed = _speaker_connected.is_positional()
		
		if _speaker_volume_slider:
			_speaker_volume_slider.editable = _speaker_connected.is_positional()
			_speaker_volume_slider.value = _speaker_connected.get_unit_size()
		
		_speaker_ignore_control_signals = false

# Set the properties of controls relating to the selected timer.
func _set_timer_controls() -> void:
	if _timer_connected:
		if _timer_pause_button:
			_timer_pause_button.disabled = false
			_timer_pause_button.text = tr("Pause timer")
			
			if _timer_connected.get_mode() == TimerPiece.MODE_SYSTEM_TIME:
				_timer_pause_button.disabled = true
			elif _timer_connected.is_timer_paused():
				_timer_pause_button.text = tr("Resume timer")
		
		if _timer_start_stop_countdown_button:
			if _timer_connected.get_mode() == TimerPiece.MODE_COUNTDOWN:
				_timer_start_stop_countdown_button.text = tr("Stop countdown")
			else:
				_timer_start_stop_countdown_button.text = tr("Start countdown")
		
		if _timer_start_stop_stopwatch_button:
			if _timer_connected.get_mode() == TimerPiece.MODE_STOPWATCH:
				_timer_start_stop_stopwatch_button.text = tr("Stop stopwatch")
			else:
				_timer_start_stop_stopwatch_button.text = tr("Start stopwatch")
		
		if _timer_time_label:
			_timer_time_label.text = _timer_connected.get_time_string()

# Set the tool used by the player.
# new_tool: The tool to be used. See the TOOL_* enum for possible values.
func _set_tool(new_tool: int) -> void:
	if new_tool < TOOL_CURSOR or new_tool > TOOL_ERASE:
		push_error("Invalid argument for _set_tool!")
		return
	
	if new_tool == _tool:
		return
	
	var cursor = Input.CURSOR_ARROW
	match new_tool:
		TOOL_CURSOR:
			cursor = Input.CURSOR_ARROW
		TOOL_FLICK:
			cursor = Input.CURSOR_POINTING_HAND
		TOOL_RULER:
			cursor = Input.CURSOR_HSIZE
		TOOL_HIDDEN_AREA:
			cursor = Input.CURSOR_FORBIDDEN
		TOOL_PAINT:
			cursor = Input.CURSOR_CROSS
		TOOL_ERASE:
			cursor = Input.CURSOR_CROSS
	
	_mouse_grab.mouse_default_cursor_shape = cursor
	rpc_id(1, "request_set_cursor", cursor)
	
	clear_selected_pieces()
	
	_flick_placing_point2 = false
	_flick_line.visible = false
	
	_ruler_placing_point2 = false
	for ruler in _rulers.get_children():
		_rulers.remove_child(ruler)
		ruler.queue_free()
	
	emit_signal("setting_hidden_area_preview_visible", false)
	_hidden_area_placing_point2 = false
	
	_tool = new_tool

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
		
		# Now that there are no selected pieces, it's possible that the hand
		# preview shows up again - this is a workaround to prevent that.
		_piece_mouse_is_over_time = 0.0
		
		if not selected.empty():
			var old_hover_y = _hover_y_pos_base + _hover_y_pos_offset
			
			# The old hover position might be too low, and cause pieces to
			# collide into the table. We can prevent this by determining a
			# minimum y-position.
			var min_hover_y_pos = 0.0
			var min_hover_y_pos_set = false
			for piece in selected:
				var from = piece.transform.origin
				var to = Vector3(from.x, -10.0, from.z)
				
				var space_state = get_world().direct_space_state
				var result = space_state.intersect_ray(from, to, [piece])
				
				if result.has("position"):
					# Calculate the minimum y-position the piece has to be in
					# in order to not be obstructed.
					var collision_point = result["position"]
					var min_y_pos = collision_point.y + (piece.get_size().y / 2)
					
					if min_hover_y_pos_set:
						min_hover_y_pos = max(min_hover_y_pos, min_y_pos)
					else:
						min_hover_y_pos = min_y_pos
						min_hover_y_pos_set = true
			
			# Try to keep the same vertical position we had before, but if it
			# was lower than the new minimum, we need to adjust for that.
			old_hover_y = max(min_hover_y_pos, old_hover_y)
			
			_hover_y_pos_base = max(min_hover_y_pos, _hover_y_pos_base)
			_hover_y_pos_offset = old_hover_y - _hover_y_pos_base
			
			var origin_piece = selected[0]
			if _piece_mouse_is_over:
				if selected.has(_piece_mouse_is_over):
					origin_piece = _piece_mouse_is_over
			var origin = origin_piece.transform.origin
			
			# Keep the X and the Z positions of the origin piece the same to
			# start off with.
			var origin_offset = origin - get_hover_position()
			origin_offset.y = 0.0
			
			if selected.size() == 1:
				var piece = selected[0]
				
				if piece is Stack and fast:
					emit_signal("pop_stack_requested", piece, 1)
				elif piece is PieceContainer and fast:
					if piece.get_piece_count() == 0:
						emit_signal("hover_piece_requested", piece, origin_offset)
					else:
						emit_signal("container_release_random_requested", piece, 1)
				else:
					emit_signal("hover_piece_requested", piece, origin_offset)
			else:
				var offsets = []
				for piece in selected:
					var offset = piece.transform.origin - origin + origin_offset
					offsets.append(offset)
				
				emit_signal("hover_pieces_requested", selected, offsets)
		
		_is_grabbing_selected = false

# Unlock the currently selected pieces.
func _unlock_selected_pieces() -> void:
	_hide_context_menu()
	for piece in _selected_pieces:
		if piece is Piece:
			piece.rpc_id(1, "request_unlock")

# Called when the camera starts moving either positionally or rotationally.
# mouse_speed_sq: The square of the speed the mouse is moving at in pixels/sec.
# This is used to stop micro-movements of the mouse from triggering events.
func _on_moving(mouse_speed_sq: float = 0.0) -> bool:
	# If we were grabbing a piece while moving...
	if _is_grabbing_selected:
		# ... and the mouse moved at a big enough speed ...
		if mouse_speed_sq > GRABBING_FAST_MIN_MOUSE_SPEED_SQ:
			# ... then send out a signal to start hovering the piece fast.
			_start_hovering_grabbed_piece(true)
			return true
		else:
			return false
	
	# Or if we were hovering a piece already...
	if _is_hovering_selected:
		# This code may be run multiple times a frame depending on how fast the
		# user is moving the mouse, so limit ourselves to run this only once
		# per frame.
		if _moved_piece_this_frame:
			return true
		
		# Set the maximum hover y-position so the pieces don't go above and
		# behind the camera.
		var max_y_pos = _camera.global_transform.origin.y - HOVER_Y_MIN
		_hover_y_pos_base = min(_hover_y_pos_base, max_y_pos)
		
		# ... then send out a signal with the new hover position.
		if _selected_pieces.size() == 1:
			var piece = _selected_pieces[0]
			piece.rpc_unreliable_id(1, "request_set_hover_position", get_hover_position())
		elif _selected_pieces.size() > 1:
			# If we started hovering multiple pieces, the server should have
			# remembered the list of pieces we started hovering, so all we need
			# to do is send it the updated position.
			emit_signal("setting_hover_position_multiple", get_hover_position())
		
		_moved_piece_this_frame = true
		return true
	
	if _is_painting:
		_send_paint_position = true
		return true
	
	if _is_erasing:
		_send_erase_position = true
		return true
	
	return false

# Called when the player inputs a scroll event.
func _on_scroll(delta: float, ctrl: bool, alt: bool) -> void:
	if _is_hovering_selected:
		if alt:
			# Changing the rotation of the hovered pieces.
			var amount = _piece_rotation_amount * delta
			if piece_rotate_invert:
				amount *= -1
			for piece in _selected_pieces:
				piece.rpc_id(1, "request_rotate_y", amount)
		else:
			if ctrl:
				var new_y_base = _hover_y_pos_base + delta
				_hover_y_pos_base = max(new_y_base, HOVER_Y_MIN)
			else:
				_hover_y_pos_offset = _hover_y_pos_offset + delta
			
			_hover_y_pos_offset = max(_hover_y_pos_offset,
					HOVER_Y_MIN - _hover_y_pos_base)
			_on_moving()
	else:
		# Zooming the camera in and away from the controller.
		var offset = zoom_sensitivity * delta
		var new_zoom = _target_zoom + offset
		_target_zoom = max(min(new_zoom, ZOOM_DISTANCE_MAX), ZOOM_DISTANCE_MIN)
	
	get_tree().set_input_as_handled()

func _on_ApplyTransformButton_pressed():
	_hide_context_menu()
	var origin = Vector3(_transform_piece_pos_x.value,
			_transform_piece_pos_y.value, _transform_piece_pos_z.value)
	var angles = Vector3(deg2rad(_transform_piece_rot_x.value),
			deg2rad(_transform_piece_rot_y.value),
			deg2rad(_transform_piece_rot_z.value))
	var new_scale = Vector3(_transform_piece_sca_x.value,
			_transform_piece_sca_y.value, _transform_piece_sca_z.value)
	
	var new_basis = Basis(angles) * Basis.IDENTITY.scaled(new_scale)
	var new_transform = Transform(new_basis, origin)
	
	for piece in _selected_pieces:
		piece.rpc_id(1, "request_set_transform", new_transform)

func _on_BrushSizeValueSlider_value_changed(value: float):
	_brush_size_label.text = str(value)

func _on_ColorMenu_popup_hide():
	for piece in _selected_pieces:
		piece.rpc_id(1, "request_set_albedo_color", _color_picker.color, false)

func _on_ColorPicker_color_changed(color: Color):
	for piece in _selected_pieces:
		piece.rpc_unreliable_id(1, "request_set_albedo_color", color, true)

func _on_ContainerContentDialog_take_all_from(container: PieceContainer):
	_container_content_dialog.visible = false
	clear_selected_pieces()
	emit_signal("container_release_random_requested", container, container.get_piece_count())

func _on_ContainerContentDialog_take_from(container: PieceContainer, names: Array):
	_container_content_dialog.visible = false
	clear_selected_pieces()
	emit_signal("container_release_these_requested", container, names)

func _on_CursorToolButton_pressed():
	_set_tool(TOOL_CURSOR)

func _on_DealCardsSpinBoxButton_pressed(value: int):
	if _selected_pieces.empty():
		return
	
	_hide_context_menu()
	emit_signal("dealing_cards", _selected_pieces[0], value)

func _on_EraserSizeValueSlider_value_changed(value: float):
	_eraser_size_label.text = str(value)

func _on_EraseOKButton_pressed():
	_erase_tool_menu.visible = false

func _on_EraseToolButton_pressed():
	_set_tool(TOOL_ERASE)
	
	_erase_tool_menu.rect_position = get_viewport().get_mouse_position()
	_erase_tool_menu.rect_position.y -= _erase_tool_menu.rect_size.y
	_erase_tool_menu.popup()

func _on_FlickOKButton_pressed():
	_flick_tool_menu.visible = false

func _on_FlickStrengthValueSlider_value_changed(value: float):
	_flick_strength_value_label.text = "%.1f" % value

func _on_FlickToolButton_pressed():
	_set_tool(TOOL_FLICK)
	
	_flick_tool_menu.rect_position = get_viewport().get_mouse_position()
	_flick_tool_menu.rect_position.y -= _paint_tool_menu.rect_size.y
	_flick_tool_menu.popup()

func _on_HiddenAreaToolButton_pressed():
	_set_tool(TOOL_HIDDEN_AREA)

func _on_Lobby_player_added(id: int) -> void:
	if id == get_tree().get_network_unique_id():
		return
	
	if _cursors.has_node(str(id)):
		return
	
	var cursor = TextureRect.new()
	cursor.name = str(id)
	cursor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cursor.rect_scale = _get_cursor_scale()
	cursor.texture = _create_player_cursor_texture(id, false)
	
	cursor.set_meta("cursor_position", Vector3())
	cursor.set_meta("x_basis", Vector3.RIGHT)
	
	_cursors.add_child(cursor)

func _on_Lobby_player_modified(id: int, _old: Dictionary) -> void:
	if id == get_tree().get_network_unique_id():
		return
	
	if not _cursors.has_node(str(id)):
		return
	
	var cursor = _cursors.get_node(str(id))
	if not cursor:
		return
	if not cursor is TextureRect:
		return
	
	cursor.texture = _create_player_cursor_texture(id, false)

func _on_Lobby_player_removed(id: int) -> void:
	if id == get_tree().get_network_unique_id():
		return
	
	if not _cursors.has_node(str(id)):
		return
	
	var cursor = _cursors.get_node(str(id))
	if cursor:
		_cursors.remove_child(cursor)
		cursor.queue_free()

func _on_MouseGrab_gui_input(event):
	if event is InputEventMouseButton:
		var ctrl = event.command if OS.get_name() == "OSX" else event.control
		
		if event.button_index == BUTTON_LEFT:
			
			if _tool == TOOL_CURSOR:
				if event.is_pressed():
					if _piece_mouse_is_over:
						if ctrl:
							if _piece_mouse_is_over in _selected_pieces:
								erase_selected_pieces(_piece_mouse_is_over)
							else:
								append_selected_pieces([_piece_mouse_is_over])
						else:
							if not _selected_pieces.has(_piece_mouse_is_over):
								set_selected_pieces([_piece_mouse_is_over])
							_is_grabbing_selected = true
							_grabbing_time = 0.0
					else:
						if not (ctrl or _is_hovering_selected):
							clear_selected_pieces()
						
						if hold_left_click_to_move:
							# Start dragging the camera with the mouse.
							_drag_camera_anchor = _calculate_hover_position(event.position, 0.0)
							_is_dragging_camera = true
						else:
							# Start box selecting.
							_box_select_init_pos = event.position
							_is_box_selecting = true
							
							_box_selection_rect.rect_position = _box_select_init_pos
							_box_selection_rect.rect_size = Vector2()
							_box_selection_rect.visible = true
				else:
					_is_dragging_camera = false
					_is_grabbing_selected = false
					
					if _is_hovering_selected:
						var cards = []
						var adding_card_to_hand = false
						for piece in _selected_pieces:
							if piece is Card or (piece is Stack and piece.is_card_stack()):
								cards.append(piece)
								if not piece.over_hands.empty():
									adding_card_to_hand = true
							piece.rpc_id(1, "request_stop_hovering")
						
						set_is_hovering(false)
						
						if adding_card_to_hand:
							emit_signal("adding_cards_to_hand", cards, 0)
					
					# Stop box selecting.
					if _is_box_selecting:
						_box_selection_rect.visible = false
						_is_box_selecting = false
						_perform_box_select = true
			
			elif _tool == TOOL_FLICK:
				if event.is_pressed() and _piece_mouse_is_over and (not _flick_placing_point2):
					set_selected_pieces([_piece_mouse_is_over])
					
					_flick_line.visible = true
					_flick_line.point1 = _cursor_position
					_flick_piece_origin = _piece_mouse_is_over.transform.origin
					_flick_placing_point2 = true
				
				elif not event.is_pressed():
					if not _selected_pieces.empty():
						var position = _flick_line.point1 - _flick_piece_origin
						var impulse = _flick_line.point1 - _flick_line.point2
						impulse *= FLICK_MODIFIER * _flick_strength_value_slider.value
						_selected_pieces[0].rpc_id(1, "request_impulse",
								position, impulse)
					
					set_selected_pieces([])
					_flick_line.visible = false
					_flick_placing_point2 = false
			
			elif _tool == TOOL_RULER:
				if event.is_pressed() and _cursor_on_table and (not _ruler_placing_point2):
					var ruler = preload("res://Scenes/Game/UI/RulerLine.tscn").instance()
					ruler.is_metric = (_ruler_system_button.selected == 0)
					ruler.point1 = _cursor_position
					ruler.point2 = ruler.point1
					ruler.scale = _ruler_scale_spin_box.value
					_rulers.add_child(ruler)
					
					_ruler_placing_point2 = true
				
				elif not event.is_pressed():
					_ruler_placing_point2 = false
			
			elif _tool == TOOL_HIDDEN_AREA:
				if event.is_pressed() and _cursor_on_table and (not _hidden_area_placing_point2):
					_hidden_area_point1 = _cursor_position
					_hidden_area_point2 = _hidden_area_point1
					
					_hidden_area_placing_point2 = true
				
				elif not event.is_pressed():
					var point1_v2 = Vector2(_hidden_area_point1.x, _hidden_area_point1.z)
					var point2_v2 = Vector2(_hidden_area_point2.x, _hidden_area_point2.z)
					emit_signal("placing_hidden_area", point1_v2, point2_v2)
					
					_hidden_area_placing_point2 = false
				
				emit_signal("setting_hidden_area_preview_visible", _hidden_area_placing_point2)
			
			elif _tool == TOOL_PAINT:
				var was_painting = _is_painting
				_is_painting = event.is_pressed()
				if (not was_painting) and _is_painting:
					_use_last_paint_position = false
			
			elif _tool == TOOL_ERASE:
				var was_erasing = _is_erasing
				_is_erasing = event.is_pressed()
				if (not was_erasing) and _is_erasing:
					_use_last_paint_position = false
		
		elif event.button_index == BUTTON_RIGHT:
			if _is_hovering_selected:
				# TODO: Consider doing something here, like randomizing dice
				# or shuffling stacks?
				pass
			else:
				# Only bring up the context menu if the mouse didn't move
				# between the press and the release of the RMB.
				if event.is_pressed():
					_right_click_pos = event.position
					
					if _tool == TOOL_CURSOR:
						if _piece_mouse_is_over:
							if not _selected_pieces.has(_piece_mouse_is_over):
								if _piece_mouse_is_over is PieceContainer:
									append_selected_pieces([_piece_mouse_is_over])
								else:
									set_selected_pieces([_piece_mouse_is_over])
						else:
							clear_selected_pieces()
				else:
					if _tool == TOOL_CURSOR:
						if _cursor_on_table:
							if event.position == _right_click_pos:
								if _selected_pieces.empty():
									_popup_table_context_menu()
									_spawn_point_position = _cursor_position
								else:
									_popup_piece_context_menu()
					
					elif _tool == TOOL_FLICK:
						if event.position == _right_click_pos:
							set_selected_pieces([])
							_flick_placing_point2 = false
							_flick_line.visible = false
					
					elif _tool == TOOL_RULER:
						if event.position == _right_click_pos:
							var num_rulers = _rulers.get_child_count()
							if num_rulers > 0:
								var last_ruler = _rulers.get_child(num_rulers - 1)
								_rulers.remove_child(last_ruler)
								last_ruler.queue_free()
							
							_ruler_placing_point2 = false
					
					elif _tool == TOOL_HIDDEN_AREA:
						if event.position == _right_click_pos:
							if _hidden_area_mouse_is_over:
								emit_signal("removing_hidden_area", _hidden_area_mouse_is_over)
					
					elif _tool == TOOL_PAINT:
						pass
					
					elif _tool == TOOL_ERASE:
						pass
		
		elif event.is_pressed() and (event.button_index == BUTTON_WHEEL_UP or
			event.button_index == BUTTON_WHEEL_DOWN):
			
			var delta = 1.0 if event.button_index == BUTTON_WHEEL_DOWN else -1.0
			var alt = event.control if OS.get_name() == "OSX" else event.alt
			_on_scroll(delta, ctrl, alt)
	
	elif event is InputEventMouseMotion:
		# Check if by moving the mouse, we either started hovering a piece, or
		# we have moved the hovered pieces position.
		if _on_moving(event.speed.length_squared()):
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
		
		elif _is_dragging_camera:
			var new_anchor = _calculate_hover_position(event.position, 0.0)
			var diff_anchor = new_anchor - _drag_camera_anchor
			translation -= diff_anchor
		
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
	
	elif event is InputEventPanGesture:
		var ctrl = event.command if OS.get_name() == "OSX" else event.control
		var alt  = event.control if OS.get_name() == "OSX" else event.alt
		_on_scroll(event.delta.y, ctrl, alt)

func _on_PaintOKButton_pressed():
	_paint_tool_menu.visible = false

func _on_PaintToolButton_pressed():
	_set_tool(TOOL_PAINT)
	
	_paint_tool_menu.rect_position = get_viewport().get_mouse_position()
	_paint_tool_menu.rect_position.y -= _paint_tool_menu.rect_size.y
	_paint_tool_menu.popup()

func _on_PieceContextMenu_id_pressed(id: int):
	match id:
		CONTEXT_CARDS_PUT_IN_HAND:
			emit_signal("adding_cards_to_hand", _selected_pieces, get_tree().get_network_unique_id())
		
		CONTEXT_PIECE_COPY:
			_copy_selected_pieces()
		
		CONTEXT_PIECE_CUT:
			_cut_selected_pieces()
		
		CONTEXT_PIECE_DELETE:
			_delete_selected_pieces()
		
		CONTEXT_PIECE_DETAILS:
			_details_dialog.show_details(_selected_pieces)
		
		CONTEXT_PIECE_LOCK:
			_lock_selected_pieces()
		
		CONTEXT_PIECE_PASTE:
			_paste_clipboard()
		
		CONTEXT_PIECE_UNLOCK:
			_unlock_selected_pieces()
		
		CONTEXT_PIECE_CONTAINER_ADD:
			if _selected_pieces.size() == 1:
				var piece = _selected_pieces[0]
				if piece is PieceContainer:
					emit_signal("spawning_piece_in_container", piece.name)
		
		CONTEXT_PIECE_CONTAINER_ADD_SELECTED:
			if _container_multi_context == null:
				return
			
			var pieces = []
			for piece in _selected_pieces:
				if piece != _container_multi_context:
					pieces.append(piece)
			
			emit_signal("adding_pieces_to_container", _container_multi_context, pieces)
		
		CONTEXT_PIECE_CONTAINER_PEEK:
			if _selected_pieces.size() == 1:
				var piece = _selected_pieces[0]
				if piece is PieceContainer:
					_container_content_dialog.display_contents(piece)
					_container_content_dialog.popup_centered()
		
		CONTEXT_STACK_COLLECT_ALL:
			if _selected_pieces.size() == 1:
				var piece = _selected_pieces[0]
				if piece is Stack:
					emit_signal("stack_collect_all_requested", piece, true)
		
		CONTEXT_STACK_COLLECT_INDIVIDUALS:
			if _selected_pieces.size() == 1:
				var piece = _selected_pieces[0]
				if piece is Stack:
					emit_signal("stack_collect_all_requested", piece, false)
		
		CONTEXT_STACK_ORIENT_ALL_DOWN:
			for piece in _selected_pieces:
				if piece is Stack:
					piece.rpc_id(1, "request_orient_pieces", false)
		
		CONTEXT_STACK_ORIENT_ALL_UP:
			for piece in _selected_pieces:
				if piece is Stack:
					piece.rpc_id(1, "request_orient_pieces", true)
		
		CONTEXT_STACK_SHUFFLE:
			for piece in _selected_pieces:
				if piece is Stack:
					piece.rpc_id(1, "request_shuffle")
		
		CONTEXT_STACKABLE_PIECE_COLLECT_SELECTED:
			if _selected_pieces.size() > 1:
				# If a particular piece was right-clicked, add every other
				# piece onto that one by putting it at the front of the list.
				var pieces_to_collect = _selected_pieces.duplicate()
				if _stackable_piece_multi_context != null:
					pieces_to_collect.erase(_stackable_piece_multi_context)
					pieces_to_collect.push_front(_stackable_piece_multi_context)
				emit_signal("collect_pieces_requested", pieces_to_collect)
		
		0: # Labels.
			pass
		
		_:
			push_error("Invalid PieceContextMenu item id (%d)!" % id)

func _on_PieceContextMenu_popup_hide():
	# Any variables that were potentially set if the object was a timer need
	# to be reset.
	if _timer_connected:
		_timer_connected.disconnect("mode_changed", self, "_on_timer_mode_changed")
		_timer_connected.disconnect("timer_paused", self, "_on_timer_paused")
		_timer_connected.disconnect("timer_resumed", self, "_on_timer_resumed")
	_timer_connected = null
	
	# Any variables that were potentially set if the object was a speaker need
	# to be reset.
	if _speaker_connected:
		_speaker_connected.disconnect("is_positional_changed", self, "_on_speaker_is_positional_changed")
		_speaker_connected.disconnect("started_playing", self, "_on_speaker_started_playing")
		_speaker_connected.disconnect("stopped_playing", self, "_on_speaker_stopped_playing")
		_speaker_connected.disconnect("track_changed", self, "_on_speaker_track_changed")
		_speaker_connected.disconnect("track_paused", self, "_on_speaker_track_paused")
		_speaker_connected.disconnect("track_resumed", self, "_on_speaker_track_resumed")
		_speaker_connected.disconnect("unit_size_changed", self, "_on_speaker_unit_size_changed")
	_speaker_connected = null

func _on_RulerOKButton_pressed():
	_ruler_tool_menu.visible = false

func _on_RulerScaleSlider_value_changed(value: float):
	if _ruler_scale_value_changed_lock:
		return
	
	# Ensure that the slider and the spin box don't keep calling each other's
	# value_changed callbacks.
	_ruler_scale_value_changed_lock = true
	_ruler_scale_spin_box.value = value
	_ruler_scale_value_changed_lock = false

func _on_RulerScaleSpinBox_value_changed(value: float):
	if _ruler_scale_value_changed_lock:
		return
	
	_ruler_scale_value_changed_lock = true
	_ruler_scale_slider.value = value
	_ruler_scale_value_changed_lock = false

func _on_RulerToolButton_pressed():
	_set_tool(TOOL_RULER)
	
	_ruler_tool_menu.rect_position = get_viewport().get_mouse_position()
	_ruler_tool_menu.rect_position.y -= _ruler_tool_menu.rect_size.y
	_ruler_tool_menu.popup()

func _on_SetDiceValueButton_pressed():
	_hide_context_menu()
	
	if _dice_value_button.selected < 0:
		return
	
	var value_to_set = _dice_value_button.get_selected_metadata()
	var quat_result_cache: Dictionary = {}
	for piece in _selected_pieces:
		if piece is Dice:
			var face_value_dict: Dictionary = piece.piece_entry["face_values"]
			if not face_value_dict.has(value_to_set):
				continue
			
			var face_value_normal: Vector3 = face_value_dict[value_to_set][0]
			
			var rotation_quat: Quat
			if face_value_normal.is_equal_approx(Vector3.UP):
				rotation_quat = Quat.IDENTITY
			elif quat_result_cache.has(face_value_normal):
				rotation_quat = quat_result_cache[face_value_normal]
			else:
				# Come up with a basis where the y component is the normal
				# vector, invert it, and use it as a transform to get the face
				# we want to show pointed upwards.
				var offset = Vector3.UP
				if face_value_normal.abs().is_equal_approx(Vector3.UP):
					offset = Vector3.BACK
				
				var basis_x = face_value_normal.cross(face_value_normal + offset)
				var basis_z = basis_x.cross(face_value_normal)
				var inverse_basis = Basis(basis_x, face_value_normal, basis_z)
				rotation_quat = inverse_basis.get_rotation_quat().inverse()
				quat_result_cache[face_value_normal] = rotation_quat
			
			if piece.is_hovering():
				piece.rpc_id(1, "request_set_hover_rotation", rotation_quat)
			else:
				piece.rpc_id(1, "request_set_rotation_quat", rotation_quat)

func _on_SortMenu_id_pressed(id: int):
	var key = ""
	match id:
		CONTEXT_STACK_SORT_NAME:
			key = "name"
		CONTEXT_STACK_SORT_SUIT:
			key = "suit"
		CONTEXT_STACK_SORT_VALUE:
			key = "value"
	
	if not key.empty():
		for stack in _selected_pieces:
			if stack is Stack:
				stack.rpc_id(1, "request_sort", key)

func _on_SpeakerPauseButton_pressed():
	if _speaker_ignore_control_signals:
		return
	
	if _speaker_connected:
		if _speaker_connected.is_track_paused():
			_speaker_connected.rpc_id(1, "request_resume_track")
		else:
			_speaker_connected.rpc_id(1, "request_pause_track")

func _on_SpeakerPlayStopButton_pressed():
	if _speaker_ignore_control_signals:
		return
	
	if _speaker_connected:
		if _speaker_connected.is_playing_track():
			_speaker_connected.rpc_id(1, "request_stop_track")
		else:
			_speaker_connected.rpc_id(1, "request_play_track")

func _on_SpeakerPositionalButton_toggled(button_pressed: bool):
	if _speaker_ignore_control_signals:
		return
	
	if _speaker_connected:
		_speaker_connected.rpc_id(1, "request_set_positional", button_pressed)

func _on_SpeakerSelectTrackButton_pressed():
	_track_dialog.popup_centered()

func _on_SpeakerVolumeSlider_value_changed(value: float):
	if _speaker_ignore_control_signals:
		return
	
	if _speaker_connected:
		_speaker_connected.rpc_id(1, "request_set_unit_size", value)

func _on_StartStopCountdownButton_pressed():
	if _timer_connected:
		if _timer_connected.get_mode() == TimerPiece.MODE_COUNTDOWN:
			_timer_connected.rpc_id(1, "request_stop_timer")
		else:
			var time = _timer_countdown_time.get_seconds()
			_timer_connected.rpc_id(1, "request_start_countdown", time)

func _on_StartStopStopwatchButton_pressed():
	if _timer_connected:
		if _timer_connected.get_mode() == TimerPiece.MODE_STOPWATCH:
			_timer_connected.rpc_id(1, "request_stop_timer")
		else:
			_timer_connected.rpc_id(1, "request_start_stopwatch")

func _on_TableContextMenu_id_pressed(id: int):
	match id:
		CONTEXT_TABLE_PASTE:
			_paste_clipboard()
		
		CONTEXT_TABLE_SET_SPAWN_POINT:
			emit_signal("setting_spawn_point", _spawn_point_position)
		
		CONTEXT_TABLE_SPAWN_OBJECT:
			emit_signal("spawning_piece_at", _spawn_point_position)
		
		0: # Labels.
			pass
		
		_:
			push_error("Invalid TableContextMenu item id (%d)!" % id)

func _on_TakeOffTopSpinBoxButton_pressed(value: int):
	_hide_context_menu()
	if _selected_pieces.size() == 1:
		var piece = _selected_pieces[0]
		if piece is Stack:
			clear_selected_pieces()
			emit_signal("pop_stack_requested", piece, value)

func _on_TakeOutSpinBoxButton_pressed(value: int):
	_hide_context_menu()
	if _selected_pieces.size() == 1:
		var piece = _selected_pieces[0]
		if piece is PieceContainer:
			clear_selected_pieces()
			emit_signal("container_release_random_requested", piece, value)

func _on_TimerPauseButton_pressed():
	if _timer_connected:
		if _timer_connected.is_timer_paused():
			_timer_connected.rpc_id(1, "request_resume_timer")
		else:
			_timer_connected.rpc_id(1, "request_pause_timer")

func _on_TrackDialog_entry_requested(_pack: String, _type: String, entry: Dictionary):
	_track_dialog.visible = false
	if _speaker_connected:
		var entry_path: String = entry["entry_path"]
		var type_name: String = entry_path.split("/", false, 1)[1]
		var music: bool = (type_name.begins_with("music"))
		_speaker_connected.rpc_id(1, "request_set_track", entry, music)
	else:
		push_warning("Don't know which speaker to set track for, doing nothing.")

func _on_Viewport_size_changed():
	# Scale the cursors so they always appear the same size, regardless of the
	# window resolution.
	for cursor in _cursors.get_children():
		if cursor is TextureRect:
			cursor.rect_scale = _get_cursor_scale()
