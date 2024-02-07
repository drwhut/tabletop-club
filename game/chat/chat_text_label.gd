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

class_name ChatTextLabel
extends RichTextLabel

## A label which displays the messages sent to the MessageHub.
##
## The label will automatically format the messages depending on their type.
## For security purposes, BBCode formatting within messages will not be used.
## However, specially-made tags can be placed in messages to allow for custom
## formatting within a message:
## [ul]
## [code]<player ID>[/code]: Display a player's name in their chosen colour.
## [/ul]


# An array keeping track of which lines represent which type of messages.
# NOTE: A value of 255 means it is not a valid message.
var _line_type_arr := PoolByteArray()


func _ready():
	# Make sure the first couple of lines are welcome messages to the player.
	push_message(Message.new(Message.TYPE_INFO,
			tr("Welcome to Tabletop Club!")))
	push_message(Message.new(Message.TYPE_INFO,
			tr("To view the list of commands, type /? or /help below and press Enter.")))
	
	GameConfig.connect("applying_settings", self,
			"_on_GameConfig_applying_settings")
	MessageHub.connect("messages_received", self,
			"_on_MessageHub_messages_received")


## Add [param message] to the end of the label in a new line.
func push_message(message: Message) -> void:
	if not _line_type_arr.empty():
		newline()
	
	var line_type := message.type
	
	# TODO: Allow all of the custom colours to be configured.
	match message.type:
		Message.TYPE_SAY:
			pass
		Message.TYPE_WHISPER:
			pass
		Message.TYPE_INFO:
			push_color(Color.aqua)
			add_text("[INFO] ")
			pop()
			add_text(message.text)
		Message.TYPE_WARNING:
			push_color(Color.yellow)
			add_text("[WARN] ")
			add_text(message.text)
			pop()
		Message.TYPE_ERROR:
			push_color(Color.red)
			add_text("[ERROR] ")
			add_text(message.text)
			pop()
		_:
			# Not a valid message, but show it anyways.
			line_type = 255
			add_text(message.text)
	
	_line_type_arr.push_back(line_type)


## Remove the message at the given [param line]. If the line does not exist, an
## error is thrown.
func remove_message(line: int) -> void:
	var success := remove_line(line)
	if not success:
		push_error("Cannot remove line '%d', does not exist" % line)
		return
	
	_line_type_arr.remove(line)


func _on_GameConfig_applying_settings():
	# If either of these settings was just disabled, we need to go through and
	# prune that type of message if it has already been added.
	if GameConfig.general_show_errors and GameConfig.general_show_warnings:
		return
	
	for line in range(_line_type_arr.size() - 1, -1, -1):
		var message_type := _line_type_arr[line]
		
		if (
			message_type == Message.TYPE_ERROR and
			(not GameConfig.general_show_errors)
		):
			remove_message(line)
		
		elif (
			message_type == Message.TYPE_WARNING and
			(not GameConfig.general_show_warnings)
		):
			remove_message(line)


func _on_MessageHub_messages_received():
	var new_messages := MessageHub.take_messages()
	for element in new_messages:
		var message: Message = element
		
		# Don't show errors or warnings if the player does not want to see them.
		if (
			message.type == Message.TYPE_ERROR and
			(not GameConfig.general_show_errors)
		):
			continue
		
		elif (
			message.type == Message.TYPE_WARNING and
			(not GameConfig.general_show_warnings)
		):
			continue
		
		push_message(message)
