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

extends Preview

class_name ObjectPreview

onready var _camera = $CenterContainer/ViewportContainer/Viewport/Camera
onready var _label = $LabelContainer/Label
onready var _label_container = $LabelContainer
onready var _stack_icon = $CenterContainer/ViewportContainer/StackIcon
onready var _viewport = $CenterContainer/ViewportContainer/Viewport

const LABEL_WAIT_TIME = 3.0
const LABEL_MOVE_DELAY = 0.0625
const REVOLUTIONS_PER_SECOND = 0.25
const TOOLTIP_MAX_LENGTH = 80
const TOOLTIP_MAX_LINES = 4
const X_ROTATION = PI / 4

var _piece: Piece = null

var _label_direction_moving = 1
var _label_time_since_move = 0.0
var _label_time_waiting = 0.0
var _piece_factory_order = -1
var _piece_to_add: Piece = null

# Get the name of the piece node this preview is displaying.
# Returns: The name of the piece node, an empty string if displaying nothing.
func get_piece_name() -> String:
	if _piece != null:
		return _piece.name
	
	return ""

# Set the preview to display a given piece.
# piece: The piece to display. Note that it must be an orphan node!
func set_piece(piece: Piece) -> void:
	set_piece_details(piece.piece_entry)
	set_piece_display(piece)

# Set the preview's details with a piece entry.
# piece_entry: The entry used to populate the details.
func set_piece_details(piece_entry: Dictionary) -> void:
	_entry = piece_entry
	var locale = TranslationServer.get_locale()
	
	var display_name = ""
	var name_locale = "name_%s" % locale
	if piece_entry.has(name_locale):
		display_name = piece_entry[name_locale]
	else:
		display_name = piece_entry["name"]
	
	var tooltip_text = display_name
	
	var desc_locale = "desc_%s" % locale
	if piece_entry.has(desc_locale):
		tooltip_text += "\n" + _truncate_string(piece_entry[desc_locale])
	elif not piece_entry["desc"].empty():
		tooltip_text += "\n" + _truncate_string(piece_entry["desc"])
	
	if piece_entry.has("author"):
		if not piece_entry["author"].empty():
			tooltip_text += "\n" + tr("Author: %s") % _truncate_string(piece_entry["author"])
	
	if piece_entry.has("license"):
		if not piece_entry["license"].empty():
			tooltip_text += "\n" + tr("License: %s") % _truncate_string(piece_entry["license"])
	
	if piece_entry.has("modified_by"):
		if not piece_entry["modified_by"].empty():
			tooltip_text += "\n" + tr("Modified by: %s") % _truncate_string(piece_entry["modified_by"])
	
	if piece_entry.has("url"):
		if not piece_entry["url"].empty():
			tooltip_text += "\n" + tr("URL: %s") % _truncate_string(piece_entry["url"])
	
	hint_tooltip = tooltip_text
	
	_label.text = display_name
	_label_container.scroll_horizontal_enabled = true
	_label_direction_moving = 1
	_label_time_since_move = 0.0
	_label_time_waiting = LABEL_WAIT_TIME
	
	_stack_icon.visible = piece_entry.has("entry_names")

# Set the piece to be displayed in the viewport.
# piece: The piece to display. Note that it must be an orphan node!
func set_piece_display(piece: Piece) -> void:
	if _piece_to_add != null:
		ResourceManager.queue_free_object(_piece_to_add)
	_piece_to_add = piece

func _ready():
	# We connect the signal here because we don't want the editor to connect
	# the signal when this is inside an ObjectPreviewGrid (which is an editor
	# script).
	connect("tree_exiting", self, "_on_tree_exiting")
	
	PieceFactory.connect("finished", self, "_on_PieceFactory_finished")

