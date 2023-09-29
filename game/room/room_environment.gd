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

class_name RoomEnvironment
extends WorldEnvironment

## The environment used for the game room.
##
## Note that in order for this node to function properly, an environment needs
## to be set. This can be the default environment resource.


## The starting skybox to use when the game first loads, in the form of its
## asset entry.
## TODO: Make typed in 4.x.
export(Resource) var default_skybox = null

## If set, [member default_skybox] is used to set the current environment's
## skybox upon the node being ready. This can be set to false if the default
## environment already uses the desired skybox.
export(bool) var set_skybox_on_ready := false


func _ready():
	if default_skybox is AssetEntrySkybox:
		if set_skybox_on_ready:
			set_skybox(default_skybox)
	else:
		push_error("'default_skybox' is not of type AssetEntrySkybox")


## Set the room's skybox using its entry.
func set_skybox(skybox_entry: AssetEntrySkybox) -> void:
	var skybox_texture := skybox_entry.load_skybox_texture()
	if skybox_texture != null:
		var panorama_sky := PanoramaSky.new()
		panorama_sky.panorama = skybox_texture
		environment.background_sky = panorama_sky
	else:
		push_error("Failed to load texture for skybox '%s'" % skybox_entry.get_path())
		environment.background_sky = ProceduralSky.new()
	
	environment.background_energy = skybox_entry.energy
	environment.background_sky_rotation = skybox_entry.rotation
