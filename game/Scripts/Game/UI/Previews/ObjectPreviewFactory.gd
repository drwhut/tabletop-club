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

var _build_thread = Thread.new()

var _entry_list = {}
var _entry_list_mutex = Mutex.new()

var _finished_pieces = {}
var _finished_pieces_mutex = Mutex.new()

var _free_pieces = []
var _free_pieces_mutex = Mutex.new()

# Add a request to build a piece with the given entry, and place the result in
# the given object preview.
# preview: The preview to place the built piece into.
# piece_entry: The entry to build the piece with.
func add_to_queue(preview: ObjectPreview, piece_entry: Dictionary) -> void:
	_entry_list_mutex.lock()
	_entry_list[preview] = piece_entry
	_entry_list_mutex.unlock()
	
	if not _build_thread.is_active():
		_build_thread.start(self, "_build")

# Wait for the building thread to finish it's current jobs. This should be
# called if a preview is about to leave the scene tree.
func flush_queue() -> void:
	if _build_thread.is_active():
		_build_thread.wait_to_finish()

# Free a piece while in the build thread. This should be used if the piece was
# built via this factory.
# piece: The piece to free.
func free_piece(piece: Piece) -> void:
	_free_pieces_mutex.lock()
	_free_pieces.append(piece)
	_free_pieces_mutex.unlock()
	
	if not _build_thread.is_active():
		_build_thread.start(self, "_build")

func _ready():
	connect("tree_exiting", self, "_on_tree_exiting")

func _process(_delta):
	_finished_pieces_mutex.lock()
	for preview in _finished_pieces:
		if preview is ObjectPreview:
			var piece = _finished_pieces[preview]
			if piece is Piece:
				preview.set_piece_display(piece)
				
				# If the piece is not parented now, it means the preview
				# rejected it (now that I'm writing this it actually sounds
				# really sad, orphans should never be rejected). This is most
				# likely because the preview was cleared earlier while we were
				# still building the piece for the preview.
				if not piece.is_inside_tree():
					free_piece(piece)
	
	_finished_pieces.clear()
	_finished_pieces_mutex.unlock()

# The function the build thread runs.
# _userdata: Not used.
func _build(_userdata) -> void:
	# Take the first entry out of the list.
	var preview: ObjectPreview = null
	var piece_entry: Dictionary = {}
	_entry_list_mutex.lock()
	if not _entry_list.empty():
		preview = _entry_list.keys()[0]
		piece_entry = _entry_list[preview]
		_entry_list.erase(preview)
	_entry_list_mutex.unlock()
	
	while preview != null and (not piece_entry.empty()):
		var piece: Piece = null
		
		# This section of code is why this function is running in a thread.
		if piece_entry.has("texture_paths"):
			if piece_entry["scene_path"] == "res://Pieces/Card.tscn":
				piece = preload("res://Pieces/StackSandwich.tscn").instance()
			else:
				piece = preload("res://Pieces/StackLasagne.tscn").instance()
			PieceBuilder.fill_stack(piece, piece_entry)
		else:
			piece = PieceBuilder.build_piece(piece_entry)
		
		_finished_pieces_mutex.lock()
		_finished_pieces[preview] = piece
		_finished_pieces_mutex.unlock()
		
		# Take the first entry out of the list.
		preview = null
		piece_entry = {}
		_entry_list_mutex.lock()
		if not _entry_list.empty():
			preview = _entry_list.keys()[0]
			piece_entry = _entry_list[preview]
			_entry_list.erase(preview)
		_entry_list_mutex.unlock()
	
	_free_pieces_mutex.lock()
	while not _free_pieces.empty():
		var piece = _free_pieces.pop_back()
		piece.free()
	_free_pieces_mutex.unlock()
	
	# When threads reach the end of their function, Godot still flags them as
	# "active" until they are joined back into the main thread. This line
	# ensures the thread is properly de-allocated when there are no more pieces
	# to build.
	_build_thread.call_deferred("wait_to_finish")

func _on_tree_exiting():
	# Start the build thread so it can free the remaining pieces in the free
	# queue.
	if not _build_thread.is_active():
		_build_thread.start(self, "_build")
	
	if _build_thread.is_active():
		_build_thread.wait_to_finish()
