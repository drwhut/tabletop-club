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

class_name BindingManager
extends Reference

## A simplified front-end for [InputMap].
##
## TODO: Test this class.


## Get all of the current bindings for the given action.
## TODO: Make typed in 4.x
func get_bindings(action: String) -> Array:
	if not InputMap.has_action(action):
		push_error("Cannot get bindings for action '%s', does not exist" % action)
		return []
	
	return InputMap.get_action_list(action)


## Get all of the default bindings for the given action.
## TODO: Make typed in 4.x
func get_bindings_default(action: String) -> Array:
	if not InputMap.has_action(action):
		push_error("Cannot get default bindings for action '%s', does not exist" % action)
		return []
	
	var setting_name := "input/%s" % action
	if not ProjectSettings.has_setting(setting_name):
		push_error("Cannot get default bindings for action '%s', '%s' does not exist in ProjectSettings" %
				[action, setting_name])
		return []
	
	var setting: Dictionary = ProjectSettings.get_setting(setting_name)
	var events: Array = setting["events"]
	return events


## Get the current keyboard binding for the given action at the given index.
func get_keyboard_binding(action: String, index: int) -> InputEvent:
	var bindings := get_bindings(action)
	return _get_binding_at_index(bindings, index, false)


## Get the default keyboard binding for the given action at the given index.
func get_keyboard_binding_default(action: String, index: int) -> InputEvent:
	var bindings := get_bindings_default(action)
	return _get_binding_at_index(bindings, index, false)


## Get the current controller binding for the given action at the given index.
func get_controller_binding(action: String, index: int) -> InputEvent:
	var bindings := get_bindings(action)
	return _get_binding_at_index(bindings, index, true)


## Get the default controller binding for the given action at the given index.
func get_controller_binding_default(action: String, index: int) -> InputEvent:
	var bindings := get_bindings_default(action)
	return _get_binding_at_index(bindings, index, true)


## Set the new keyboard bindings for the given action.
## TODO: Make array typed in 4.x
func set_keyboard_bindings(action: String, bindings: Array) -> void:
	_set_bindings_for_device(action, bindings, false)


## Set the new controller bindings for the given action.
## TODO: Make array typed for 4.x
func set_controller_bindings(action: String, bindings: Array) -> void:
	_set_bindings_for_device(action, bindings, true)


## Check if two bindings are equal to one another - this can be used to check
## if the current binding is the same as the default binding.
## NOTE: Modifiers like Alt and Shift are NOT taken into account.
func are_bindings_equal(binding_1: InputEvent, binding_2: InputEvent) -> bool:
	if binding_1 is InputEventKey:
		if binding_2 is InputEventKey:
			return binding_1.scancode == binding_2.scancode
	
	if binding_1 is InputEventMouseButton:
		if binding_2 is InputEventMouseButton:
			return binding_1.button_index == binding_2.button_index
	
	if binding_1 is InputEventJoypadButton:
		if binding_2 is InputEventJoypadButton:
			return binding_1.button_index == binding_2.button_index
	
	return false


## Reset all of the current bindings to their default state.
func reset_all() -> void:
	InputMap.load_from_globals()


# Of all of the bindings given, taking into account only the controller or the
# keyboard bindings, return the one at the given index. If a binding does not
# exist at the given index, [code]null[/code] is returned instead.
# TODO: Make array typed in 4.x
func _get_binding_at_index(bindings: Array, index: int, controller: bool) -> InputEvent:
	if index < 0:
		return null
	
	var device_index := 0
	for element in bindings:
		var binding: InputEvent = element
		
		# TODO: Use this style of if-statement everywhere else in the code.
		if (
			(controller and binding is InputEventJoypadButton) or
			((not controller) and (
				binding is InputEventKey or
				binding is InputEventMouseButton
			))
		):
			if device_index == index:
				return binding
			
			device_index += 1
	
	return null


# Set all of either the controller or keyboard bindings for the given action.
# TODO: Make array typed for 4.x
func _set_bindings_for_device(action: String, events: Array, controller: bool) -> void:
	if not InputMap.has_action(action):
		push_error("Cannot set bindings for action '%s', does not exist" % action)
		return
	
	var new_bindings := events.duplicate()
	for element in get_bindings(action):
		var event: InputEvent = element
		var keep := false
		
		if controller:
			keep = not (event is InputEventJoypadButton)
		else:
			keep = not (event is InputEventKey or event is InputEventMouseButton)
		
		if keep:
			new_bindings.push_back(event)
	
	InputMap.action_erase_events(action)
	for event in new_bindings:
		InputMap.action_add_event(action, event)
