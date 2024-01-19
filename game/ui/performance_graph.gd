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

class_name PerformanceGraph
extends Control

## Shows a graph of the game's performance over time.


## If [code]true[/code], show the physics frame time. Otherwise, show the
## process frame time.
export(bool) var physics_time := false setget set_physics_time

## Set the colour of the graph's line.
export(Color) var line_color := Color.white

## Set the width of the graph's line.
export(float, 1.0, 100.0, 1.0) var line_width := 1.0

## Set the number of data points that are collected.
export(int, 1, 2000) var series_size := 960 setget set_series_size


# The list of data points in the series that the line shows each frame.
var _series_data := PoolVector2Array()

# The number of the last frame that the time was recorded at.
# NOTE: _last_frame - 1 will be the last recorded index in the series, since we
# can only start calculating the delta once there has been at least two frames.
var _last_frame := -1

# The time recorded at the previous frame.
var _last_time_usec := -1


func _ready():
	# Initialize the data series to the given size. The data will be garbage to
	# start with, but over time it will be filled with frame times.
	_series_data.resize(series_size)


func _process(_delta: float):
	if physics_time:
		return
	
	record_delta()


func _physics_process(_delta: float):
	if not physics_time:
		return
	
	record_delta()


func _draw():
	var first_frame := _last_frame - series_size
	if first_frame < 0:
		first_frame = 0
	
	for index in range(first_frame, _last_frame - 2):
		var series_index_from := index % series_size
		var series_index_to := (index + 1) % series_size
		
		var from := _series_data[series_index_from]
		var to := _series_data[series_index_to]
		
		draw_line(from, to, line_color, line_width, false)


## Clear the series data and restart the graph.
func clear() -> void:
	_last_frame = -1
	_last_time_usec = -1


## Record the time in seconds between the previous frame and the current frame,
## and append the result to the end of the series.
func record_delta() -> void:
	# TODO: Use Time.get_ticks_*() throughout the code, as OS.get_ticks_*() is
	# being deprecated.
	var current_time_usec := Time.get_ticks_usec()
	
	if _last_time_usec >= 0:
		var series_index := _last_frame % series_size
		var series_value := float(current_time_usec - _last_time_usec) / 1000000
		
		# We want the graph to go up the screen when the value increases,
		# specifically, the top of the control should be 1000ms.
		var series_y := rect_size.y * (1.0 - series_value)
		
		# NOTE: Putting the value in a Vector2 secretly converts the float from
		# being 64-bit to being 32-bit.
		var series_pos := Vector2(series_index, series_y)
		
		_series_data[series_index] = series_pos
	
	_last_frame += 1
	_last_time_usec = current_time_usec
	
	update() # Notify the control to re-draw the graph.


func set_physics_time(value: bool) -> void:
	physics_time = value
	
	# Reset the graph.
	clear()


func set_series_size(value: int) -> void:
	if value < 1:
		return
	
	series_size = value
	_series_data.resize(value)
	
	# Reset the graph.
	clear()
