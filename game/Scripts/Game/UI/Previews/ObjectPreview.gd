# tabletop-club
# Copyright (c) 2020-2021 Benjamin 'drwhut' Beddows
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
onready var _label = $Label
onready var _viewport = $CenterContainer/ViewportContainer/Viewport

const REVOLUTIONS_PER_SECOND = 0.25
const X_ROTATION = PI / 4

var _piece: Piece = null

var _reject_factory_output = false

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
	
	if piece_entry["description"].empty():
		hint_tooltip = ""
	else:
		hint_tooltip = piece_entry["description"]
	_label.text = piece_entry["name"]
	
	# If we've just set the details of a piece, then we're bound to have our
	# display set as well, so welcome any pieces built by the
	# ObjectPreviewFactory with open arms!
	_reject_factory_output = false

# Set the piece to be displayed in the viewport.
# piece: The piece to display. Note that it must be an orphan node!
func set_piece_display(piece: Piece) -> void:
	if _reject_factory_output:
		return
	
	# Make sure that if we are already displaying a piece, we free it before
	# we lose it!
	_clear_gui(false)
	_piece = piece
	
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

func _ready():
	# We connect the signal here because we don't want the editor to connect
	# the signal when this is inside an ObjectPreviewGrid (which is an editor
	# script).
	connect("tree_exiting", self, "_on_tree_exiting")

func _process(delta):
	if _piece:
		var delta_theta = 2 * PI * REVOLUTIONS_PER_SECOND * delta
		_piece.rotate_object_local(Vector3.UP, delta_theta)

# Called when the preview is cleared.
# details: Should the details (like the name) be cleared too?
func _clear_gui(details: bool = true) -> void:
	if details:
		hint_tooltip = ""
		_label.text = ""
		
		# If the ObjectPreviewFactory is still building a piece for this
		# preview, we don't want it to appear after we've cleared the preview,
		# so turn it away when it does eventually come knocking on the front
		# door.
		_reject_factory_output = true
	
	if _piece:
		_viewport.remove_child(_piece)
		
		# Ask the ObjectPreviewFactory to free the piece, as it could have come
		# from there. If it didn't, that doesn't matter, it does the same thing
		# anyway.
		ObjectPreviewFactory.free_piece(_piece)
		
		_piece = null

# Called when the preview entry is changed.
# piece_entry: The new entry to display. It is guaranteed to not be empty.
func _set_entry_gui(piece_entry: Dictionary) -> void:
	set_piece_details(piece_entry)
	
	# Ask the ObjectPreviewFactory to build the piece for us to display in
	# another thread.
	_clear_gui(false)
	ObjectPreviewFactory.add_to_queue(self, piece_entry)

# Called when the selected flag has been changed.
# selected: If the preview is now selected.
func _set_selected_gui(selected: bool) -> void:
	_viewport.transparent_bg = not selected

func _on_tree_exiting():
	# Wait for the ObjectPreviewFactory's build thread to finish in the event
	# it is still building a piece for us.
	ObjectPreviewFactory.flush_queue()
