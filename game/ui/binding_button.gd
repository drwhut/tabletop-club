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

class_name BindingButton
extends Button

## A button that displays which button is bound to a specific action.
##
## When the button is clicked, the user is given the opportunity to select a new
## binding for the button's action.


## The action that this button sets a binding for.
export(String) var action := ""

## The index of the binding that this button sets.
export(int, 0, 5) var index := 0

## If [code]true[/code], this button only accepts controller bindings. Otherwise
## this button will only accept keyboard and mouse bindings.
export(bool) var controller := false


# If set, this will be the new binding for the given action.
var _binding_override: InputEvent = null


func _ready():
	# When the button is pressed, we want to keep it pressed for as long as the
	# player hasn't assigned a new button.
	toggle_mode = true
	
	connect("toggled", self, "_on_toggled")


func _input(event: InputEvent):
	if not pressed:
		return
	
	# Only accept press events, as we want to try and catch the ESC key being
	# pressed before the binding panel closes.
	if not event.is_pressed():
		return
	
	var is_valid := false
	if controller:
		is_valid = (event is InputEventJoypadButton)
	else:
		is_valid = (event is InputEventKey or event is InputEventMouseButton)
	
	if not is_valid:
		return
	
	# We have a valid binding, assign it and update the display.
	_binding_override = event
	print("BindingButton: New binding assigned for action '%s/%d': %s" % [
			action, index, str(event)])
	
	update_display()
	pressed = false
	
	get_tree().set_input_as_handled()


## Get the current binding for the given action and index. If the binding has
## been overridden by the player, the override is returned instead.
func get_binding() -> InputEvent:
	if _binding_override != null:
		return _binding_override
	
	var binding_manager := BindingManager.new()
	
	if controller:
		return binding_manager.get_controller_binding(action, index)
	else:
		return binding_manager.get_keyboard_binding(action, index)


## Get the current binding override for the given action and index. If it has
## not been overridden by the player yet, [code]null[/code] is returned.
func get_override() -> InputEvent:
	return _binding_override


## Clear the current binding override. When [method update_display] is called
## afterwards, the button will display the current binding for the given action
## and index.
func clear_override() -> void:
	_binding_override = null


## Set the current binding override. When [method update_display] is called
## afterwrds, the button will display the override.
## [b]NOTE:[/b] You cannot set a keyboard event as the override for a controller
## button, and vice versa. You also cannot use [code]null[/code] as an argument.
## If you wish to clear the override, use [method clear_override].
func set_override(override: InputEvent) -> void:
	if controller:
		if not override is InputEventJoypadButton:
			push_error("Cannot set '%s' as override for controller button '%s'" % [
					str(override), name])
			return
	else:
		if not (override is InputEventKey or override is InputEventMouseButton):
			push_error("Cannot set '%s' as override for keyboard button '%s'" % [
					str(override), name])
			return
	
	_binding_override = override


## Update the display of the button to match the action's current binding. If
## it has been overridden by the player, the new binding is displayed instead.
func update_display() -> void:
	if not InputMap.has_action(action):
		push_error("Cannot display binding for action '%s', does not exist" % action)
		return
	
	var binding := get_binding()
	
	if binding == null:
		text = tr("Not Bound")
	
	elif binding is InputEventKey:
		text = OS.get_scancode_string(binding.scancode)
	
	elif binding is InputEventMouseButton:
		match binding.button_index:
			BUTTON_LEFT:
				text = tr("Left Mouse Button")
			BUTTON_RIGHT:
				text = tr("Right Mouse Button")
			BUTTON_MIDDLE:
				text = tr("Middle Mouse Button")
			BUTTON_XBUTTON1:
				text = tr("Extra Mouse Button 1")
			BUTTON_XBUTTON2:
				text = tr("Extra Mouse Button 2")
			BUTTON_WHEEL_UP:
				text = tr("Mouse Wheel Up")
			BUTTON_WHEEL_DOWN:
				text = tr("Mouse Wheel Down")
			BUTTON_WHEEL_LEFT:
				text = tr("Mouse Wheel Left")
			BUTTON_WHEEL_RIGHT:
				text = tr("Mouse Wheel Right")
			_:
				text = tr("Unknown Mouse Button")
	
	# TODO: Display icons for controller buttons, depending on the controller
	# being used.
	
	else:
		text = tr("Unknown")


func _on_toggled(pressed: bool):
	if not pressed:
		return
	
	text = tr("Press any key…")
