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
class_name ColorSlider
extends VBoxContainer

## A series of sliders used to select a colour.


## Emitted when one of the sliders is starting to be dragged.
signal drag_started()

## Emitted when the slider that was being dragged has stopped being dragged.
signal drag_ended()

## Emitted when the colour has been changed by the sliders.
signal color_changed(new_color)


## The colour currently being represented by the sliders.
export(Color) var color := Color.black setget set_color

## If [code]true[/code], the HSV sliders are visible, RGB otherwise.
export(bool) var hsv_mode := true setget set_hsv_mode


# In the event the saturation becomes 0.0, this variable will save the hue just
# before it is reset.
var _saved_hue := 1.0

# In the event the value becomes 0.0, this variable will save the saturation
# just before it is reset.
var _saved_saturation := 1.0


# The button used to enter HSV mode.
var _hsv_button: Button = null

# The button used to enter RGB mode.
var _rgb_button: Button = null

# The background of the hue slider.
var _hue_background: TextureRect = null

# The slider used to set the hue.
var _hue_slider: HSlider = null

# The background of the saturation slider.
var _saturation_background: TextureRect = null

# The rectangle multiplied with the saturation background to make it so the
# right-hand side of the bar is the currently selected hue.
var _saturation_hue_rect: ColorRect = null

# The texture added with the saturation background to make it so the left-hand
# side of the bar is pure white.
var _saturation_white_rect: TextureRect = null

# The slider used to set the saturation.
var _saturation_slider: HSlider = null

# The background of the value slider.
var _value_background: TextureRect = null

# The rectangle multiplued with the value background to make it so the
# right-hand side of the bar is the currently selected hue and saturation.
var _value_cumulative_rect: ColorRect = null

# The slider used to set the value.
var _value_slider: HSlider = null

# The background of the red slider.
var _red_background: TextureRect = null

# The slider used to set the red value.
var _red_slider: HSlider = null

# The background of the green slider.
var _green_background: TextureRect = null

# The slider used to set the green value.
var _green_slider: HSlider = null

# The background of the blue slider.
var _blue_background: TextureRect = null

# The slider used to set the blue value.
var _blue_slider: HSlider = null

# The rectangle showing the current colour.
var _color_rect: ColorRect = null

# The label showing details about the current color.
var _color_label: Label = null


