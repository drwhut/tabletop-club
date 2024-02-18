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

extends Node

## A singleton which saves a list of [Message] in a thread-safe manner.
##
## Messages can be added at any time, from any thread. On each frame of the main
## thread, if any messages were added since the previous frame, [signal XXX] is
## emitted to allow for UI elements like the chat window to take the messages
## and display them to the player.
##
## TODO: Test this class once it is complete.


## Fired when at least one message has been received since the last frame.
signal messages_received()


# The list of messages that can be added to from any thread.
# TODO: Make typed in 4.x
var _message_list: Array = []

# The flag that lets the main thread know a message was received.
var _message_added_flag := false

# The mutex lock for the message list and flag.
var _message_mutex := Mutex.new()


func _ready():
	if CustomModule.is_loaded():
		CustomModule.error_reporter.connect("error_received", self,
				"_on_ErrorReporter_error_received")
		CustomModule.error_reporter.connect("warning_received", self,
				"_on_ErrorReporter_warning_received")
	else:
		push_warning("Cannot receive system errors and warnings - custom module was not loaded")


func _process(_delta: float):
	_message_mutex.lock()
	var message_was_added := _message_added_flag
	_message_added_flag = false
	_message_mutex.unlock()
	
	if message_was_added:
		emit_signal("messages_received")


## Add a message to the list.
func add_message(message: Message) -> void:
	_message_mutex.lock()
	_message_list.push_back(message)
	_message_added_flag = true
	
	# Print the message to STDOUT so that it appears in the logs - we don't need
	# to do this for errors or warnings, since they appear in the logs anyways.
	match message.type:
		Message.TYPE_SAY:
			print("[SAY/%d] %s" % [message.origin, message.text])
		Message.TYPE_WHISPER:
			print("[WHISPER/%d] %s" % [message.origin, message.text])
		Message.TYPE_INFO:
			print("[INFO] %s" % message.text)
		Message.TYPE_WARNING:
			pass
		Message.TYPE_ERROR:
			pass
		_:
			push_error("Cannot print message, unknown type '%d'" % message.type)
	
	_message_mutex.unlock()


## Get the list of messages that were added since the last time this function
## was called. The internal list is cleared by using this function.
## [b]NOTE:[/b] Although this function should work from any thread, it is
## recommended to only use it in the main thread, otherwise you may create
## race conditions for which thread gets the messages first.
## TODO: Make array typed in 4.x
func take_messages() -> Array:
	_message_mutex.lock()
	var out := _message_list
	_message_list = []
	_message_mutex.unlock()
	return out


func _on_ErrorReporter_error_received(_p_func: String, _p_file: String,
		_p_line: int, p_error: String, _p_errorexp: String):
	
	var m := Message.new(Message.TYPE_ERROR, p_error)
	add_message(m)


func _on_ErrorReporter_warning_received(_p_func: String, _p_file: String,
		_p_line: int, p_error: String, _p_errorexp: String):
	
	var m := Message.new(Message.TYPE_WARNING, p_error)
	add_message(m)
