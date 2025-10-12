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

extends Area

class_name HiddenArea

onready var _mesh_instance = $CollisionShape/MeshInstance

var player_id: int = 1

# Update the color of the hidden area to reflect the owner's color.
func update_player_color() -> void:
	var player = Lobby.get_player(player_id)
	if player.empty():
		return
	
	var material = _mesh_instance.get_surface_material(0)
	if material:
		var a = material.albedo_color.a
		material.albedo_color = player["color"]
		material.albedo_color.a = a

func _ready():
	# Each hidden area should have a different material since they will probably
	# have different albedo colours because of the players ability to pick
	# different colours.
	var material = _mesh_instance.get_surface_material(0)
	if material:
		_mesh_instance.set_surface_material(0, material.duplicate())
	
	Lobby.connect("player_modified", self, "_on_Lobby_player_modified")

func _on_HiddenArea_body_entered(body):
	if body is Piece:
		if get_tree().get_network_unique_id() != player_id:
			body.visible = false

func _on_HiddenArea_body_exited(body):
	if body is Piece:
		body.visible = true

func _on_Lobby_player_modified(id: int, _old: Dictionary):
	if id == player_id:
		update_player_color()