func _init():
	# Since the root node is just a container, have it ignore all mouse events
	# and pass them onto the sliders directly. This makes sure that only the
	# sliders are emitting the mouse_entered and mouse_exited events.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	var grabber_normal := preload("grabber.svg")
	var grabber_highlight := preload("grabber_highlight.svg")
	
	var button_container := HBoxContainer.new()
	button_container.alignment = BoxContainer.ALIGN_END
	add_child(button_container)
	
	var button_group := ButtonGroup.new()
	
	_hsv_button = Button.new()
	_hsv_button.text = tr("HSV")
	_hsv_button.toggle_mode = true
	_hsv_button.pressed = true
	_hsv_button.group = button_group
	_hsv_button.connect("pressed", self, "_on_hsv_button_pressed")
	button_container.add_child(_hsv_button)
	
	_rgb_button = Button.new()
	_rgb_button.text = tr("RGB")
	_rgb_button.toggle_mode = true
	_rgb_button.group = button_group
	_rgb_button.connect("pressed", self, "_on_rgb_button_pressed")
	button_container.add_child(_rgb_button)
	
	_hue_background = TextureRect.new()
	_hue_background.texture = preload("slider_h.png")
	_hue_background.expand = true
	_hue_background.rect_min_size = Vector2(0.0, 24.0)
	_hue_background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_hue_background)
	
	_hue_slider = HSlider.new()
	_hue_slider.min_value = 0.0
	_hue_slider.max_value = 1.0
	_hue_slider.step = 1.0 / 360
	
	_hue_slider.anchor_left = 0.0
	_hue_slider.anchor_top = 0.0
	_hue_slider.anchor_right = 1.0
	_hue_slider.anchor_bottom = 1.0
	
	_hue_slider.add_icon_override("grabber", grabber_normal)
	_hue_slider.add_icon_override("grabber_disabled", grabber_normal)
	_hue_slider.add_icon_override("grabber_highlight", grabber_highlight)
	_hue_slider.add_stylebox_override("slider", StyleBoxEmpty.new())
	
	_hue_slider.connect("drag_started", self, "_on_drag_started")
	_hue_slider.connect("drag_ended", self, "_on_drag_ended")
	_hue_slider.connect("value_changed", self, "_on_hue_slider_value_changed")
	_hue_slider.connect("focus_entered", self, "_on_focus_entered")
	_hue_slider.connect("focus_exited", self, "_on_focus_exited")
	_hue_slider.connect("mouse_entered", self, "_on_mouse_entered")
	_hue_slider.connect("mouse_exited", self, "_on_mouse_exited")
	_hue_background.add_child(_hue_slider)
	
	_saturation_background = TextureRect.new()
	_saturation_background.texture = preload("slider_v.png")
	_saturation_background.expand = true
	_saturation_background.rect_min_size = Vector2(0.0, 24.0)
	_saturation_background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_saturation_background)
	
	_saturation_hue_rect = ColorRect.new()
	var saturation_hue_material := CanvasItemMaterial.new()
	saturation_hue_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_saturation_hue_rect.material = saturation_hue_material
	
	_saturation_hue_rect.anchor_left = 0.0
	_saturation_hue_rect.anchor_top = 0.0
	_saturation_hue_rect.anchor_right = 1.0
	_saturation_hue_rect.anchor_bottom = 1.0
	_saturation_background.add_child(_saturation_hue_rect)
	
	_saturation_white_rect = TextureRect.new()
	_saturation_white_rect.texture = preload("slider_v.png")
	_saturation_white_rect.expand = true
	_saturation_white_rect.flip_h = true
	
	var saturation_white_material := CanvasItemMaterial.new()
	saturation_white_material.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_saturation_white_rect.material = saturation_white_material
	
	_saturation_white_rect.anchor_left = 0.0
	_saturation_white_rect.anchor_top = 0.0
	_saturation_white_rect.anchor_right = 1.0
	_saturation_white_rect.anchor_bottom = 1.0
	_saturation_background.add_child(_saturation_white_rect)
	
	_saturation_slider = HSlider.new()
	_saturation_slider.min_value = 0.0
	_saturation_slider.max_value = 1.0
	_saturation_slider.step = 1.0 / 100
	
	_saturation_slider.anchor_left = 0.0
	_saturation_slider.anchor_top = 0.0
	_saturation_slider.anchor_right = 1.0
	_saturation_slider.anchor_bottom = 1.0
	
	_saturation_slider.add_icon_override("grabber", grabber_normal)
	_saturation_slider.add_icon_override("grabber_disabled", grabber_normal)
	_saturation_slider.add_icon_override("grabber_highlight", grabber_highlight)
	_saturation_slider.add_stylebox_override("slider", StyleBoxEmpty.new())
	
	_saturation_slider.connect("drag_started", self, "_on_drag_started")
	_saturation_slider.connect("drag_ended", self, "_on_drag_ended")
	_saturation_slider.connect("value_changed", self,
			"_on_saturation_slider_value_changed")
	_saturation_slider.connect("focus_entered", self, "_on_focus_entered")
	_saturation_slider.connect("focus_exited", self, "_on_focus_exited")
	_saturation_slider.connect("mouse_entered", self, "_on_mouse_entered")
	_saturation_slider.connect("mouse_exited", self, "_on_mouse_exited")
	_saturation_background.add_child(_saturation_slider)
	
	_value_background = TextureRect.new()
	_value_background.texture = preload("slider_v.png")
	_value_background.expand = true
	_value_background.rect_min_size = Vector2(0.0, 24.0)
	_value_background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_value_background)
	
	_value_cumulative_rect = ColorRect.new()
	var value_cumulative_material := CanvasItemMaterial.new()
	value_cumulative_material.blend_mode = CanvasItemMaterial.BLEND_MODE_MUL
	_value_cumulative_rect.material = value_cumulative_material
	
	_value_cumulative_rect.anchor_left = 0.0
	_value_cumulative_rect.anchor_top = 0.0
	_value_cumulative_rect.anchor_right = 1.0
	_value_cumulative_rect.anchor_bottom = 1.0
	_value_background.add_child(_value_cumulative_rect)
	
	_value_slider = HSlider.new()
	_value_slider.min_value = 0.0
	_value_slider.max_value = 1.0
	_value_slider.step = 1.0 / 100
	
	_value_slider.anchor_left = 0.0
	_value_slider.anchor_top = 0.0
	_value_slider.anchor_right = 1.0
	_value_slider.anchor_bottom = 1.0
	
	_value_slider.add_icon_override("grabber", grabber_normal)
	_value_slider.add_icon_override("grabber_disabled", grabber_normal)
	_value_slider.add_icon_override("grabber_highlight", grabber_highlight)
	_value_slider.add_stylebox_override("slider", StyleBoxEmpty.new())
	
	_value_slider.connect("drag_started", self, "_on_drag_started")
	_value_slider.connect("drag_ended", self, "_on_drag_ended")
	_value_slider.connect("value_changed", self, "_on_value_slider_value_changed")
	_value_slider.connect("focus_entered", self, "_on_focus_entered")
	_value_slider.connect("focus_exited", self, "_on_focus_exited")
	_value_slider.connect("mouse_entered", self, "_on_mouse_entered")
	_value_slider.connect("mouse_exited", self, "_on_mouse_exited")
	_value_background.add_child(_value_slider)
	
	_red_background = TextureRect.new()
	_red_background.texture = preload("slider_r.png")
	_red_background.expand = true
	_red_background.rect_min_size = Vector2(0.0, 24.0)
	_red_background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_red_background)
	
	_red_slider = HSlider.new()
	_red_slider.min_value = 0.0
	_red_slider.max_value = 1.0
	_red_slider.step = 1.0 / 256
	
	_red_slider.anchor_left = 0.0
	_red_slider.anchor_top = 0.0
	_red_slider.anchor_right = 1.0
	_red_slider.anchor_bottom = 1.0
	
	_red_slider.add_icon_override("grabber", grabber_normal)
	_red_slider.add_icon_override("grabber_disabled", grabber_normal)
	_red_slider.add_icon_override("grabber_highlight", grabber_highlight)
	_red_slider.add_stylebox_override("slider", StyleBoxEmpty.new())
	
	_red_slider.connect("drag_started", self, "_on_drag_started")
	_red_slider.connect("drag_ended", self, "_on_drag_ended")
	_red_slider.connect("value_changed", self, "_on_red_slider_value_changed")
	_red_slider.connect("focus_entered", self, "_on_focus_entered")
	_red_slider.connect("focus_exited", self, "_on_focus_exited")
	_red_slider.connect("mouse_entered", self, "_on_mouse_entered")
	_red_slider.connect("mouse_exited", self, "_on_mouse_exited")
	_red_background.add_child(_red_slider)
	
	_green_background = TextureRect.new()
	_green_background.texture = preload("slider_g.png")
	_green_background.expand = true
	_green_background.rect_min_size = Vector2(0.0, 24.0)
	_green_background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_green_background)
	
	_green_slider = HSlider.new()
	_green_slider.min_value = 0.0
	_green_slider.max_value = 1.0
	_green_slider.step = 1.0 / 256
	
	_green_slider.anchor_left = 0.0
	_green_slider.anchor_top = 0.0
	_green_slider.anchor_right = 1.0
	_green_slider.anchor_bottom = 1.0
	
	_green_slider.add_icon_override("grabber", grabber_normal)
	_green_slider.add_icon_override("grabber_disabled", grabber_normal)
	_green_slider.add_icon_override("grabber_highlight", grabber_highlight)
	_green_slider.add_stylebox_override("slider", StyleBoxEmpty.new())
	
	_green_slider.connect("drag_started", self, "_on_drag_started")
	_green_slider.connect("drag_ended", self, "_on_drag_ended")
	_green_slider.connect("value_changed", self, "_on_green_slider_value_changed")
	_green_slider.connect("focus_entered", self, "_on_focus_entered")
	_green_slider.connect("focus_exited", self, "_on_focus_exited")
	_green_slider.connect("mouse_entered", self, "_on_mouse_entered")
	_green_slider.connect("mouse_exited", self, "_on_mouse_exited")
	_green_background.add_child(_green_slider)
	
	_blue_background = TextureRect.new()
	_blue_background.texture = preload("slider_b.png")
	_blue_background.expand = true
	_blue_background.rect_min_size = Vector2(0.0, 24.0)
	_blue_background.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(_blue_background)
	
	_blue_slider = HSlider.new()
	_blue_slider.min_value = 0.0
	_blue_slider.max_value = 1.0
	_blue_slider.step = 1.0 / 256
	
	_blue_slider.anchor_left = 0.0
	_blue_slider.anchor_top = 0.0
	_blue_slider.anchor_right = 1.0
	_blue_slider.anchor_bottom = 1.0
	
	_blue_slider.add_icon_override("grabber", grabber_normal)
	_blue_slider.add_icon_override("grabber_disabled", grabber_normal)
	_blue_slider.add_icon_override("grabber_highlight", grabber_highlight)
	_blue_slider.add_stylebox_override("slider", StyleBoxEmpty.new())
	
	_blue_slider.connect("drag_started", self, "_on_drag_started")
	_blue_slider.connect("drag_ended", self, "_on_drag_ended")
	_blue_slider.connect("value_changed", self, "_on_blue_slider_value_changed")
	_blue_slider.connect("focus_entered", self, "_on_focus_entered")
	_blue_slider.connect("focus_exited", self, "_on_focus_exited")
	_blue_slider.connect("mouse_entered", self, "_on_mouse_entered")
	_blue_slider.connect("mouse_exited", self, "_on_mouse_exited")
	_blue_background.add_child(_blue_slider)
	
	_color_rect = ColorRect.new()
	_color_rect.rect_min_size = Vector2(0.0, 48.0)
	add_child(_color_rect)
	
	_color_label = Label.new()
	_color_label.align = Label.ALIGN_CENTER
	_color_label.valign = Label.VALIGN_CENTER
	_color_label.clip_text = true
	
	_color_label.anchor_left = 0.0
	_color_label.anchor_top = 0.0
	_color_label.anchor_right = 1.0
	_color_label.anchor_bottom = 1.0
	_color_rect.add_child(_color_label)
	
	# Make sure the correct sliders are on display. This function also updates
	# the preview and sliders for us.
	set_hsv_mode(hsv_mode)


