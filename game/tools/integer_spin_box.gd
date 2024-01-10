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

tool
class_name IntegerSpinBox
extends HBoxContainer

## A spin box with integer values that can be used with a controller.
##
## As well as a decrement and increment button on either side of the value, the
## value can also be clicked with the mouse to turn the [Label] into a
## [LineEdit].


## Emitted when the value of the spin box has changed.
signal value_changed(new_value)


## The minimum value the spin box can hold.
export(int) var min_value := 0 setget set_min_value

## The maximum value the spin box can hold.
export(int) var max_value := 100 setget set_max_value

## How much the value increments or decrements by.
export(int) var step := 1 setget set_step

## The current value of the spin box.
export(int) var value := 0 setget set_value

## The text that is displayed before the value itself.
export(String) var prefix := "" setget set_prefix

## The text that is displayed after the value itself.
export(String) var suffix := "" setget set_suffix

## The width of the label in pixels.
export(float, 0.0, 1000.0) var label_width := 50.0 \
		setget set_label_width, get_label_width

## The width of the increment and decrement buttons in pixels.
export(float, 0.0, 1000.0) var button_width := 25.0 \
		setget set_button_width, get_button_width

## The font used for the buttons and label.
export(Font) var font_override: Font = null \
		setget set_font_override, get_font_override


# The button used to decrement the current value.
var _decrement_button: Button = null

# The button used to increment the current value.
var _increment_button: Button = null

# The label showing the current value.
var _value_label: Label = null

# The line edit where the value can be set manually.
var _value_line_edit: LineEdit = null


func _init():
	# Since the root node is just a container, have it ignore all mouse events
	# and pass them onto the buttons directly. This makes sure that only the
	# buttons are emitting the mouse_entered and mouse_exited events.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	_decrement_button = Button.new()
	_decrement_button.text = "-"
	_decrement_button.flat = false
	_decrement_button.rect_min_size = Vector2(button_width, 0.0)
	_decrement_button.connect("pressed", self, "_on_decrement_button_pressed")
	
	_decrement_button.connect("focus_entered", self, "_on_focus_entered")
	_decrement_button.connect("focus_exited", self, "_on_focus_exited")
	_decrement_button.connect("mouse_entered", self, "_on_mouse_entered")
	_decrement_button.connect("mouse_exited", self, "_on_mouse_exited")
	add_child(_decrement_button)
	
	_value_label = Label.new()
	_value_label.align = Label.ALIGN_CENTER
	_value_label.clip_text = true
	_value_label.rect_min_size = Vector2(label_width, 0.0)
	_value_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_value_label.connect("gui_input", self, "_on_value_label_gui_input")
	
	_value_label.connect("mouse_entered", self, "_on_mouse_entered")
	_value_label.connect("mouse_exited", self, "_on_mouse_exited")
	add_child(_value_label)
	
	_value_line_edit = LineEdit.new()
	_value_line_edit.visible = false
	_value_line_edit.align = LineEdit.ALIGN_CENTER
	_value_line_edit.context_menu_enabled = false
	_value_line_edit.virtual_keyboard_enabled = false
	_value_line_edit.rect_min_size = Vector2(label_width, 0.0)
	_value_line_edit.connect("text_entered", self,
			"_on_value_line_edit_text_entered")
	_value_line_edit.connect("focus_exited", self,
			"_on_value_line_edit_focus_exited")
	add_child(_value_line_edit)
	
	_increment_button = Button.new()
	_increment_button.text = "+"
	_increment_button.flat = false
	_increment_button.rect_min_size = Vector2(button_width, 0.0)
	_increment_button.connect("pressed", self, "_on_increment_button_pressed")
	
	_increment_button.connect("focus_entered", self, "_on_focus_entered")
	_increment_button.connect("focus_exited", self, "_on_focus_exited")
	_increment_button.connect("mouse_entered", self, "_on_mouse_entered")
	_increment_button.connect("mouse_exited", self, "_on_mouse_exited")
	add_child(_increment_button)
	
	if font_override != null:
		_decrement_button.add_font_override("font", font_override)
		_increment_button.add_font_override("font", font_override)
		_value_label.add_font_override("font", font_override)
		_value_line_edit.add_font_override("font", font_override)
	
	update_value_display()


