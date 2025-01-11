# tabletop-club
# Copyright (c) 2020-2024 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2024 Tabletop Club contributors (see game/CREDITS.tres).
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

## Shows information on the screen that may be useful for debugging purposes.
##
## By default, the visibility is toggled with the F3 key, but this binding can
## be changed by the player in the options menu.


## The path to the PlayerController node.
##
## If set, information about it will be displayed.
export(NodePath) var player_controller_path: NodePath


# A reference to the PlayerController node.
var _player_controller: Node = null


onready var _debug_label: Label = $DebugLabel
onready var _process_time_label: Label = $GraphContainer/ProcessContainer/ProcessTimeLabel
onready var _physics_time_label: Label = $GraphContainer/PhysicsContainer/PhysicsTimeLabel
onready var _process_graph: PerformanceGraph = $GraphContainer/ProcessContainer/ProcessGraph
onready var _physics_graph: PerformanceGraph = $GraphContainer/PhysicsContainer/PhysicsGraph


func _ready():
	# Get the reference to the PlayerController node using the path, if it has
	# been given.
	if not player_controller_path.is_empty():
		_player_controller = get_node(player_controller_path)
	
	# Since the info starts off hidden, we don't need to re-calculate the text
	# every frame until it is shown.
	set_process(false)
	
	# Same thing for the graphs, they don't need to be recording values if they
	# are hidden.
	_set_graphs_enabled(false)


func _process(_delta: float):
	var text := ""
	
	# Game/Engine Version
	text += ProjectSettings.get_setting("application/config/name")
	if ProjectSettings.has_setting("application/config/version"):
		text += " " + ProjectSettings.get_setting("application/config/version")
	text += " (%s)\n" % ("Debug" if OS.is_debug_build() else "Release")
	
	text += "Godot %s\n" % Engine.get_version_info()["string"]
	
	# Device
	# TODO: Use VisualServer.get_video_adapter_name() once it is fixed. See:
	# https://github.com/drwhut/tabletop-club/issues/91
	# https://github.com/godotengine/godot/issues/36402
	
	# Performance
	text += "FPS: %.0f\n" % Performance.get_monitor(Performance.TIME_FPS)
	
	# Show the frame times below the performance graphs.
	_process_time_label.text = "Frame Time: %.3fms" % \
			(1000.0 * Performance.get_monitor(Performance.TIME_PROCESS))
	_physics_time_label.text = "Physics Frame Time: %.3fms" % \
			(1000.0 * Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))
	
	# Objects
	text += "Objects: %.0f\n" % Performance.get_monitor(
			Performance.OBJECT_COUNT)
	text += "Resources: %.0f\n" % Performance.get_monitor(
			Performance.OBJECT_RESOURCE_COUNT)
	text += "Nodes: %.0f\n" % Performance.get_monitor(
			Performance.OBJECT_NODE_COUNT)
	text += "Orphan Nodes: %.0f\n" % Performance.get_monitor(
			Performance.OBJECT_ORPHAN_NODE_COUNT)
	
	# Physics
	# TODO: Report Performance.PHYSICS_3D_ACTIVE_OBJECTS once we switch to using
	# GodotPhysics instead of Bullet. See:
	# https://github.com/godotengine/godot/issues/16540
	
	# Memory
	if OS.is_debug_build():
		var static_used := int(Performance.get_monitor(
				Performance.MEMORY_STATIC))
		var static_max := int(Performance.get_monitor(
				Performance.MEMORY_STATIC_MAX))
		var dynamic_used := int(Performance.get_monitor(
				Performance.MEMORY_DYNAMIC))
		var dynamic_max := int(Performance.get_monitor(
				Performance.MEMORY_DYNAMIC_MAX))
		
		text += "Static Memory: %s/%s\n" % [String.humanize_size(static_used),
				String.humanize_size(static_max)]
		text += "Dynamic Memory: %s/%s\n" % [String.humanize_size(dynamic_used),
				String.humanize_size(dynamic_max)]
	
	var video_memory := int(Performance.get_monitor(
			Performance.RENDER_VIDEO_MEM_USED))
	text += "Video Memory: %s\n" % String.humanize_size(video_memory)
	
	# Network
	var network_id := "N/A"
	if get_tree().has_network_peer():
		network_id = str(get_tree().get_network_unique_id())
	
	text += "Network ID: %s\n" % network_id
	
	# TODO: Add camera position, rotation, cursor position, what the cursor is
	# over, and if we are hovering an object.
	if _player_controller != null:
		text += "\nPlayer Controller: %s\n" % \
				("Disabled" if _player_controller.disabled else "Enabled")
		
		text += "Ignoring Key Events: %s\n" % \
				("Yes" if _player_controller.ignore_key_events else "No")
		
		var camera_controller: CameraController = \
				_player_controller.get_camera_controller()
		var camera := camera_controller.get_camera()
		var camera_pos := camera.global_translation
		var camera_rot := camera.global_rotation
		
		text += "Camera Position: (%.3f, %.3f, %.3f)\n" % [camera_pos.x,
				camera_pos.y, camera_pos.z]
		text += "Camera Rotation: (%.3f, %.3f, %.3f)\n" % [rad2deg(camera_rot.x),
				rad2deg(camera_rot.y), rad2deg(camera_rot.z)]
		
		var current_tool: PlayerTool = _player_controller.get_current_tool_node()
		if current_tool != null:
			text += "Tool: %s\n" % current_tool.name
			
			var cursor_over := "None"
			if current_tool.cursor_over_area != null:
				# TODO: Display information about the hidden area.
				pass
			elif current_tool.cursor_over_body != null:
				var body := current_tool.cursor_over_body
				if body is Piece:
					# TODO: Show the asset entry path, but only if it is not in
					# another player's hand.
					var entry_path := "???"
					
					cursor_over = "[Piece] %s (Asset: %s, Mode: %d, Selected: %s)" % [
							body.name, entry_path, body.state_mode,
							"Yes" if body.selected else "No"]
				else:
					cursor_over = "[Unknown] %s" % body.name
			
			text += "Cursor Over: %s\n" % cursor_over
			
			var cursor_position := "N/A"
			if current_tool.cursor_over_plane:
				var pos := current_tool.cursor_world_position
				cursor_position = "(%.3f, %.3f, %.3f)" % [pos.x, pos.y, pos.z]
			text += "Cursor Position: %s\n" % cursor_position
	
	# TODO: Add information specific to the current player tool.
	
	_debug_label.text = text


func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("game_toggle_debug_info"):
		visible = not visible
		set_process(visible)
		
		_process_graph.clear()
		_physics_graph.clear()
		_set_graphs_enabled(visible)
		
		get_tree().set_input_as_handled()


# Set whether the performance graphs are recording deltas or not.
func _set_graphs_enabled(enabled: bool) -> void:
	_process_graph.set_process(enabled)
	_process_graph.set_physics_process(enabled)
	
	_physics_graph.set_process(enabled)
	_physics_graph.set_physics_process(enabled)
