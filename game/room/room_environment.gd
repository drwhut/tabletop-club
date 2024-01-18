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
	
	GameConfig.connect("applying_settings", self,
			"_on_GameConfig_applying_settings")


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


func _on_GameConfig_applying_settings():
	var radiance_size := Sky.RADIANCE_SIZE_128
	
	match GameConfig.video_skybox_radiance_detail:
		GameConfig.RADIANCE_LOW:
			radiance_size = Sky.RADIANCE_SIZE_128
		GameConfig.RADIANCE_MEDIUM:
			radiance_size = Sky.RADIANCE_SIZE_256
		GameConfig.RADIANCE_HIGH:
			radiance_size = Sky.RADIANCE_SIZE_512
		GameConfig.RADIANCE_VERY_HIGH:
			radiance_size = Sky.RADIANCE_SIZE_1024
		GameConfig.RADIANCE_ULTRA:
			radiance_size = Sky.RADIANCE_SIZE_2048
	
	environment.background_sky.radiance_size = radiance_size
	
	var ssao_enabled := true
	var ssao_quality := Environment.SSAO_QUALITY_LOW
	
	match GameConfig.video_ssao:
		GameConfig.SSAO_NONE:
			ssao_enabled = false
		GameConfig.SSAO_LOW:
			ssao_quality = Environment.SSAO_QUALITY_LOW
		GameConfig.SSAO_MEDIUM:
			ssao_quality = Environment.SSAO_QUALITY_MEDIUM
		GameConfig.SSAO_HIGH:
			ssao_quality = Environment.SSAO_QUALITY_HIGH
	
	environment.ssao_enabled = ssao_enabled
	environment.ssao_quality = ssao_quality
	
	var dof_enabled := true
	var dof_quality := Environment.DOF_BLUR_QUALITY_LOW
	
	match GameConfig.video_depth_of_field:
		0:
			dof_enabled = false
		1:
			dof_quality = Environment.DOF_BLUR_QUALITY_LOW
		2:
			dof_quality = Environment.DOF_BLUR_QUALITY_MEDIUM
		3:
			dof_quality = Environment.DOF_BLUR_QUALITY_HIGH
	
	var dof_amount := 0.1 * GameConfig.video_depth_of_field_amount
	var dof_distance := 15.0 + 85.0 * GameConfig.video_depth_of_field_distance
	
	environment.dof_blur_far_amount = dof_amount
	environment.dof_blur_far_distance = dof_distance
	environment.dof_blur_far_enabled = dof_enabled
	environment.dof_blur_far_quality = dof_quality
	environment.dof_blur_far_transition = 10.0
	
	environment.dof_blur_near_amount = dof_amount
	environment.dof_blur_near_distance = 5.0
	environment.dof_blur_near_enabled = dof_enabled
	environment.dof_blur_near_quality = dof_quality
	environment.dof_blur_near_transition = 1.0
	
	environment.adjustment_brightness = GameConfig.video_brightness
	environment.adjustment_contrast = GameConfig.video_contrast
	environment.adjustment_saturation = GameConfig.video_saturation
	
	environment.adjustment_enabled = (GameConfig.video_brightness != 1.0) or \
			(GameConfig.video_contrast != 1.0) or \
			(GameConfig.video_saturation != 1.0)
