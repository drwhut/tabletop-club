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

extends Spatial

onready var _mesh_instance = $MeshInstance
onready var _texture_rect = $Viewport/TextureRect
onready var _viewport = $Viewport

const PAINT_FORMAT = Image.FORMAT_RGBA8

var _paint_queue = []
var _painted_last_frame = false

# Clear the paint texture.
func clear_paint() -> void:
	var image = Image.new()
	var image_size = get_paint_size()
	image.create(image_size.x, image_size.y, false, PAINT_FORMAT)
	image.fill(Color.transparent)
	set_paint(image)
	
	_paint_queue.clear()

# Get the current paint texture image.
# Returns: The current image.
func get_paint() -> Image:
	return _texture_rect.texture.get_data()

# Get the paint image size.
# Returns: The paint image size.
func get_paint_size() -> Vector2:
	if _viewport == null:
		return Vector2.ZERO
	return _viewport.size

# Set if the paint texture is filtered.
# filtering_enabled: If texture filtering is enabled.
func set_filtering_enabled(filtering_enabled: bool) -> void:
	if _mesh_instance == null:
		return
	var mesh_material = _mesh_instance.get_surface_material(0)
	mesh_material.set_shader_param("FilteringEnabled", filtering_enabled)

# Set the current paint texture from the given image.
# image: The image to set as the new paint texture.
func set_paint(image: Image) -> void:
	if _texture_rect == null:
		return
	
	var texture = ImageTexture.new()
	texture.create_from_image(image)
	_texture_rect.texture = texture

# Push a paint command to the paint queue.
# pos1: The initial global position to paint from.
# pos2: The final global position to paint to.
# color: The color to paint.
# size: The size of the paint.
remotesync func push_paint_queue(pos1: Vector3, pos2: Vector3, color: Color, size: float) -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	var uv1_x = pos1.x / scale.x + 0.5
	var uv1_z = pos1.z / scale.z + 0.5
	var uv2_x = pos2.x / scale.x + 0.5
	var uv2_z = pos2.z / scale.z + 0.5
	
	# Assuming the viewport is square.
	var unit_size = 1.0 / _viewport.size.x
	var adjusted_size = size * unit_size
	
	_paint_queue.push_back({
		"color": color,
		"pos1": Vector2(uv1_x, uv1_z),
		"pos2": Vector2(uv2_x, uv2_z),
		"size": adjusted_size
	})

# Request the server to clear the paint.
master func request_clear_paint() -> void:
	rpc("clear_paint_rpc")

# Called by the server to clear the paint.
remotesync func clear_paint_rpc() -> void:
	if get_tree().get_rpc_sender_id() != 1:
		return
	
	clear_paint()

# Request the server to add a paint command to the paint queue.
# pos1: The initial global position to paint from.
# pos2: The final global position to paint to.
# color: The color to paint.
# size: The size of the paint.
master func request_push_paint_queue(pos1: Vector3, pos2: Vector3, color: Color, size: float) -> void:
	rpc_unreliable("push_paint_queue", pos1, pos2, color, size)

func _ready():
	var image_size = get_paint_size()
	_texture_rect.rect_size = image_size
	
	var inverse_aspect_ratio = scale.z / scale.x
	var pixel_size = Vector2(inverse_aspect_ratio / image_size.x, 1.0 / image_size.y)
	var mesh_material = _mesh_instance.get_surface_material(0)
	mesh_material.set_shader_param("TexturePixelSize", pixel_size)
	
	clear_paint()

func _process(_delta):
	if _painted_last_frame:
		# TODO: This call is very costly - is there a way to avoid saving the
		# image potentially every frame? Would it actually be faster to draw
		# on the image on the CPU side? (CanvasItem?)
		_save_viewport_texture()
		_texture_rect.material.set_shader_param("BrushEnabled", false)
	_painted_last_frame = false
	
	if not _paint_queue.empty():
		var command = _paint_queue.pop_front()
		
		if scale.x == 0.0 or scale.z == 0.0:
			return
		
		var aspect_ratio = scale.x / scale.z
		_texture_rect.material.set_shader_param("AspectRatio", aspect_ratio)
		
		var color: Color = command["color"]
		_texture_rect.material.set_shader_param("BrushColor", color)
		_texture_rect.material.set_shader_param("BrushEnabled", true)
		
		var pos1: Vector2 = command["pos1"]
		var pos2: Vector2 = command["pos2"]
		_texture_rect.material.set_shader_param("BrushPosition", pos2)
		
		var size: float = command["size"]
		_texture_rect.material.set_shader_param("BrushSize", size)
		
		# Perform some calculations on the CPU side to save time on the GPU.
		# These calculations are consistent for every pixel.
		var brush_vec = (pos2 - pos1).normalized()
		var perpendicular = Vector2(-brush_vec.y, brush_vec.x)
		var to_corner = size * perpendicular
		to_corner.x /= aspect_ratio
		
		# Three corners of a parallelogram representing the fill-in line.
		var a = pos1 + to_corner
		var ab = -2.0 * to_corner
		var ad = pos2 - pos1
		
		var inverse_col_1 = Vector2.ZERO
		var inverse_col_2 = Vector2.ZERO
		
		var det = ab.x * ad.y - ad.x * ab.y
		if det != 0.0:
			inverse_col_1 = (1.0 / det) * Vector2(ad.y, -ab.y)
			inverse_col_2 = (1.0 / det) * Vector2(-ad.x, ab.x)
		
		_texture_rect.material.set_shader_param("InverseQuadCol1", inverse_col_1)
		_texture_rect.material.set_shader_param("InverseQuadCol2", inverse_col_2)
		_texture_rect.material.set_shader_param("QuadCorner", a)
		
		_painted_last_frame = true

# Save the current viewport texture as the new paint texture.
func _save_viewport_texture() -> void:
	var image = _viewport.get_texture().get_data()
	set_paint(image)
