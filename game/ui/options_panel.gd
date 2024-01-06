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

## The options menu, which interfaces with the GameConfig class.
##
## NOTE: If a control is named "opt_NAME", where NAME is the name of a property
## in GameConfig, then this script will automatically link the control with the
## corresponding property, removing the need to manually connect signals or to
## write functions for each individual control.


# A dictionary mapping controls to the name of the property that they represent
# in the GameConfig.
var _control_property_map := {}


onready var _section_parent := $VBoxContainer/MainContainer/OptionContainer/ScrollContainer/SectionParent/
onready var _audio_container := $VBoxContainer/MainContainer/OptionContainer/ScrollContainer/SectionParent/AudioContainer
onready var _control_container := $VBoxContainer/MainContainer/OptionContainer/ScrollContainer/SectionParent/ControlContainer


func _ready():
	# Before we do anything, we need to populate the control property map so
	# that we can start displaying and modifying the GameConfig properties.
	var node_stack: Array = [_section_parent]
	while not node_stack.empty():
		var current_node: Node = node_stack.pop_front()
		if current_node is Control and current_node.name.begins_with("opt_"):
			var property_name := current_node.name.substr(4)
			
			if GameConfig.get(property_name) != null:
				_control_property_map[current_node] = property_name
			else:
				push_error("Property '%s' does not exist in the GameConfig (from: '%s')" % [
						property_name, current_node.name])
		
		node_stack.append_array(current_node.get_children())
	
	# Show the current properties when we enter the game.
	read_config()


## Have the controls show the current values from the GameConfig.
func read_config() -> void:
	for key in _control_property_map:
		var control: Control = key
		var property_name: String = _control_property_map[key]
		
		if control is LabeledSlider:
			control.value = GameConfig.get(property_name)
		else:
			push_error("Cannot show value of '%s' with control '%s', unimplemented type" % [
					property_name, control.name])


# Show the given section, and hide the others.
func _show_section(section_root: Control) -> void:
	for child in _section_parent.get_children():
		if child is Control:
			child.visible = (child == section_root)


func _on_AudioSectionButton_pressed():
	_show_section(_audio_container)


func _on_ControlSectionButton_pressed():
	_show_section(_control_container)


func _on_GeneralSectionButton_pressed():
	pass # Replace with function body.


func _on_MultiplayerSectionButton_pressed():
	pass # Replace with function body.


func _on_VideoSectionButton_pressed():
	pass # Replace with function body.


func _on_BackButton_pressed():
	visible = false