func set_color(value: Color) -> void:
	color = value
	
	_update_preview()
	_update_sliders()


func set_hsv_mode(value: bool) -> void:
	hsv_mode = value
	
	if value:
		_hsv_button.pressed = true
	else:
		_rgb_button.pressed = true
	
	_hue_background.visible = value
	_saturation_background.visible = value
	_value_background.visible = value
	
	_red_background.visible = not value
	_green_background.visible = not value
	_blue_background.visible = not value
	
	# Now that the display has changed, make sure everything is up-to-date.
	_update_preview()
	_update_sliders()


# Update the preview rectangle to reflect the current colour.
func _update_preview() -> void:
	if _color_rect == null:
		return
	
	_color_rect.color = color
	
	if _color_label == null:
		return
	
	var hue := color.h
	if is_zero_approx(color.s) or is_zero_approx(color.v):
		hue = _saved_hue
	
	var sat := color.s
	if is_zero_approx(color.v):
		sat = _saved_saturation
	
	if hsv_mode:
		_color_label.text = tr("H: %d S: %d V: %d") % [
				round(360 * hue), round(100 * sat), round(100 * color.v)]
	else:
		_color_label.text = tr("R: %d G: %d B: %d") % [
				color.r8, color.g8, color.b8]
	
	var text_color := Color.black if color.get_luminance() > 0.5 else Color.white
	_color_label.add_color_override("font_color", text_color)
	
	if _saturation_hue_rect == null:
		return
	
	_saturation_hue_rect.color = Color.from_hsv(hue, 1.0, 1.0)
	
	if _value_cumulative_rect == null:
		return
	
	_value_cumulative_rect.color = Color.from_hsv(hue, sat, 1.0)


