# tabletop-club
# Copyright (c) 2020-2022 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2022 Tabletop Club contributors (see game/CREDITS.tres).
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

var _piece_to_add: Piece = null
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
	var locale = TranslationServer.get_locale()
	
	var tooltip_text = ""
	
	var desc_locale = "desc_%s" % locale
	if piece_entry.has(desc_locale):
		tooltip_text = piece_entry[desc_locale]
	elif not piece_entry["desc"].empty():
		tooltip_text = piece_entry["desc"]
	
	if piece_entry.has("author"):
		if not piece_entry["author"].empty():
			if not tooltip_text.empty():
				tooltip_text += "\n"
			tooltip_text += tr("Author: %s") % piece_entry["author"]
	
	if piece_entry.has("license"):
		if not piece_entry["license"].empty():
			if not tooltip_text.empty():
				tooltip_text += "\n"
			tooltip_text += tr("License: %s") % piece_entry["license"]
	
	if piece_entry.has("modified_by"):
		if not piece_entry["modified_by"].empty():
			if not tooltip_text.empty():
				tooltip_text += "\n"
			tooltip_text += tr("Modified by: %s") % piece_entry["modified_by"]
	
	if piece_entry.has("url"):
		if not piece_entry["url"].empty():
			if not tooltip_text.empty():
				tooltip_text += "\n"
			tooltip_text += tr("URL: %s") % piece_entry["url"]
	
	hint_tooltip = tooltip_text
	
	var name_locale = "name_%s" % locale
	if piece_entry.has(name_locale):
		_label.text = piece_entry[name_locale]
	else:
		_label.text = piece_entry["name"]
	
	# If we've just set the details of a piece, then we're bound to have our
	# display set as well, so welcome any pieces built by the
	# ObjectPreviewFactory with open arms!
	_reject_factory_output = false

# Set the piece to be displayed in the viewport.
# Returns: If the piece was accepted. If false, it should be freed!
# piece: The piece to display. Note that it must be an orphan node!
func set_piece_display(piece: Piece) -> bool:
	if _reject_factory_output:
		return false
	
	if _piece_to_add != null:
		ResourceManager.queue_free_object(_piece_to_add)
	_piece_to_add = piece
	
	return true

func _ready():
	# We connect the signal here because we don't want the editor to connect
	# the signal when this is inside an ObjectPreviewGrid (which is an editor
	# script).
	connect("tree_exiting", self, "_on_tree_exiting")

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

# Called when the preview is cleared.
# details: Should the details (like the name) be cleared too?
func _clear_gui(details: bool = true) -> void:
	_viewport.disable_3d = true
	
	if details:
		hint_tooltip = ""
		_label.text = ""
		
		# If the ObjectPreviewFactory is still building a piece for this
		# preview, we don't want it to appear after we've cleared the preview,
		# so turn it away when it does eventually come knocking on the front
		# door.
		_reject_factory_output = true
	
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
			_viewport.remove_child(child)
			ResourceManager.queue_free_object(child)
	
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

func _on_frame_post_draw():
	_remove_piece()
	VisualServer.disconnect("frame_post_draw", self, "_on_frame_post_draw")

func _on_tree_exiting():
	# Wait for the ObjectPreviewFactory's build thread to finish in the event
	# it is still building a piece for us.
	ObjectPreviewFactory.flush_queue()
	
	if _piece_to_add != null:
		_piece_to_add.queue_free()
