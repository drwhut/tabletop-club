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

class_name PaintPlane
extends MeshInstance

## The plane that displays the contents of the paint viewport in 3D space.


## The viewport that displays the paint image.
var paint_viewport: Viewport = \
		preload("res://room/paint_viewport.tscn").instance()


func _init():
	add_child(paint_viewport)
	
	var plane_mesh := PlaneMesh.new()
	plane_mesh.size = Vector2.ONE
	mesh = plane_mesh


func _ready():
	# NOTE: This section of code is why this is a class rather than a scene,
	# because otherwise errors would be thrown when the material tries to
	# set the viewport texture before entering the scene tree.
	var material := SpatialMaterial.new()
	material.flags_transparent = true
	material.albedo_texture = paint_viewport.get_texture()
	
	set_surface_material(0, material)
	
	GameConfig.connect("applying_settings", self,
			"_on_GameConfig_applying_settings")


func _on_GameConfig_applying_settings():
	var material: SpatialMaterial = get_surface_material(0)
	var viewport_texture: ViewportTexture = material.albedo_texture
	
	# Take the default flags, and remove the filter flag...
	var new_flags := viewport_texture.flags & (~Texture.FLAG_FILTER)
	
	# ... only add it back in if the GameConfig property is true.
	if GameConfig.video_table_paint_filtering:
		new_flags |= Texture.FLAG_FILTER
	
	viewport_texture.flags = new_flags
