# tabletop-club
# Copyright (c) 2020-2025 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2025 Tabletop Club contributors (see game/CREDITS.tres).
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

extends SpeakerPiece

class_name TimerPiece

signal mode_changed(new_mode)
signal timer_paused()
signal timer_resumed()

enum {
	MODE_COUNTDOWN,
	MODE_STOPWATCH,
	MODE_SYSTEM_TIME
}

const SYNC_INTERVAL = 5.0

var _last_sync = 0.0
var _mode = MODE_SYSTEM_TIME
var _paused = false
var _time = 0.0

# Get the mode the timer is in.
# Returns: The mode the timer is in. See the MODE_* enum for possible values.
func get_mode() -> int:
	return _mode

# Get the internal timer time.
# NOTE: This value is meaningless if the timer is in system time mode.
# Returns: The internal time.
func get_time() -> float:
	return _time

# Get the timer's time as a string, depending on the mode the timer is in.
# Returns: The internal time as a string.
func get_time_string() -> String:
	match _mode:
		MODE_COUNTDOWN:
			return _time_to_hms(_time)
		
		MODE_STOPWATCH:
			return _time_to_hms(_time)
		
		MODE_SYSTEM_TIME:
			var time_dict = OS.get_time()
			
			var hour   = time_dict["hour"]
			var minute = time_dict["minute"]
			var second = time_dict["second"]
			return "%02d:%02d:%02d" % [hour, minute, second]
		
		_:
			push_error("Invalid timer mode!")
			return ""

# Check if the timer is paused.
# Returns: If the timer is paused.
func is_timer_paused() -> bool:
	return _paused

# Pause the timer at a specific time.
# time: The time to pause the timer at.
remotesync func pause_timer_at(time: float) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_paused = true
	set_time(time)
	
	emit_signal("timer_paused")

# Request the server to pause the timer.
master func request_pause_timer() -> void:
	rpc("pause_timer_at", get_time())

# Request the server to resume the internal timer if it is paused.
master func request_resume_timer() -> void:
	rpc("resume_timer")

# Request the server to start a countdown on the timer.
# from: The number of seconds the countdown should last.
master func request_start_countdown(from: float) -> void:
	rpc("start_countdown", from)

# Request the server to starts a stopwatch on the timer.
master func request_start_stopwatch() -> void:
	rpc("start_stopwatch")

# Request the server to switch to the system time mode.
master func request_stop_timer() -> void:
	rpc("stop_timer")

# Request the server to sync the internal timer.
master func request_sync_timer() -> void:
	var player_id = get_tree().get_rpc_sender_id()
	if player_id > 1:
		rpc_id(player_id, "request_sync_timer_accepted", get_time())

# Called by the server when the request to sync the internal timer was accepted.
puppet func request_sync_timer_accepted(time: float) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	set_time(time)

# Resume the internal timer.
remotesync func resume_timer() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	_paused = false
	
	emit_signal("timer_resumed")

# Set the mode the timer is in.
# timer_mode: The mode the timer is in. See the MODE_* enum for possible values.
func set_mode(timer_mode: int) -> void:
	if timer_mode < MODE_COUNTDOWN or timer_mode > MODE_SYSTEM_TIME:
		push_error("Invalid timer mode!")
		return
	
	_mode = timer_mode
	
	emit_signal("mode_changed", _mode)

# Set the internal timer time.
# time: The new internal time.
func set_time(time: float) -> void:
	if time < 0:
		push_error("Invalid time!")
		return
	
	_time = time

# Start a countdown on the timer.
# from: The number of seconds the countdown should last.
remotesync func start_countdown(from: float) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	set_time(from)
	set_mode(MODE_COUNTDOWN)

# Start the stopwatch on the timer.
remotesync func start_stopwatch() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	set_time(0.0)
	set_mode(MODE_STOPWATCH)

# If the timer is in countdown or stopwatch mode, switch it to system time mode.
remotesync func stop_timer() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	set_mode(MODE_SYSTEM_TIME)

func _process(delta):
	if not _paused:
		if _mode == MODE_COUNTDOWN:
			_time -= delta
			
			# Only one peer should decide when the countdown ends for everyone
			# else - the server.
			if get_tree().is_network_server():
				if _time < 0:
					request_stop_timer()
					request_play_track()
			
		elif _mode == MODE_STOPWATCH:
			_time += delta
		
		if _mode != MODE_SYSTEM_TIME and (not get_tree().is_network_server()):
			_last_sync += delta
			if _last_sync > SYNC_INTERVAL:
				rpc_id(1, "request_sync_timer")
				_last_sync -= SYNC_INTERVAL

# Convert a time value to a H:M:S string.
# Return: The time value as a H:M:S string.
# time: The time value in seconds.
func _time_to_hms(time: float) -> String:
	var time_int = int(time)
	
	var hour = time_int / 3600
	time_int %= 3600
	var minute = time_int / 60
	var second = time_int % 60
	
	return "%02d:%02d:%02d" % [hour, minute, second]
