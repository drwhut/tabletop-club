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

class_name PartialData
extends Reference

## A reference to generic byte data that is transferred between clients.
##
## [b]NOTE:[/b] Depending on whether the data is being sent or being received,
## the data held in this class can either be all of the data, or just the
## chunks of data that have been received so far respectively.


## The different types of data that can be sent in chunks.
## [b]NOTE:[/b] This does not refer to different data types, rather, it refers
## to what the data will be used for.
enum {
	TYPE_STATE, ## The data represents a room state.
	TYPE_MAX ## Used for validation only.
}


## The name associated with the data. This is used to check if the client that
## is receiving data already has the data in memory, and thus the transfer can
## be skipped.
var name := ""

## The type of data that is being represented. See the [code]TYPE_*[/code]
## constants for possible values.
var type := TYPE_STATE setget set_type

## The size of the data when it is compressed. This is likely to be how it is
## sent between clients.
var size_compressed := 0 setget set_size_compressed

## The size of the data when it is uncompressed. This value is needed for the
## buffer size when the decompression occurs.
var size_uncompressed := 0 setget set_size_uncompressed

## The data itself, either in whole, or as a subsection of the data yet to be
## received.
var bytes := PoolByteArray()


func set_type(value: int) -> void:
	if value < 0 or value >= TYPE_MAX:
		push_error("Value '%d' is invalid for partial data type" % value)
		return
	
	type = value


func set_size_compressed(value: int) -> void:
	if value < 0:
		push_error("Compressed size cannot be negative")
		return
	
	if value > size_uncompressed:
		push_error("Compressed size cannot be bigger than uncompressed size")
		return
	
	size_compressed = value


func set_size_uncompressed(value: int) -> void:
	if value < 0:
		push_error("Uncompressed size cannot be negative")
		return
	
	if value < size_compressed:
		push_error("Uncompressed size cannot be smaller than compressed size")
		return
	
	size_uncompressed = value
