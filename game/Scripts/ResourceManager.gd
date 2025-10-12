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

extends Node

# Loading resources from multiple threads at the same time is not supported -
# so make sure we load resources one at a time with a mutex.
var _res_mutex = Mutex.new()

var _free_queue = []

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
	
	# Workaround for this issue:
	# https://github.com/godotengine/godot/issues/55566
	OS.delay_msec(1)
	
	var res: Resource = load(path)
	
	# On macOS, I came across a bug in GLES3 where a StreamTexture would be
	# freed (via normal means), but the material holding that texture would not
	# be updated - so instead of delving into graphics library code I decided
	# to be a coward and just use a workaround - just keep StreamTextures
	# hostage in memory :)
	if OS.get_name() == "OSX":
		if res is StreamTexture:
			_stex_refs[res.resource_path] = res
	
	_res_mutex.unlock()
	
	return res

# Free an object in a thread-safe manner.
# object: The object to free.
func free_object(object: Object) -> void:
	# Lock the resource mutex here, just in case a resource used by the object
	# is being created as it is being freed here.
	_res_mutex.lock()
	if object is Node:
		# This is a workaround for a crash that sometimes happens when a
		# MeshInstance tries to disconnect its mesh's _mesh_changed signal.
		var node_stack = [object]
		while not node_stack.empty():
			var node: Node = node_stack.pop_back()
			for child in node.get_children():
				node_stack.push_back(child)
			
			if node is MeshInstance:
				node.mesh = null
		
		object.queue_free()
	else:
		object.free()
	_res_mutex.unlock()

# Queue an object to be freed in a thread-safe manner.
# object: The object to be freed.
func queue_free_object(object: Object) -> void:
	_free_mutex.lock()
	_free_queue.push_back(object)
	call_deferred("_clear_free_queue")
	_free_mutex.unlock()

func _notification(what):
	match what:
		NOTIFICATION_PREDELETE:
			_clear_free_queue()

# Free all of the objects in the free queue.
func _clear_free_queue() -> void:
	_free_mutex.lock()
	while not _free_queue.empty():
		free_object(_free_queue.pop_back())
	_free_mutex.unlock()
