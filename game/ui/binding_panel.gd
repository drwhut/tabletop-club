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

extends AttentionPanel

## A panel that allows the player to change the bindings of the game's actions.
##
## NOTE: This script may be used by more than one scene, therefore it is made
## a bit more general than usual.


## Fired when the player is about to change a binding.
signal changing_binding(action, index)


# The list of [BindingButton] this panel contains.
# TODO: Make typed in 4.x
var _binding_button_list: Array = []


onready var _binding_reset_dialog := $DialogContainer/BindingResetDialog


func _ready():
	# Scan the entire scene for [BindingButton] nodes.
	var node_list: Array = get_children()
	while not node_list.empty():
		var node: Node = node_list.pop_front()
		if node is BindingButton:
			_binding_button_list.push_back(node)
			
			# Connect the pressed signal so we can let the outside world know if
			# a binding is about to be changed.
			node.connect("pressed", self, "_on_binding_button_pressed", [
					node.action, node.index])
		
		node_list.append_array(node.get_children())


## Clear all of the button's overrides. When [method update_buttons] is called
## afterwards, it is guaranteed that the buttons will represent the current
## bindings.
func clear_overrides() -> void:
	for element in _binding_button_list:
		var binding_button: BindingButton = element
		binding_button.clear_override()


## Update all of the buttons in the panel to show the current bindings.
func update_buttons() -> void:
	for element in _binding_button_list:
		var binding_button: BindingButton = element
		binding_button.update_display()


## Write all of the player's bindings to the [InputMap].
## [b]NOTE:[/b] The new bindings will be used straight away, but they will not
## be saved to the config file. For this, [method GameConfig.save_to_file] will
## need to be called afterwards.
func write_bindings() -> void:
	var binding_map := {}
	var is_for_controller := false
	var is_device_known := false
	
	for element in _binding_button_list:
		var binding_button: BindingButton = element
		
		var binding_list: Array = []
		if binding_map.has(binding_button.action):
			binding_list = binding_map[binding_button.action]
		else:
			binding_map[binding_button.action] = binding_list
		
		var binding := binding_button.get_binding()
		if binding == null:
			continue
		
		if is_device_known:
			if binding_button.controller != is_for_controller:
				push_warning("'%s' does not set bindings for the same device as others in the scene" %
						binding_button.name)
				continue
		else:
			is_for_controller = binding_button.controller
		
		# If any indicies were skipped, they should be set to null.
		if binding_list.size() < binding_button.index + 1:
			binding_list.resize(binding_button.index + 1)
		
		binding_list[binding_button.index] = binding
	
	var binding_manager := BindingManager.new()
	
	for key in binding_map:
		var action: String = key
		var binding_list: Array = binding_map[key]
		
		if is_for_controller:
			binding_manager.set_controller_bindings(action, binding_list)
		else:
			binding_manager.set_keyboard_bindings(action, binding_list)


func _on_binding_button_pressed(action: String, index: int):
	emit_signal("changing_binding", action, index)


func _on_BackButton_pressed():
	visible = false


func _on_ResetButton_pressed():
	_binding_reset_dialog.popup_centered()


func _on_BindingResetDialog_resetting_bindings():
	var binding_manager := BindingManager.new()
	
	for element in _binding_button_list:
		var binding_button: BindingButton = element
		
		var current_binding := binding_button.get_binding()
		var default_binding: InputEvent = null
		if binding_button.controller:
			default_binding = binding_manager.get_controller_binding_default(
					binding_button.action, binding_button.index)
		else:
			default_binding = binding_manager.get_keyboard_binding_default(
					binding_button.action, binding_button.index)
		
		if binding_manager.are_bindings_equal(current_binding, default_binding):
			continue
		
		emit_signal("changing_binding", binding_button.action,
				binding_button.index)
		
		if default_binding == null:
			binding_button.remove_binding()
		else:
			binding_button.set_override(default_binding)
		
		binding_button.update_display()
