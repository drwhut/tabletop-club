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

extends Stack

class_name ShuffleableStack

func add_context_to_control(control: Control) -> void:
	var shuffle_button = Button.new()
	shuffle_button.text = "Shuffle"
	shuffle_button.connect("pressed", self, "_on_shuffle_pressed")
	control.add_child(shuffle_button)
	
	.add_context_to_control(control)

master func request_shuffle() -> void:
	var names = []
	
	for piece in _pieces.get_children():
		names.push_back(piece.name)
	
	randomize()
	names.shuffle()
	
	rpc("set_piece_order", names)

remotesync func set_piece_order(order: Array) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var i = 0
	for piece_name in order:
		var node = _pieces.get_node(piece_name)
		
		if node:
			_pieces.move_child(node, i)
		
		i += 1
	
	_set_piece_heights()

func _physics_process(delta):
	
	# If the stack is being shaken, then get the server to send a list of
	# shuffled names to each client (including itself).
	if get_tree().is_network_server() and is_being_shaked():
		request_shuffle()

func _on_shuffle_pressed() -> void:
	rpc_id(1, "request_shuffle")