# Update the sliders to reflect the current colour.
func _update_sliders() -> void:
	if _hue_slider == null:
		return
	
	_hue_slider.value = color.h
	_saved_hue = color.h
	
	if _saturation_slider == null:
		return
	
	_saturation_slider.value = color.s
	_saved_saturation = color.s
	
	if _value_slider == null:
		return
	
	_value_slider.value = color.v
	
	if _red_slider == null:
		return
	
	_red_slider.value = color.r
	
	if _green_slider == null:
		return
	
	_green_slider.value = color.g
	
	if _blue_slider == null:
		return
	
	_blue_slider.value = color.b


func _on_hsv_button_pressed():
	set_hsv_mode(true)


func _on_rgb_button_pressed():
	set_hsv_mode(false)


func _on_hue_slider_value_changed(value: float):
	color.h = value
	_saved_hue = value
	
	_update_preview()
	emit_signal("color_changed", color)


func _on_saturation_slider_value_changed(value: float):
	var old_color := color
	color.s = value
	_saved_saturation = value
	
	# If the saturation was previously 0.0, then the hue would have been reset.
	# We want to restore the hue's value to what it was before that reset.
	if is_zero_approx(old_color.s) and (not is_zero_approx(color.s)):
		color.h = _saved_hue
	
	_update_preview()
	emit_signal("color_changed", color)


func _on_value_slider_value_changed(value: float):
	var old_color := color
	color.v = value
	
	# If the value was previously 0.0, then both the hue and saturation would
	# have been reset. We need to restore both to what they were beforehand.
	if is_zero_approx(old_color.v) and (not is_zero_approx(color.v)):
		color.s = _saved_saturation
		color.h = _saved_hue
	
	_update_preview()
	emit_signal("color_changed", color)


func _on_red_slider_value_changed(value: float):
	color.r = value
	
	_update_preview()
	emit_signal("color_changed", color)


func _on_green_slider_value_changed(value: float):
	color.g = value
	
	_update_preview()
	emit_signal("color_changed", color)


func _on_blue_slider_value_changed(value: float):
	color.b = value
	
	_update_preview()
	emit_signal("color_changed", color)


func _on_drag_started():
	emit_signal("drag_started")


func _on_drag_ended(_value):
	emit_signal("drag_ended")


func _on_focus_entered():
	emit_signal("focus_entered")


func _on_focus_exited():
	emit_signal("focus_exited")


func _on_mouse_entered():
	emit_signal("mouse_entered")


func _on_mouse_exited():
	emit_signal("mouse_exited")
