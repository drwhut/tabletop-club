# tabletop-club
# Copyright (c) 2020-2022 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2022 Tabletop Club contributors (see game/CREDITS.tres).
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

# Loading resources from multiple threads at the same time is not supported -
# so make sure we load resources one at a time with a mutex.
var _res_mutex = Mutex.new()

# Prevent two objects from being registered to be freed at the same time.
var _free_mutex = Mutex.new()

# OSX only: prevents StreamTextures from being freed from memory, since we keep
# a reference to them here.
var _stex_refs = {}

# Load the resource at the given path. This function will block if another
# thread is loading a resource at the same time.
# Returns: The resource at the given path.
# path: The path of the resource to load.
func load_res(path: String) -> Resource:
	_res_mutex.lock()
	var res: Resource = load(path)
	
	# On macOS, I came across a bug in GLES3 where a StreamTexture would be
	# freed (via normal means), but the material holding that texture would not
	# be updated - so instead of delving into graphics library code I decided
	# to be a coward and just use a workaround - just keep StreamTextures
	# hostage in memory :)
	if OS.get_name() == "OSX":
		if res is StreamTexture:
			print("_load_res: Saved %s" % res.resource_path)
			_stex_refs[res.resource_path] = res
	
	_res_mutex.unlock()
	
	return res

# Free an object in a thread-safe manner.
# object: The object to free.
func free_object(object: Object) -> void:
	# Lock the resource mutex here, just in case a resource used by the object
	# is being created as it is being freed here.
	_res_mutex.lock()
	object.free()
	_res_mutex.unlock()

# Queue an object to be freed in a thread-safe manner.
# object: The object to be freed.
func queue_free_object(object: Object) -> void:
	_free_mutex.lock()
	call_deferred("free_object", object)
	_free_mutex.unlock()
