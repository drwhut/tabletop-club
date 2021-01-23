# open-tabletop
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

extends Node

enum {
	MODE_NONE,
	MODE_ERROR,
	MODE_CLIENT,
	MODE_SERVER,
	MODE_SINGLEPLAYER
}

var _current_scene: Node = null

# Restart the game.
func restart_game() -> void:
	call_deferred("_terminate_peer")
	call_deferred("_goto_scene", ProjectSettings.get_setting("application/run/main_scene"), {
		"mode": MODE_NONE
	})

# Start the game as a client.
# server: The server to connect to.
# port: The port to connect to.
func start_game_as_client(server: String, port: int) -> void:
	call_deferred("_goto_scene", "res://Scenes/Game.tscn", {
		"mode": MODE_CLIENT,
		"server": server,
		"port": port
	})

# Start the game as a server.
# max_players: The maximum number of allowed players.
# port: The port to host the server on.
func start_game_as_server(max_players: int, port: int) -> void:
	call_deferred("_goto_scene", "res://Scenes/Game.tscn", {
		"mode": MODE_SERVER,
		"max_players": max_players,
		"port": port
	})

# Start the game in singleplayer mode.
func start_game_singleplayer() -> void:
	call_deferred("_goto_scene", "res://Scenes/Game.tscn", {
		"mode": MODE_SINGLEPLAYER
	})

# Start the main menu.
func start_main_menu() -> void:
	call_deferred("_terminate_peer")
	call_deferred("_goto_scene", "res://Scenes/MainMenu.tscn", {
		"mode": MODE_NONE
	})

# Start the main menu, and display an error message.
# error: The error message to display.
func start_main_menu_with_error(error: String) -> void:
	call_deferred("_terminate_peer")
	call_deferred("_goto_scene", "res://Scenes/MainMenu.tscn", {
		"mode": MODE_ERROR,
		"error": error
	})

func _ready():
	var root = get_tree().get_root()
	_current_scene = root.get_child(root.get_child_count() - 1)

# Go to a given scene, with a set of arguments.
# path: The file path of the scene to load.
# args: The arguments for the scene to use after it has loaded.
func _goto_scene(path: String, args: Dictionary) -> void:
	if not args.has("mode"):
		push_error("Scene argument 'mode' is missing!")
		return
	
	if not args["mode"] is int:
		push_error("Scene argument 'mode' is not an integer!")
		return
	
	match args["mode"]:
		MODE_NONE:
			pass
		
		MODE_ERROR:
			if not args.has("error"):
				push_error("Scene argument 'error' is missing!")
				return
			
			if not args["error"] is String:
				push_error("Scene argument 'error' is not a string!")
				return
		
		MODE_CLIENT:
			if not args.has("server"):
				push_error("Scene argument 'server' is missing!")
				return
			
			if not args["server"] is String:
				push_error("Scene argument 'server' is not a string!")
				return
			
			if not args.has("port"):
				push_error("Scene argument 'port' is missing!")
				return
			
			if not args["port"] is int:
				push_error("Scene argument 'port' is not an integer!")
				return
		
		MODE_SERVER:
			if not args.has("max_players"):
				push_error("Scene argument 'max_players' is missing!")
				return
			
			if not args["max_players"] is int:
				push_error("Scene argument 'max_players' is not an integer!")
				return
			
			if not args.has("port"):
				push_error("Scene argument 'port' is missing!")
				return
			
			if not args["port"] is int:
				push_error("Scene argument 'port' is not an integer!")
				return
		
		MODE_SINGLEPLAYER:
			pass
		
		_:
			push_error("Invalid mode " + str(args["mode"]) + "!")
			return
	
	# Since this function should be called via call_deferred, it should be safe
	# to free the current scene now.
	var root = get_tree().get_root()
	root.remove_child(_current_scene)
	_current_scene.free()
	
	_current_scene = load(path).instance()
	
	root.add_child(_current_scene)
	get_tree().set_current_scene(_current_scene)
	
	match args["mode"]:
		MODE_ERROR:
			_current_scene.display_error(args["error"])
		MODE_CLIENT:
			_current_scene.init_client(args["server"], args["port"])
		MODE_SERVER:
			_current_scene.init_server(args["max_players"], args["port"])
		MODE_SINGLEPLAYER:
			_current_scene.init_singleplayer()

# Terminate the network peer if it exists.
func _terminate_peer() -> void:
	# TODO: Send a message to say we are leaving first.
	get_tree().network_peer = null
