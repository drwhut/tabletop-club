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

extends StackablePiece

class_name Card

remotesync func bring_back(new_transform: Transform) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	transform = new_transform
	mode = MODE_RIGID
	
	# Delete the last saved server state, otherwise the card will lerp to the
	# new position.
	_last_server_state = {}

remotesync func place_aside() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	transform.origin = Vector3(9999, 9999, 9999)
	mode = MODE_STATIC

func _ready():
	_mesh_instance = $MeshInstance
