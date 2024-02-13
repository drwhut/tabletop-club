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

class_name CommandParser
extends Reference

## Parses commands given by the player and executes them.


## The full list of commands.
enum {
	COMMAND_HELP,
	COMMAND_SAY,
	COMMAND_WHISPER,
	COMMAND_MAX ## Used for verification only.
}


## A mapping that defines which aliases invoke which commands.
const ALIAS_COMMAND_MAP := {
	"?": COMMAND_HELP,
	"help": COMMAND_HELP,
	"s": COMMAND_SAY,
	"say": COMMAND_SAY,
	"w": COMMAND_WHISPER,
	"whisper": COMMAND_WHISPER,
}


## Get the localised argument format for the given [param command_id].
func get_arg_format(command_id: int) -> String:
	match command_id:
		COMMAND_HELP:
			return ""
		COMMAND_SAY:
			return tr("<message>")
		COMMAND_WHISPER:
			return tr("<player> <message>")
		_:
			return ""


## Get the localised description for the given [param command_id].
func get_description(command_id: int) -> String:
	match command_id:
		COMMAND_HELP:
			return tr("List all of the commands that can be invoked.")
		COMMAND_SAY:
			return tr("Send a public message to everyone in the room.")
		COMMAND_WHISPER:
			return tr("Send a private message to another player.")
		_:
			return ""


## Parse the [param text] given by the player as a potential command.
func parse_command(text: String) -> void:
	var cmd_arg_split := text.split(" ", false, 1)
	if cmd_arg_split.empty():
		push_error("Invalid command, text is empty")
		return
	
	var command: String = cmd_arg_split[0]
	if command.begins_with("/"):
		command = command.substr(1)
	var command_id: int = ALIAS_COMMAND_MAP.get(command, -1)
	if command_id < 0:
		push_error("Unknown command '%s'" % command)
		return
	
	var args_str := ""
	if cmd_arg_split.size() > 1:
		args_str = cmd_arg_split[1]
	
	parse_args(command_id, args_str)


## For the given [param command_id], parse the [param args_str] to check if it
## is valid, then execute the command.
func parse_args(command_id: int, args_str: String) -> void:
	match command_id:
		COMMAND_HELP:
			# TODO: Replace with helper function, report number of arguments
			# that were given. Should helper function return both the argument
			# list and a success boolean?
			if not args_str.empty():
				push_error("/help: Arguments received when none were expected")
				return
			
			execute_help()
		COMMAND_SAY:
			pass
		COMMAND_WHISPER:
			pass
		_:
			push_error("Unknown command ID '%d', cannot execute" % command_id)
			return


## Execute the [code]/help[/code] command.
func execute_help() -> void:
	var command_alias_list := []
	for _index in range(0, COMMAND_MAX):
		command_alias_list.push_back([])
	
	for element in ALIAS_COMMAND_MAP:
		var alias: String = element
		var command_id: int = ALIAS_COMMAND_MAP[element]
		var alias_list: Array = command_alias_list[command_id]
		
		var alias_with_slash := "/" + alias
		alias_list.push_back(alias_with_slash)
	
	for command_id in range(0, command_alias_list.size()):
		var alias_list: Array = command_alias_list[command_id]
		var alias_list_as_string := ", ".join(alias_list)
		var arg_format := get_arg_format(command_id)
		var description := get_description(command_id)
		
		var message := Message.new(Message.TYPE_INFO, "%s %s: %s" % [
				alias_list_as_string, arg_format, description])
		MessageHub.add_message(message)


## Execute the [code]/say[/code] command.
func execute_say(_message: String) -> void:
	pass


## Execute the [code]/whisper[/code] command.
func execute_whisper(_player_id: int, _message: String) -> void:
	pass
