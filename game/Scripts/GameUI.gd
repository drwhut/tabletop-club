# open-tabletop
# Copyright (c) 2020 drwhut
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

extends Control

signal card_in_hand_requested(card)
signal card_out_hand_requested(card_texture)
signal piece_requested(piece_entry)

const HIGHLIGHT_COLOUR = Color(0.25, 1.0, 1.0, 0.5)

onready var _game_menu_background = $GameMenuBackground
onready var _hand = $Hand
onready var _objects_dialog = $ObjectsDialog
onready var _objects_tree = $ObjectsDialog/ObjectsTree

var _candidate_card: CardTextureRect = null
var _grabbed_card_from_hand: CardTextureRect = null
var _hand_highlight: ColorRect = ColorRect.new()
var _holding_card = false
var _mouse_in_hand = false
var _mouse_over_cards = []

# Add a card to the hand.
# card: The card to add to the hand.
# front_face: Is the card's front face being shown?
func add_card_to_hand(card: Card, front_face: bool) -> void:
	var texture_rect = _create_card_half_texture(card, front_face)
	_hand.add_child(texture_rect)
	
	var index = _hand.get_child_count() - 1
	if _hand.is_a_parent_of(_hand_highlight):
		index = _hand_highlight.get_index()
	
	_hand.move_child(texture_rect, index)
	
	if _hand.is_a_parent_of(_hand_highlight):
		_hand.remove_child(_hand_highlight)

# Remove a card from our hand.
# card: The card to remove.
func remove_card_from_hand(card: Card) -> void:
	for card_texture in _hand.get_children():
		if card_texture is CardTextureRect:
			if card_texture.card == card:
				_hand.remove_child(card_texture)
				card_texture.queue_free()
	
	# If we were holding the card, stop holding it.
	if _grabbed_card_from_hand:
		if _grabbed_card_from_hand.card == card:
			_grabbed_card_from_hand = null

# Set the piece tree contents, based on the piece database given.
# pieces: The database from the PieceDB.
func set_piece_tree_from_db(pieces: Dictionary) -> void:
	var root = _objects_tree.create_item()
	_objects_tree.set_hide_root(true)
	
	for game in pieces:
		_add_game_to_tree(game, pieces[game])

func _ready():
	var hand_height = _hand.rect_size.y
	_hand_highlight.color = HIGHLIGHT_COLOUR
	_hand_highlight.mouse_filter = MOUSE_FILTER_IGNORE
	_hand_highlight.rect_min_size = Vector2(hand_height / 1.618, hand_height)

func _input(event):
	if event is InputEventMouseButton:
		if event.button_index == BUTTON_LEFT:
			if (not event.is_pressed()) and _grabbed_card_from_hand:
				_grabbed_card_from_hand = null
	
	# Would usually use the signals for this, but we also need to know if the
	# mouse is over the hand when it is also over the cards.
	elif event is InputEventMouseMotion:
		var hand_rect = Rect2(_hand.rect_position, _hand.rect_size)
		_mouse_in_hand = hand_rect.has_point(get_viewport().get_mouse_position())
		
		# Dragging a card from the hand to the room.
		if _grabbed_card_from_hand and not _mouse_in_hand:
			emit_signal("card_out_hand_requested", _grabbed_card_from_hand)
		
		# Dragging a card from the room in and out of the hand.
		elif _holding_card:
			if _mouse_in_hand:
				if not _hand.is_a_parent_of(_hand_highlight):
					_hand.add_child(_hand_highlight)
				if _candidate_card:
					_hand.move_child(_hand_highlight, _candidate_card.get_index())
					
					# Reset the list of cards the mouse is hovering over, as
					# the mouse would now be hovering over the highlighting
					# card.
					_candidate_card = null
					_mouse_over_cards = []
			elif not _mouse_in_hand and _hand.is_a_parent_of(_hand_highlight):
				_hand.remove_child(_hand_highlight)

func _unhandled_input(event):
	if _candidate_card and not _holding_card:
		if event.is_action_pressed("game_flip"):
			_candidate_card.front_face = not _candidate_card.front_face
			_candidate_card.update()
	
	if not _game_menu_background.visible and event.is_action_pressed("game_menu"):
		_game_menu_background.visible = true

# Add a game's piece entries to the piece tree.
# game_name: The name of the game.
# game_pieces: The game's piece entries.
func _add_game_to_tree(game_name: String, game_pieces: Dictionary) -> void:
	var game_node = _objects_tree.create_item(_objects_tree.get_root())
	game_node.set_text(0, game_name)
	
	var dice_node = _objects_tree.create_item(game_node)
	dice_node.set_text(0, "Dice")
	
	_add_type_to_tree(dice_node, game_pieces, "d4", "d4")
	_add_type_to_tree(dice_node, game_pieces, "d6", "d6")
	_add_type_to_tree(dice_node, game_pieces, "d8", "d8")
	
	# If there are no dice in this game, delete the dice node.
	if not dice_node.get_children():
		dice_node.free()
	
	_add_type_to_tree(game_node, game_pieces, "cards", "Cards")
	_add_type_to_tree(game_node, game_pieces, "chips", "Chips")
	_add_type_to_tree(game_node, game_pieces, "pieces", "Pieces")
	_add_type_to_tree(game_node, game_pieces, "stacks", "Stacks")

