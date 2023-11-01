# tabletop-club
# Copyright (c) 2020-2023 Benjamin 'drwhut' Beddows.
# Copyright (c) 2021-2023 Tabletop Club contributors (see game/CREDITS.tres).
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

extends GutTest

## Test the [RoomState] class, and the loading and saving of it.


const STATE_FILE_PATH := "user://__STATE__.tc"


func before_all() -> void:
	# For these tests, we need to load the default asset pack into the AssetDB,
	# since the states will be looking for entries within the pack.
	var ttc_pack := preload("res://assets/default_pack/ttc_pack.tres")
	ttc_pack.reset_dictionary()
	AssetDB.add_pack(ttc_pack)
	AssetDB.commit_changes()


func after_all() -> void:
	# Once we are done with these tests, remove the default pack so that all of
	# the other tests are working with an empty AssetDB.
	AssetDB.remove_pack("TabletopClub")
	AssetDB.commit_changes()


func test_saving_and_loading_state() -> void:
	var state_before := RoomState.new()
	state_before.lamp_color = Color.red
	state_before.lamp_intensity = 2.75
	state_before.is_lamp_sunlight = false
	
	state_before.skybox_entry = preload("res://assets/default_pack/skyboxes/space.tres")
	state_before.table_entry = preload("res://assets/default_pack/tables/picnic_bench.tres")
	
	state_before.table_transform.origin = Vector3(50.0, 0.0, 25.0)
	state_before.is_table_rigid = false
	
	# TODO: Use PaintPlane constants.
	var paint_image := Image.new()
	paint_image.create(512, 512, false, Image.FORMAT_RGBA8)
	paint_image.fill(Color.pink)
	state_before.table_paint_image = paint_image
	
	var hidden_area_1 := HiddenAreaState.new()
	hidden_area_1.index_id = 1
	hidden_area_1.player_id = 1
	hidden_area_1.transform = Transform.IDENTITY.rotated(Vector3.UP, PI / 2)
	
	var hidden_area_2 := HiddenAreaState.new()
	hidden_area_2.index_id = 2
	hidden_area_2.player_id = 247344
	hidden_area_2.transform = Transform.IDENTITY.rotated(Vector3.UP, -PI / 2)
	hidden_area_2.transform.origin = Vector3(0.0, 0.0, -20.0)
	
	state_before.hidden_area_states = [ hidden_area_1, hidden_area_2 ]
	
	var piece_0 := PieceState.new()
	piece_0.index_id = 0
	piece_0.scene_entry = preload("res://assets/default_pack/pieces/chess_knight_black.tres")
	piece_0.is_locked = false
	piece_0.transform.origin = Vector3(0.0, 100.0, 5.0)
	piece_0.user_scale = Vector3.ONE
	piece_0.user_albedo = Color.blue
	
	var speaker_1 := SpeakerState.new()
	speaker_1.index_id = 1
	speaker_1.scene_entry = preload("res://assets/default_pack/speakers/gramophone.tres")
	speaker_1.is_locked = true
	speaker_1.transform.origin = Vector3(100.0, 20.0, 0.0)
	speaker_1.user_scale = Vector3(5.0, 1.0, 1.0)
	speaker_1.user_albedo = Color.white
	speaker_1.is_using_music_bus = true
	speaker_1.is_playing = true
	speaker_1.is_paused = false
	speaker_1.is_positional = false
	speaker_1.playback_position = 10.0
	speaker_1.unit_size = 2.0
	speaker_1.track_entry = preload("res://assets/default_pack/music/kevin_macleod_in_your_arms.tres")
	
	var timer_2 := TimerState.new()
	timer_2.index_id = 2
	timer_2.scene_entry = preload("res://assets/default_pack/timers/radio.tres")
	timer_2.is_locked = true
	timer_2.transform.basis = Basis.IDENTITY.rotated(Vector3.UP, -PI / 2)
	timer_2.transform.origin = Vector3(-50.0, 10.0, 0.0)
	timer_2.user_scale = Vector3(1.5, 1.5, 1.5)
	timer_2.user_albedo = Color.yellow
	timer_2.is_using_music_bus = false
	timer_2.is_playing = false
	timer_2.is_paused = false
	timer_2.is_positional = true
	timer_2.playback_position = 0.0
	timer_2.unit_size = 5.0
	timer_2.track_entry = preload("res://assets/default_pack/sounds/alarm.tres")
	timer_2.is_timer_paused = true
	timer_2.timer_mode = 1 # TODO: Replace with STOPWATCH.
	timer_2.timer_time = 69.420
	
	var stack_3 := ContainerState.new()
	stack_3.index_id = 3
	stack_3.scene_entry = null
	stack_3.is_locked = true
	stack_3.transform.basis = Basis.IDENTITY.rotated(Vector3.FORWARD, PI / 2)
	stack_3.transform.origin = Vector3(0.0, 0.5, 5.0)
	stack_3.user_scale = Vector3(6.0, 1.0, 8.0)
	stack_3.user_albedo = Color.white
	
	var card_4 := PieceState.new()
	card_4.index_id = 4
	card_4.scene_entry = preload("res://assets/default_pack/cards/spades_01.tres")
	card_4.is_locked = false
	card_4.transform = Transform.IDENTITY
	card_4.user_scale = Vector3(7.0, 1.0, 8.0) # Should not be saved.
	card_4.user_albedo = Color.gray
	
	var card_5 := PieceState.new()
	card_5.index_id = 5
	card_5.scene_entry = preload("res://assets/default_pack/cards/hearts_02.tres")
	card_5.is_locked = false
	card_5.transform.basis = Basis.IDENTITY.rotated(Vector3.BACK, PI)
	card_5.user_scale = Vector3(8.0, 1.0, 8.0) # Should not be saved.
	card_5.user_albedo = Color.white
	
	stack_3.content_states = [ card_4, card_5 ]
	
	var container_6 := ContainerState.new()
	container_6.index_id = 6
	container_6.scene_entry = preload("res://assets/default_pack/containers/pot.tres")
	container_6.is_locked = true
	container_6.transform.basis = Basis.IDENTITY.rotated(Vector3.UP, PI)
	container_6.transform.origin = Vector3(80.0, 4.0, 40.0)
	container_6.user_scale = Vector3(20.0, 20.0, 20.0)
	container_6.user_albedo = Color.green
	
	var container_7 := ContainerState.new()
	container_7.index_id = 7
	container_7.scene_entry = preload("res://assets/default_pack/containers/purse.tres")
	container_7.is_locked = false
	container_7.transform.basis = Basis.IDENTITY
	container_7.transform.origin = Vector3(128.0, 256.0, -512.0)
	container_7.user_scale = Vector3(10.0, 0.5, 10.0)
	container_7.user_albedo = Color.white
	
	var stone_8 := PieceState.new()
	stone_8.index_id = 8
	stone_8.scene_entry = preload("res://assets/default_pack/pieces/go_stone_white.tres")
	stone_8.is_locked = false
	stone_8.transform = Transform.IDENTITY
	stone_8.user_scale = Vector3(4.0, 1.0, 4.0)
	stone_8.user_albedo = Color.black
	
	container_7.content_states = [ stone_8 ]
	
	var stack_11 := ContainerState.new()
	stack_11.index_id = 11
	stack_11.scene_entry = null
	stack_11.is_locked = false
	stack_11.transform.basis = Basis.IDENTITY.rotated(Vector3.RIGHT, PI)
	stack_11.transform.origin = Vector3(0.5, 2.5, -5.0)
	stack_11.user_scale = Vector3(5.0, 0.25, 5.0)
	stack_11.user_albedo = Color.white
	
	var token_12 := PieceState.new()
	token_12.index_id = 12
	token_12.scene_entry = preload("res://assets/default_pack/tokens/poker/poker_1.tres")
	token_12.is_locked = false
	token_12.transform = Transform.IDENTITY
	token_12.user_scale = Vector3(20.0, 40.0, 60.0) # Not saved in stack.
	token_12.user_albedo = Color.white
	
	var token_13 := PieceState.new()
	token_13.index_id = 13
	token_13.scene_entry = preload("res://assets/default_pack/tokens/poker/poker_5.tres")
	token_13.is_locked = false
	token_13.transform = Transform.IDENTITY
	token_13.user_scale = Vector3(0.1, 0.2, 0.4) # Not saved in stack.
	token_13.user_albedo = Color.lightgray
	
	var token_14 := PieceState.new()
	token_14.index_id = 14
	token_14.scene_entry = preload("res://assets/default_pack/tokens/poker/poker_10.tres")
	token_14.is_locked = false
	token_14.transform = Transform.IDENTITY
	token_14.user_scale = Vector3.ZERO # Not saved in stack.
	token_14.user_albedo = Color.gray
	
	stack_11.content_states = [ token_12, token_13, token_14 ]
	
	var board_20 := PieceState.new()
	board_20.index_id = 20
	board_20.scene_entry = preload("res://assets/default_pack/boards/chess_board.tres")
	board_20.is_locked = false
	board_20.transform.origin = Vector3(0.0, 10.0, 5.0)
	board_20.user_scale = Vector3(2.0, 1.0, 2.0)
	board_20.user_albedo = Color.white
	
	var speaker_21 := SpeakerState.new()
	speaker_21.index_id = 21
	speaker_21.scene_entry = preload("res://assets/default_pack/speakers/gramophone.tres")
	speaker_21.is_locked = false
	speaker_21.transform.origin = Vector3(200.0, 4.0, -20.0)
	speaker_21.user_scale = Vector3(0.25, 0.25, 0.25)
	speaker_21.user_albedo = Color.white
	speaker_21.is_using_music_bus = true
	speaker_21.is_playing = true
	speaker_21.is_paused = true
	speaker_21.is_positional = false
	speaker_21.playback_position = 25.0
	speaker_21.unit_size = 1.0
	speaker_21.track_entry = preload("res://assets/default_pack/music/kevin_macleod_spy_glass.tres")
	
	container_6.content_states = [ container_7, stack_11, board_20, speaker_21 ]
	
	state_before.piece_states = [ piece_0, speaker_1, timer_2, stack_3,
			container_6 ]
	
	assert_eq(StateSaver.save(STATE_FILE_PATH, state_before), OK)
	var state_after := StateLoader.load(STATE_FILE_PATH)
	assert_not_null(state_after)
	
	assert_eq(state_after.lamp_color, Color.red)
	assert_eq(state_after.lamp_intensity, 2.75)
	assert_eq(state_after.is_lamp_sunlight, false)
	
	assert_eq(state_after.skybox_entry,
			preload("res://assets/default_pack/skyboxes/space.tres"))
	assert_eq(state_after.table_entry,
			preload("res://assets/default_pack/tables/picnic_bench.tres"))
	
	var table_transform := state_after.table_transform
	assert_eq(table_transform.basis, Basis.IDENTITY)
	assert_eq(table_transform.origin, Vector3(50.0, 0.0, 25.0))
	
	assert_eq(state_after.is_table_rigid, false)
	
	# TODO: Use PaintPlane constants.
	paint_image = state_after.table_paint_image
	assert_eq(paint_image.get_width(), 512)
	assert_eq(paint_image.get_height(), 512)
	assert_false(paint_image.has_mipmaps())
	assert_eq(paint_image.get_format(), Image.FORMAT_RGBA8)
	
	var is_image_valid := true
	paint_image.lock()
	for x in range(512):
		for y in range(512):
			var pixel := paint_image.get_pixel(x, y)
			if pixel != Color.pink:
				is_image_valid = false
	paint_image.unlock()
	assert_true(is_image_valid)
	
	assert_eq(state_after.hidden_area_states.size(), 2)
	
	hidden_area_1 = state_after.hidden_area_states[0] as HiddenAreaState
	assert_not_null(hidden_area_1)
	assert_eq(hidden_area_1.index_id, 1)
	assert_eq(hidden_area_1.player_id, 1)
	var hidden_area_transform := hidden_area_1.transform
	assert_true(hidden_area_transform.basis.x.is_equal_approx(Vector3.FORWARD))
	assert_true(hidden_area_transform.basis.y.is_equal_approx(Vector3.UP))
	assert_true(hidden_area_transform.basis.z.is_equal_approx(Vector3.RIGHT))
	assert_eq(hidden_area_transform.origin, Vector3.ZERO)
	
	hidden_area_2 = state_after.hidden_area_states[1] as HiddenAreaState
	assert_not_null(hidden_area_2)
	assert_eq(hidden_area_2.index_id, 2)
	assert_eq(hidden_area_2.player_id, 247344)
	hidden_area_transform = hidden_area_2.transform
	assert_true(hidden_area_transform.basis.x.is_equal_approx(Vector3.BACK))
	assert_true(hidden_area_transform.basis.y.is_equal_approx(Vector3.UP))
	assert_true(hidden_area_transform.basis.z.is_equal_approx(Vector3.LEFT))
	assert_eq(hidden_area_transform.origin, Vector3(0.0, 0.0, -20.0))
	
	assert_eq(state_after.piece_states.size(), 5)
	
	# NOTE: The StateLoader reads in the piece states in a specific order, that
	# is, by type. Hence the following checks being out-of-order.
	container_6 = state_after.piece_states[0] as ContainerState
	assert_not_null(container_6)
	assert_eq(container_6.index_id, 6)
	assert_eq(container_6.scene_entry,
			preload("res://assets/default_pack/containers/pot.tres"))
	assert_false(container_6.is_stack()) # Specific to containers.
	assert_eq(container_6.is_locked, true)
	var container_transform := container_6.transform
	assert_true(container_transform.basis.x.is_equal_approx(Vector3.LEFT))
	assert_true(container_transform.basis.y.is_equal_approx(Vector3.UP))
	assert_true(container_transform.basis.z.is_equal_approx(Vector3.FORWARD))
	assert_eq(container_transform.origin, Vector3(80.0, 4.0, 40.0))
	assert_eq(container_6.user_scale, Vector3(20.0, 20.0, 20.0))
	assert_eq(container_6.user_albedo, Color.green)
	
	assert_eq(container_6.content_states.size(), 4)
	
	container_7 = container_6.content_states[0] as ContainerState
	assert_not_null(container_7)
	assert_eq(container_7.index_id, 7)
	assert_eq(container_7.scene_entry,
			preload("res://assets/default_pack/containers/purse.tres"))
	assert_false(container_7.is_stack()) # Specific to containers.
	assert_eq(container_7.is_locked, false)
	assert_eq(container_7.transform.basis, Basis.IDENTITY)
	assert_eq(container_7.transform.origin, Vector3(128.0, 256.0, -512.0))
	assert_eq(container_7.user_scale, Vector3(10.0, 0.5, 10.0))
	assert_eq(container_7.user_albedo, Color.white)
	
	assert_eq(container_7.content_states.size(), 1)
	
	stone_8 = container_7.content_states[0] as PieceState
	assert_not_null(stone_8)
	assert_eq(stone_8.index_id, 8)
	assert_eq(stone_8.scene_entry,
			preload("res://assets/default_pack/pieces/go_stone_white.tres"))
	assert_eq(stone_8.is_locked, false)
	assert_eq(stone_8.transform, Transform.IDENTITY)
	assert_eq(stone_8.user_scale, Vector3(4.0, 1.0, 4.0))
	assert_eq(stone_8.user_albedo, Color.black)
	
	board_20 = container_6.content_states[1] as PieceState
	assert_not_null(board_20)
	assert_eq(board_20.index_id, 20)
	assert_eq(board_20.scene_entry,
			preload("res://assets/default_pack/boards/chess_board.tres"))
	assert_eq(board_20.is_locked, false)
	assert_eq(board_20.transform.basis, Basis.IDENTITY)
	assert_eq(board_20.transform.origin, Vector3(0.0, 10.0, 5.0))
	assert_eq(board_20.user_scale, Vector3(2.0, 1.0, 2.0))
	assert_eq(board_20.user_albedo, Color.white)
	
	speaker_21 = container_6.content_states[2] as SpeakerState
	assert_not_null(speaker_21)
	assert_eq(speaker_21.index_id, 21)
	assert_eq(speaker_21.scene_entry,
			preload("res://assets/default_pack/speakers/gramophone.tres"))
	assert_eq(speaker_21.is_locked, false)
	assert_eq(speaker_21.transform.basis, Basis.IDENTITY)
	assert_eq(speaker_21.transform.origin, Vector3(200.0, 4.0, -20.0))
	assert_eq(speaker_21.user_scale, Vector3(0.25, 0.25, 0.25))
	assert_eq(speaker_21.user_albedo, Color.white)
	assert_eq(speaker_21.is_using_music_bus, true)
	assert_eq(speaker_21.is_playing, true)
	assert_eq(speaker_21.is_paused, true)
	assert_eq(speaker_21.is_positional, false)
	assert_eq(speaker_21.playback_position, 25.0)
	assert_eq(speaker_21.unit_size, 1.0)
	assert_eq(speaker_21.track_entry,
			preload("res://assets/default_pack/music/kevin_macleod_spy_glass.tres"))
	
	stack_11 = container_6.content_states[3] as ContainerState
	assert_not_null(stack_11)
	assert_eq(stack_11.index_id, 11)
	assert_eq(stack_11.scene_entry, null)
	assert_true(stack_11.is_stack()) # Specific to containers.
	assert_eq(stack_11.is_locked, false)
	var stack_transform := stack_11.transform
	assert_true(stack_transform.basis.x.is_equal_approx(Vector3.RIGHT))
	assert_true(stack_transform.basis.y.is_equal_approx(Vector3.DOWN))
	assert_true(stack_transform.basis.z.is_equal_approx(Vector3.FORWARD))
	assert_eq(stack_transform.origin, Vector3(0.5, 2.5, -5.0))
	assert_eq(stack_11.user_scale, Vector3(5.0, 0.25, 5.0))
	assert_eq(stack_11.user_albedo, Color.white)
	
	assert_eq(stack_11.content_states.size(), 3)
	
	token_12 = stack_11.content_states[0] as PieceState
	assert_not_null(token_12)
	assert_eq(token_12.index_id, -1) # Inside a stack.
	assert_eq(token_12.scene_entry,
			preload("res://assets/default_pack/tokens/poker/poker_1.tres"))
	assert_eq(token_12.is_locked, false)
	assert_eq(token_12.transform, Transform.IDENTITY)
	assert_eq(token_12.user_scale, Vector3.ONE)
	assert_eq(token_12.user_albedo, Color.white)
	
	token_13 = stack_11.content_states[1] as PieceState
	assert_not_null(token_13)
	assert_eq(token_13.index_id, -1) # Inside a stack.
	assert_eq(token_13.scene_entry,
			preload("res://assets/default_pack/tokens/poker/poker_5.tres"))
	assert_eq(token_13.is_locked, false)
	assert_eq(token_13.transform, Transform.IDENTITY)
	assert_eq(token_13.user_scale, Vector3.ONE)
	assert_eq(token_13.user_albedo, Color.lightgray)
	
	token_14 = stack_11.content_states[2] as PieceState
	assert_not_null(token_14)
	assert_eq(token_14.index_id, -1) # Inside a stack.
	assert_eq(token_14.scene_entry,
			preload("res://assets/default_pack/tokens/poker/poker_10.tres"))
	assert_eq(token_14.is_locked, false)
	assert_eq(token_14.transform, Transform.IDENTITY)
	assert_eq(token_14.user_scale, Vector3.ONE)
	assert_eq(token_14.user_albedo, Color.gray)
	
	piece_0 = state_after.piece_states[1] as PieceState
	assert_not_null(piece_0)
	assert_eq(piece_0.index_id, 0)
	assert_eq(piece_0.scene_entry,
			preload("res://assets/default_pack/pieces/chess_knight_black.tres"))
	assert_eq(piece_0.is_locked, false)
	assert_eq(piece_0.transform.basis, Basis.IDENTITY)
	assert_eq(piece_0.transform.origin, Vector3(0.0, 100.0, 5.0))
	assert_eq(piece_0.user_scale, Vector3.ONE)
	assert_eq(piece_0.user_albedo, Color.blue)
	
	speaker_1 = state_after.piece_states[2] as SpeakerState
	assert_not_null(speaker_1)
	assert_eq(speaker_1.index_id, 1)
	assert_eq(speaker_1.scene_entry,
			preload("res://assets/default_pack/speakers/gramophone.tres"))
	assert_eq(speaker_1.is_locked, true)
	assert_eq(speaker_1.transform.basis, Basis.IDENTITY)
	assert_eq(speaker_1.transform.origin, Vector3(100.0, 20.0, 0.0))
	assert_eq(speaker_1.user_scale, Vector3(5.0, 1.0, 1.0))
	assert_eq(speaker_1.user_albedo, Color.white)
	assert_eq(speaker_1.is_using_music_bus, true)
	assert_eq(speaker_1.is_playing, true)
	assert_eq(speaker_1.is_paused, false)
	assert_eq(speaker_1.is_positional, false)
	assert_eq(speaker_1.playback_position, 10.0)
	assert_eq(speaker_1.unit_size, 2.0)
	assert_eq(speaker_1.track_entry,
			preload("res://assets/default_pack/music/kevin_macleod_in_your_arms.tres"))
	
	stack_3 = state_after.piece_states[3] as ContainerState
	assert_not_null(stack_3)
	assert_eq(stack_3.index_id, 3)
	assert_eq(stack_3.scene_entry, null)
	assert_true(stack_3.is_stack()) # Specific to containers.
	assert_eq(stack_3.is_locked, true)
	stack_transform = stack_3.transform
	assert_true(stack_transform.basis.x.is_equal_approx(Vector3.DOWN))
	assert_true(stack_transform.basis.y.is_equal_approx(Vector3.RIGHT))
	assert_true(stack_transform.basis.z.is_equal_approx(Vector3.BACK))
	assert_eq(stack_transform.origin, Vector3(0.0, 0.5, 5.0))
	assert_eq(stack_3.user_scale, Vector3(6.0, 1.0, 8.0))
	assert_eq(stack_3.user_albedo, Color.white)
	
	assert_eq(stack_3.content_states.size(), 2)
	
	card_4 = stack_3.content_states[0] as PieceState
	assert_not_null(card_4)
	assert_eq(card_4.index_id, -1) # In a stack.
	assert_eq(card_4.scene_entry,
			preload("res://assets/default_pack/cards/spades_01.tres"))
	assert_eq(card_4.is_locked, false)
	assert_eq(card_4.transform, Transform.IDENTITY)
	assert_eq(card_4.user_scale, Vector3.ONE) # In a stack.
	assert_eq(card_4.user_albedo, Color.gray)
	
	card_5 = stack_3.content_states[1] as PieceState
	assert_not_null(card_5)
	assert_eq(card_5.index_id, -1) # In a stack.
	assert_eq(card_5.scene_entry,
			preload("res://assets/default_pack/cards/hearts_02.tres"))
	assert_eq(card_5.is_locked, false)
	var card_transform := card_5.transform
	assert_true(card_transform.basis.x.is_equal_approx(Vector3.LEFT))
	assert_true(card_transform.basis.y.is_equal_approx(Vector3.DOWN))
	assert_true(card_transform.basis.z.is_equal_approx(Vector3.BACK))
	assert_eq(card_transform.origin, Vector3.ZERO)
	assert_eq(card_5.user_scale, Vector3.ONE) # In a stack.
	assert_eq(card_5.user_albedo, Color.white)
	
	timer_2 = state_after.piece_states[4] as TimerState
	assert_not_null(timer_2)
	assert_eq(timer_2.index_id, 2)
	assert_eq(timer_2.scene_entry,
			preload("res://assets/default_pack/timers/radio.tres"))
	assert_eq(timer_2.is_locked, true)
	var timer_transform := timer_2.transform
	assert_true(timer_transform.basis.x.is_equal_approx(Vector3.BACK))
	assert_true(timer_transform.basis.y.is_equal_approx(Vector3.UP))
	assert_true(timer_transform.basis.z.is_equal_approx(Vector3.LEFT))
	assert_eq(timer_transform.origin, Vector3(-50.0, 10.0, 0.0))
	assert_eq(timer_2.user_scale, Vector3(1.5, 1.5, 1.5))
	assert_eq(timer_2.user_albedo, Color.yellow)
	assert_eq(timer_2.is_using_music_bus, false)
	assert_eq(timer_2.is_playing, false)
	assert_eq(timer_2.is_paused, false)
	assert_eq(timer_2.is_positional, true)
	assert_eq(timer_2.playback_position, 0.0)
	assert_eq(timer_2.unit_size, 5.0)
	assert_eq(timer_2.track_entry,
			preload("res://assets/default_pack/sounds/alarm.tres"))
	assert_eq(timer_2.is_timer_paused, true)
	assert_eq(timer_2.timer_mode, 1) # TODO: Replace with STOPWATCH.
	assert_true(is_equal_approx(timer_2.timer_time, 69.420))
	
	# Clean the left-over state file.
	var user_dir := Directory.new()
	user_dir.remove(STATE_FILE_PATH)
	assert_file_does_not_exist(STATE_FILE_PATH)
