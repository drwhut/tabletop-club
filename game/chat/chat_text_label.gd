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


## Add text to the label with game-specific substitutions, e.g.
## [code]<player 1>[/code].
func add_text_with_sub(text_str: String) -> void:
	var normal_since := 0
	var sub_since := -1
	
	for index in range(text_str.length()):
		match text_str[index]:
			"<":
				sub_since = index
			">":
				if sub_since < 0:
					continue
				
				var normal_length := sub_since - normal_since
				var sub_length := index - sub_since + 1
				# We only need what's inside the angled brackets.
				var sub_content := text_str.substr(sub_since + 1, sub_length - 2)
				# PoolStringArray -> Array so we can use 'match' on it.
				var sub_parts_arr := Array(sub_content.split(" ", true))
				
				match sub_parts_arr:
					["player", var arg]:
						var player_id_str: String = arg
						if not player_id_str.is_valid_integer():
							continue
						
						var player_id: int = player_id_str.to_int()
						var player := Lobby.get_player(player_id)
						if player == null:
							continue
						
						add_text(text_str.substr(normal_since, normal_length))
						push_color(player.color)
						add_text(player.name)
						pop()
						normal_since = index + 1
					
					["player_old", var arg]:
						var player_id_str: String = arg
						if not player_id_str.is_valid_integer():
							continue
						
						var player_id: int = player_id_str.to_int()
						var old_player := Lobby.get_player_old(player_id)
						if old_player == null:
							continue
						
						add_text(text_str.substr(normal_since, normal_length))
						push_color(old_player.color)
						add_text(old_player.name)
						pop()
						normal_since = index + 1
				
				# Need another '<' for the next substitution.
				sub_since = -1
	
	if normal_since < text_str.length():
		add_text(text_str.substr(normal_since))


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
			push_bold()
			add_text("[INFO] ")
			pop()
			pop()
			add_text_with_sub(message.text)
		Message.TYPE_WARNING:
			push_color(Color.yellow)
			push_bold()
			add_text("[WARN] ")
			pop()
			add_text(message.text)
			pop()
		Message.TYPE_ERROR:
			push_color(Color.red)
			push_bold()
			add_text("[ERROR] ")
			pop()
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


## Scroll to the last message that was displayed.
func scroll_to_latest() -> void:
	var line := get_line_count() - 1
	if line < 0:
		return
	
	scroll_to_line(line)


func _on_GameConfig_applying_settings():
	var font_size := 16
	match GameConfig.multiplayer_chat_font_size:
		GameConfig.FONT_SIZE_SMALL:
			font_size = 12
		GameConfig.FONT_SIZE_MEDIUM:
			font_size = 16
		GameConfig.FONT_SIZE_LARGE:
			font_size = 20
	
	# NOTE: This section expects custom fonts to be set in the theme overrides.
	var normal_font: DynamicFont = get_font("normal_font")
	normal_font.size = font_size
	
	var italics_font: DynamicFont = get_font("italics_font")
	italics_font.size = font_size
	
	var bold_font: DynamicFont = get_font("bold_font")
	bold_font.size = font_size
	
	var bold_italics_font: DynamicFont = get_font("bold_italics_font")
	bold_italics_font.size = font_size
	
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
