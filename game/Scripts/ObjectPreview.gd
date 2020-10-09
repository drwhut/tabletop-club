# open-tabletop
# Copyright (c) 2020 Benjamin 'drwhut' Beddows
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

extends Control

class_name ObjectPreview

signal clicked(preview, button_event)

onready var _camera = $CenterContainer/ViewportContainer/Viewport/Camera
onready var _label = $Label
onready var _viewport = $CenterContainer/ViewportContainer/Viewport

const REVOLUTIONS_PER_SECOND = 0.25
const X_ROTATION = PI / 4

var _last_piece_entry: Dictionary = {}
var _piece: Piece = null

# Remove the piece from the display if there is one.
func clear_piece() -> void:
	_last_piece_entry = {}
	
	if _piece:
		_viewport.remove_child(_piece)
		_piece.queue_free()
		_piece = null

# Get the piece entry this preview represents.
# Returns: The piece entry, empty if no piece has been set.
func get_piece_entry() -> Dictionary:
	return _last_piece_entry

# Does the preview appear selected?
# Returns: If the preview appears selected.
func is_selected() -> bool:
	return not _viewport.transparent_bg

# Set the preview to display the given piece.
# piece_entry: The entry of the piece to display.
func set_piece(piece_entry: Dictionary) -> void:
	_last_piece_entry = piece_entry
	
	_label.text = piece_entry["name"]
	
	if piece_entry.has("texture_paths"):
		_piece = preload("res://Pieces/Stack.tscn").instance()
	else:
		# This is a piece.
		_piece = PieceBuilder.build_piece(piece_entry)
	
	# Adjust the angle so we can see the top face.
	_piece.rotate_object_local(Vector3.RIGHT, X_ROTATION)
	
	_piece.mode = RigidBody.MODE_STATIC
	
	_viewport.add_child(_piece)
	
	if _piece is Stack:
		PieceBuilder.fill_stack(_piece, piece_entry)
	
	# Adjust the camera's position so it can see the entire piece.
	var scale = piece_entry["scale"]
	
	# This means this is a custom piece.
	if not piece_entry["scene_path"].begins_with("res://"):
		var bounding_box = Vector3()
		for child in _piece.get_children():
			if child is CollisionShape:
				var shape = child.shape
				if shape is ConvexPolygonShape:
					for point in shape.points:
						if abs(point.x) > bounding_box.x:
							bounding_box.x = abs(point.x)
						if abs(point.y) > bounding_box.y:
							bounding_box.y = abs(point.y)
						if abs(point.z) > bounding_box.z:
							bounding_box.z = abs(point.z)
		
		scale *= 2 * bounding_box
	
	var piece_height = scale.y
	
	if _piece is Card:
		piece_height = 0
	elif _piece is Stack:
		var test_piece = load(piece_entry["scene_path"]).instance()
		var is_card_stack = test_piece is Card
		test_piece.free()
		if is_card_stack:
			piece_height = 0
		else:
			piece_height *= piece_entry["texture_paths"].size()
	
	var piece_radius = max(scale.x, scale.z) / 2
	
	var x_cos = cos(X_ROTATION)
	var x_sin = sin(X_ROTATION)
	var display_height = 2 * piece_radius * x_sin + piece_height * x_cos
	var display_radius = piece_radius * x_cos + 0.5 * piece_height * x_sin
	
	var theta = deg2rad(_camera.fov)
	var dist = 1 + display_radius + (display_height / (2 * tan(theta / 2)))
	_camera.translation.z = dist

# Set the preview to appear selected.
# selected: Whether the preview should be selected.
func set_selected(selected: bool) -> void:
	_viewport.transparent_bg = not selected
	if selected:
		add_to_group("preview_selected")
	else:
		remove_from_group("preview_selected")

func _process(delta):
	if _piece:
		var delta_theta = 2 * PI * REVOLUTIONS_PER_SECOND * delta
		_piece.rotate_object_local(Vector3.UP, delta_theta)

func _on_ViewportContainer_gui_input(event):
	if event is InputEventMouseButton:
		emit_signal("clicked", self, event)