func _process(delta):
	# Only add a piece to the display if we're not waiting to remove a piece.
	if _piece_to_add and not VisualServer.is_connected("frame_post_draw", self, "_on_frame_post_draw"):
		# If the previous piece has been fully removed, we're safe to add the
		# next one in!
		if _piece == null:
			_piece = _piece_to_add
			_piece_to_add = null
			
			# Disable physics-related properties, there won't be any physicsing here!
			_piece.contact_monitor = false
			_piece.mode = RigidBody.MODE_STATIC
			
			_piece.transform.origin = Vector3.ZERO
			# Make sure the piece is orientated upwards.
			_piece.transform = _piece.transform.looking_at(Vector3.FORWARD, Vector3.UP)
			# Adjust the angle so we can see the top face.
			_piece.rotate_object_local(Vector3.RIGHT, X_ROTATION)
			
			_viewport.add_child(_piece)
			
			# Adjust the camera's position so it can see the entire piece.
			var scale = _piece.get_size()
			var piece_height = scale.y
			
			if _piece is Card:
				piece_height = 0
			elif _piece is Stack:
				if _piece.is_card_stack():
					piece_height = 0
			
			var piece_radius = max(scale.x, scale.z) / 2
			
			var x_cos = cos(X_ROTATION)
			var x_sin = sin(X_ROTATION)
			var display_height = 2 * piece_radius * x_sin + piece_height * x_cos
			var display_radius = piece_radius * x_cos + 0.5 * piece_height * x_sin
			
			var theta = deg2rad(_camera.fov)
			var dist = 1 + display_radius + (display_height / (2 * tan(theta / 2)))
			_camera.translation.z = dist
			
			_viewport.disable_3d = false
		
		else:
			# If there is still a piece in the viewport, start the process of
			# removing it from the viewport - this may take some time, since we
			# need to wait for a render pass before it is removed.
			_clear_gui(false)

	if _piece:
		var delta_theta = 2 * PI * REVOLUTIONS_PER_SECOND * delta
		_piece.rotate_object_local(Vector3.UP, delta_theta)
	
	if not _label.text.empty() and _label_container.scroll_horizontal_enabled:
		if _label_time_waiting > 0.0:
			_label_time_waiting = max(_label_time_waiting - delta, 0.0)
		else:
			_label_time_since_move += delta
			while _label_time_since_move > LABEL_MOVE_DELAY:
				_label_time_since_move -= LABEL_MOVE_DELAY
				
				var old_scroll = _label_container.scroll_horizontal
				_label_container.scroll_horizontal += _label_direction_moving
				if _label_container.scroll_horizontal == old_scroll:
					# The scroll has reached an endpoint.
					if _label_direction_moving == 1 and old_scroll == 0:
						_label_container.scroll_horizontal_enabled = false
					_label_direction_moving = -_label_direction_moving
					_label_time_since_move = 0.0
					_label_time_waiting = LABEL_WAIT_TIME
					break

# Called when the preview is cleared.
# details: Should the details (like the name) be cleared too?
func _clear_gui(details: bool = true) -> void:
	_viewport.disable_3d = true
	
	if details:
		hint_tooltip = ""
		_label.text = ""
		_stack_icon.visible = false
	
	# If the PieceFactory is still building a piece for this preview, we don't
	# want it to appear after we've cleared the preview, so cancel the request.
	if _piece_factory_order >= 0:
		PieceFactory.cancel(_piece_factory_order)
	_piece_factory_order = -1
	
	# We've set the viewport to disable 3D, but it won't actually take effect
	# until the end of the next render pass.
	if _piece:
		if not VisualServer.is_connected("frame_post_draw", self, "_on_frame_post_draw"):
			VisualServer.connect("frame_post_draw", self, "_on_frame_post_draw")

# Remove the piece from the scene tree.
func _remove_piece() -> void:
	# There should only ever be at most one child piece, but since we only
	# use a reference to one piece, _piece, remove all child pieces just in
	# case one escapes the _piece reference.
	for child in _viewport.get_children():
		if child is RigidBody:
			# Removing the piece from the scene tree early sometimes causes
			# errors when the _physics_process notification fires, and it is
			# still expecting the piece to be in the scene tree.
			# TODO: Maybe stop removing children from the scene tree before
			# calling queue_free() on them?
			#_viewport.remove_child(child)
			
			ResourceManager.queue_free_object(child)
	
	_piece = null

# Called when the preview entry is changed.
# piece_entry: The new entry to display. It is guaranteed to not be empty.
func _set_entry_gui(piece_entry: Dictionary) -> void:
	set_piece_details(piece_entry)
	
	# Ask the PieceFactory to build the piece for us to display in another
	# thread.
	_clear_gui(false)
	_piece_factory_order = PieceFactory.request(piece_entry)

# Called when the selected flag has been changed.
# selected: If the preview is now selected.
func _set_selected_gui(selected: bool) -> void:
	_viewport.transparent_bg = not selected

# Truncate the length of a string that is displayed to the screen.
# Returns: The truncated string.
# string: The string to truncate to a reasonable length.
func _truncate_string(string: String) -> String:
	var num_lines = 1
	var index = 0
	
	while index < string.length():
		if index >= TOOLTIP_MAX_LENGTH:
			break
		
		if string[index] == "\n":
			num_lines += 1
			if num_lines > TOOLTIP_MAX_LINES:
				break
		
		index += 1
	
	if index >= string.length():
		return string
	else:
		return string.substr(0, index) + "…"

func _on_frame_post_draw():
	_remove_piece()
	VisualServer.disconnect("frame_post_draw", self, "_on_frame_post_draw")

func _on_PieceFactory_finished(order: int, piece: Piece):
	if order == _piece_factory_order:
		set_piece_display(piece)
		PieceFactory.accept(order)
		
		_piece_factory_order = -1

func _on_tree_exiting():
	PieceFactory.disconnect("finished", self, "_on_PieceFactory_finished")
	
	if _piece_to_add != null:
		ResourceManager.free_object(_piece_to_add)
