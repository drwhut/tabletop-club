# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

#### Assets

- A look-up cache has been implemented into the AssetDB, which should lead to
  increased performance when searching for specific assets.
- A new 'tagging' system has been added for the internal `user://` directory,
  which is more robust against missing files.
- Can now use the `?` wildcard in section names of `config.cfg` files, which
  will match one and only one character.
- The value of die faces can now be text, as well as numbers. (#209)
- Can now use the normal vector of a die face when setting its value, instead of
  the X and Z rotation needed to make the face point upwards.

#### Project

- Added unit tests for various in-game systems using Gut v7.4.1 (#153)
- Added a fallback directory in `user://` in the event that the player's
  Documents folder could not be opened.

### Changed

#### Assets

- The AssetDB now stores entries as resources instead of JSON-like dictionaries,
  which allows for increased type safety and internal data validation.
- The way temporary entries in the AssetDB (that is, entries that are provided
  by a multiplayer host) are stored in memory has been optimised.
- The `*` wildcard can now be used in the middle of section names in
  `config.cfg` files, rather than just at the beginning and end.
- The format of the `face_values` property has changed from `VALUE: ROTATION` to
  `ROTATION: VALUE`, allowing for multiple faces of a die to have the same
  value.
- Custom assets are now imported after the main menu has loaded, instead of
  before. This should lead to faster and more consistent loading times,
  regardless of the number of custom assets.
- The 'TabletopClub' asset pack that comes bundled with the game is now
  pre-imported inside the `.pck` file instead of in its own directory. The pack
  no longer has to be imported every launch.
- All textures within the 'TabletopClub' asset pack are now bundled in a
  compressed format, leading to less video memory usage.

#### Project

- Updated the Godot Engine from 3.4.5-stable to 3.5.2-stable.
- Updated the custom module to be more flexible in how files are imported.
- Replaced the physics frame interpolation patch with the engine-provided
  implementation.
- Switched the default VRAM compression algorithm from ETC to ETC2.
- Changed the project's directory structure in order to comply with Godot
  conventions.

#### UI

- Changed the default window size from 1024x600 to 1920x1080.
- The importing process is now shown as an independent panel instead of within
  the loading screen.

### Removed

#### Assets

- Removed the `--base-asset-dir` command-line argument, as it is no longer
  required.
- The Downloads, Desktop, and installation folders are no longer scanned for
  asset packs.
- Removed the `--export-asset-db` command-line argument.

[unreleased]: https://github.com/drwhut/tabletop-club/compare/HEAD...HEAD