# Add a piece to the piece tree.
# parent: The parent node of the piece's node in the tree.
# piece: The piece entry of the piece to add.
func _add_piece_to_tree(parent: TreeItem, piece: Dictionary) -> TreeItem:
	var node = _objects_tree.create_item(parent)
	node.set_text(0, piece["name"])
	
	# Keep the piece entry in the node so we can use it later.
	node.set_metadata(0, piece)
	
	return node

# Add a type of piece to the piece tree.
# parent: The parent node to add the type node to.
# game_pieces: The game's piece entries.
# type_name: The name pf the type in the dictionary.
# display_name: The name of the type in the piece tree.
func _add_type_to_tree(parent: TreeItem, game_pieces: Dictionary,
	type_name: String, display_name: String) -> void:
	
	if game_pieces.has(type_name):
			
		var node = _objects_tree.create_item(parent)
		node.set_text(0, display_name)
		
		var array: Array = game_pieces[type_name]
		
		if array.size() > 0:
			for piece in array:
				_add_piece_to_tree(node, piece)
		else:
			node.free()

# Create a half-texture based on a given card.
# card: The card to create the half-texture from.
# front_face: Is the front face of the card showing?
func _create_card_half_texture(card: Card, front_face: bool) -> CardTextureRect:
	var card_entry = card.piece_entry
	
	var texture = load(card_entry["texture_path"])
	texture.flags = 0
	
	var card_aspect_ratio = 1.0
	
	var card_shape = card.get_node("CollisionShape")
	if card_shape:
		card_aspect_ratio = card_shape.scale.x / card_shape.scale.z
	else:
		push_error("Card " + card.name + " does not have a CollisionShape child!")
	
	var card_min_size = Vector2(_hand.rect_size.y * card_aspect_ratio, _hand.rect_size.y)
	
	var texture_rect = CardTextureRect.new()
	texture_rect.card = card
	texture_rect.expand = true
	texture_rect.front_face = front_face
	texture_rect.rect_min_size = card_min_size
	texture_rect.texture = texture
	
	texture_rect.connect("clicked_on", self, "_on_card_texture_clicked")
	texture_rect.connect("mouse_over", self, "_on_card_texture_mouse_over")
	
	return texture_rect

func _on_card_texture_clicked(card_texture: CardTextureRect) -> void:
	# We might get multiple signals if the cards overlap each other.
	if (not _grabbed_card_from_hand) or (card_texture.get_index() > _grabbed_card_from_hand.get_index()):
		_grabbed_card_from_hand = card_texture
	_hand.mouse_filter = Control.MOUSE_FILTER_PASS

func _on_card_texture_mouse_over(card_texture: CardTextureRect, is_over: bool) -> void:
	# We might be mousing over multiple cards if they overlap each other, so
	# keep track of which ones we are mousing over, and use the right-most one
	# as the candidate.
	if is_over and not _mouse_over_cards.has(card_texture):
		_mouse_over_cards.push_back(card_texture)
	
	if not is_over and _mouse_over_cards.has(card_texture):
		_mouse_over_cards.erase(card_texture)
	
	if _mouse_over_cards.size() > 0:
		
		_candidate_card = _mouse_over_cards[0]
		
		for i in range(1, _mouse_over_cards.size()):
			var opponent = _mouse_over_cards[i]
			if opponent.get_index() > _candidate_card.get_index():
				_candidate_card = opponent
	else:
		_candidate_card = null
	
	# If we are grabbing a card from our hand, and we hover over another
	# card, then swap the positions of the cards.
	if _grabbed_card_from_hand and _candidate_card:
		if _candidate_card != _grabbed_card_from_hand:
			var old_index = _candidate_card.get_index()
			_hand.move_child(_candidate_card, _grabbed_card_from_hand.get_index())
			_hand.move_child(_grabbed_card_from_hand, old_index)
			
			# Reset the list of cards the mouse is over, since we have moved
			# the cards.
			_candidate_card = _grabbed_card_from_hand
			_mouse_over_cards = [_grabbed_card_from_hand]

func _on_BackToGameButton_pressed():
	_game_menu_background.visible = false

func _on_DesktopButton_pressed():
	get_tree().quit()

func _on_GameMenuButton_pressed():
	_game_menu_background.visible = true

func _on_GameUI_tree_exited():
	_hand_highlight.free()

func _on_MainMenuButton_pressed():
	Global.start_main_menu()

func _on_ObjectsButton_pressed():
	_objects_dialog.popup_centered()

func _on_ObjectsTree_item_activated():
	var selected = _objects_tree.get_selected()
	
	# Check the selected item has metadata.
	if selected.get_metadata(0):
		emit_signal("piece_requested", selected.get_metadata(0))

func _on_Room_started_hovering_card(card):
	_holding_card = true
	_mouse_in_hand = false
	_hand.mouse_filter = Control.MOUSE_FILTER_PASS

func _on_Room_stopped_hovering_card(card):
	if _mouse_in_hand:
		emit_signal("card_in_hand_requested", card)
	
	_holding_card = false
	_mouse_in_hand = false
	_hand.mouse_filter = Control.MOUSE_FILTER_IGNORE
