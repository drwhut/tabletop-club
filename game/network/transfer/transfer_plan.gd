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

class_name TransferPlan
extends Reference

## A structure describing a future transfer of data to one or more clients.
##
## [b]NOTE:[/b] [method get_data] can be overwritten by subclasses if data
## should be retrieved the instant before a transfer occurs, instead of when it
## is added to a transfer queue.


## The list of peer IDs to send the data to.
## TODO: Make array typed in 4.x
var receiver_ids: Array = []

## The data to send to the other peers.
var data: PartialData = null


## Retrieve a reference to the data that should be transferred.
## Returns [code]null[/code] if no data exists.
func get_data() -> PartialData:
	return data
