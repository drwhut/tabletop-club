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

## A global flag to stop the import process gracefully.
##
## In the event that the player wants to close the game while the import thread
## is running, we still want to join the thread to avoid crashes, but it may
## take a while to stop processing depending on the number of custom assets that
## have been scanned in. The solution is that throughout the import process,
## this flag is checked to see if the process should be stopped, and if it is
## enabled, then the thread will quickly break out of any expensive loops in
## order to finish and join with the main thread as soon as possible.
##
## There are two reasons why this is a global script:
## - Static variables don't exist yet. :|
## - To avoid having two seperate references to the [AssetCatalog] in separate
## threads.


# The abort flag - if this is enabled, it means it's time to say goodbye :'(
var _abort_flag := false

# Thread safety, baby!
var _abort_flag_mutex := Mutex.new()


## Enable the abort flag, prompting the import process to end as quickly as
## possible if it is still running.
func enable() -> void:
	_abort_flag_mutex.lock()
	_abort_flag = true
	_abort_flag_mutex.unlock()


## Check if the abort flag has been enabled.
func is_enabled() -> bool:
	_abort_flag_mutex.lock()
	var enabled := _abort_flag
	_abort_flag_mutex.unlock()
	return enabled