## Set if the spin box should be in edit mode, that is, the [LineEdit] is
## visible rather than the [Label].
func set_edit_mode(edit_mode: bool) -> void:
	_value_label.visible = not edit_mode
	_value_line_edit.visible = edit_mode
	
	if edit_mode:
		# Grab the focus so the user can start editing the value straight away.
		_value_line_edit.grab_focus()
		
		# Select the whole number so if the user starts writing a number, they
		# effectively start from scratch.
		_value_line_edit.select()


## Update the display to show the current value.
func update_value_display() -> void:
	if _value_label == null or _value_line_edit == null:
		return
	
	_value_label.text = "%s%d%s" % [prefix, value, suffix]
	_value_line_edit.text = str(value)


func get_label_width() -> float:
	if _value_label == null:
		return 0.0
	
	return _value_label.rect_min_size.x


func get_button_width() -> float:
	if _decrement_button == null:
		return 0.0
	
	return _decrement_button.rect_min_size.x


func get_font_override() -> Font:
	if _value_label == null:
		return null
	
	if not _value_label.has_font_override("font"):
		return null
	
	return _value_label.get_font("font")


func set_min_value(new_value: int) -> void:
	min_value = new_value
	
	if min_value > max_value:
		max_value = min_value
	
	if value < min_value:
		value = min_value
		update_value_display()


func set_max_value(new_value: int) -> void:
	max_value = new_value
	
	if max_value < min_value:
		min_value = max_value
	
	if value > max_value:
		value = max_value
		update_value_display()


func set_step(new_value: int) -> void:
	if new_value > 0:
		step = new_value
	else:
		step = -new_value


func set_value(new_value: int) -> void:
	if new_value < min_value:
		value = min_value
	elif new_value > max_value:
		value = max_value
	else:
		value = new_value
	
	update_value_display()


func set_prefix(new_value: String) -> void:
	prefix = new_value
	update_value_display()


func set_suffix(new_value: String) -> void:
	suffix = new_value
	update_value_display()


func set_label_width(new_value: float) -> void:
	if _value_label == null or _value_line_edit == null:
		return
	
	_value_label.rect_min_size.x = new_value
	_value_line_edit.rect_min_size.x = new_value


func set_button_width(new_value: float) -> void:
	if _decrement_button == null or _increment_button == null:
		return
	
	_decrement_button.rect_min_size.x = new_value
	_increment_button.rect_min_size.x = new_value


func set_font_override(new_font: Font) -> void:
	if _decrement_button == null:
		return
	
	_decrement_button.add_font_override("font", new_font)
	
	if _increment_button == null:
		return
	
	_increment_button.add_font_override("font", new_font)
	
	if _value_label == null:
		return
	
	_value_label.add_font_override("font", new_font)
	
	if _value_line_edit == null:
		return
	
	_value_line_edit.add_font_override("font", new_font)


func _on_decrement_button_pressed():
	set_edit_mode(false)
	
	set_value(value - step)
	emit_signal("value_changed", value)


func _on_increment_button_pressed():
	set_edit_mode(false)
	
	set_value(value + step)
	emit_signal("value_changed", value)


func _on_value_label_gui_input(event: InputEvent):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT and (not event.pressed):
			set_edit_mode(true)


func _on_value_line_edit_text_entered(new_text: String):
	set_edit_mode(false)
	
	if new_text.is_valid_integer():
		set_value(int(new_text))
		emit_signal("value_changed", value)
	else:
		update_value_display()


func _on_value_line_edit_focus_exited():
	_on_value_line_edit_text_entered(_value_line_edit.text)


func _on_focus_entered():
	emit_signal("focus_entered")


func _on_focus_exited():
	emit_signal("focus_exited")


func _on_mouse_entered():
	emit_signal("mouse_entered")


func _on_mouse_exited():
	emit_signal("mouse_exited")
