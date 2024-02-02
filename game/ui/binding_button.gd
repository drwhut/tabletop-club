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

# If set, any binding that was shown previously (either from the InputMap or
# from the override) will be removed.
var _remove_override := false

# The timer that starts when the user wishes to remove the binding.
var _unbind_timer := Timer.new()


func _ready():
	# When the button is pressed, we want to keep it pressed for as long as the
	# player hasn't assigned a new button.
	toggle_mode = true
	
	connect("toggled", self, "_on_toggled")
	
	_unbind_timer.wait_time = 1.0
	_unbind_timer.one_shot = true
	_unbind_timer.autostart = false
	
	_unbind_timer.connect("timeout", self, "_on_unbind_timer_timeout")
	add_child(_unbind_timer)


func _input(event: InputEvent):
	if not pressed:
		return
	
	if event.is_echo():
		return
	
	if event.is_action("ui_cancel"):
		if event.is_pressed():
			# If Esc was just pressed, we don't want to immediately bind it.
			# Instead, we want to see how long it takes for the user to release
			# the button. If they wait long enough, we'll clear the binding.
			_unbind_timer.start()
			
			get_tree().set_input_as_handled()
			return
		else:
			# However, if they release it early enough, stop the timer and treat
			# it like any other button press.
			_unbind_timer.stop()
	
	# Only check press events, as that is typically what panels and dialogs are
	# checking for also.
	elif not event.is_pressed():
		return
	
	var is_valid := false
	
	if event is InputEventKey:
		is_valid = not controller
	elif event is InputEventMouseButton:
		is_valid = not controller
	elif event is InputEventJoypadButton:
		is_valid = controller
	else:
		return
	
	if is_valid:
		_binding_override = event
		_remove_override = false
		print("BindingButton: New binding assigned for action '%s/%d': %s" % [
				action, index, str(event)])
	
	update_display()
	pressed = false
	
	get_tree().set_input_as_handled()


## Get the current binding for the given action and index. If the binding has
## been overridden by the player, the override is returned instead.
func get_binding() -> InputEvent:
	if _remove_override:
		return null
	
	if _binding_override != null:
		return _binding_override
	
	var binding_manager := BindingManager.new()
	
	if controller:
		return binding_manager.get_controller_binding(action, index)
	else:
		return binding_manager.get_keyboard_binding(action, index)


## Remove the binding for the given action and index. The binding will be
## removed even if it was overridden with [method set_override]. When
## [method update_display] is called afterwards, the button will display "Not
## Bound".
func remove_binding() -> void:
	_remove_override = true


## Get the current binding override for the given action and index. If it has
## not been overridden by the player yet, [code]null[/code] is returned.
func get_override() -> InputEvent:
	return _binding_override


## Clear the current binding override. When [method update_display] is called
## afterwards, the button will display the current binding for the given action
## and index.
func clear_override() -> void:
	_binding_override = null
	_remove_override = false


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
	_remove_override = false


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


func _on_unbind_timer_timeout():
	if not pressed:
		return
	
	# The user has held down the ESC key for long enough that we'll clear the
	# button's binding.
	_remove_override = true
	print("BindingButton: Cleared binding for action '%s/%d'" % [action, index])
	
	update_display()
	pressed = false
