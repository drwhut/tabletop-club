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

class_name TransferState
extends Reference

## Describes the state of multi-chunk data transfer from one peer to another.


## The ID of the peer sending the data.
var sender_id := 0

## The ID of the peer receiving the data.
var receiver_id := 0

## Has the receiver accepted the sender's transfer offer?
var receiver_accepted := false

## Is the receiver skipping the transfer of data? That is, they already have the
## data that is being sent.
var receiver_skipping := false

## The data that is being sent, or the data that has been received so far.
var data: PartialData = null

## The number of data packets that have been sent by the sender.
var num_packets_sent := 0

## The number of data packets that have been acknowledged by the receiver.
var num_packets_ackd := 0

## The time at which the last message from the other peer was received.
## If a message is not received in time, then the transfer is timed out.
var last_message_time_ms := 0
