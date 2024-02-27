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
- Both 'Picnic Bench' and 'Table' are now textured.

#### Commands

- Added the `/say` command, which sends a public message to all players in the
  current room. This is the same behaviour as entering a normal message in the
  chat window.

#### Controls

- Added new bindings for rotating the camera up, down, left, and right. By
  default these are bound to the arrow keys.
- Bindings can now be removed by holding the Escape key while they are being
  set.
- "Mouse Wheel Up" and "Mouse Wheel Down" are now shown as editable bindings for
  "Zoom In / Lift Down" and "Zoom Out / Lift Up" respectively.
- Added the "Start Message" binding (bound to the Enter key by default), which
  will bring the chat window in focus to allow the player to start typing a
  message, as long as there are no other UI elements currently in focus.
- Added the "Start Command" binding (bound to the forward slash key by default),
  which will bring the chat window in focus and automatically insert a forward
  slash character so the player can start typing in a command.

#### Documentation

- Added icon links to various websites for the project.

#### Graphics

- Added the Fast Approximate Anti-Aliasing (FXAA) algorithm, which is now the
  default for players launching the game for the first time.
- Added sliders that can change the brightness, contrast, and saturation of the
  rendered scene in the options menu, under the "Video" section.
- Added quality presets for advanced graphics settings in the options menu: Low,
  Medium, High, Very High, and Ultra. The default for new players is Medium.
- Added a toggle for showing advanced graphics settings in the options menu.

#### Multiplayer

- Can now host multiplayer lobbies in "Direct Connection" mode, which allows
  clients to join using the host's IP address instead of a room code, removing
  the need to connect to the master server. (#225)

#### Options

- When reading the system's language, if it is a variant of a language that is
  already supported by the game, the game will use the supported language
  instead of reverting to English. For example, if the system is set to Austrian
  German (`de_AT`), the game will use German (`de`) instead of English.
- Sliders in the options menu now display their values.
- In the options menu, a preview has been added showing what the player's name
  and colour will look like on the player list in the top-right corner.
- A warning is now shown when attempting to set an invalid player name in the
  options menu.
- Added a slider that can change the scale of the user interface in the options
  menu, under the "Video" section. (#290)
- Added a new dialog for when the player is about to leave the options menu with
  new settings that have not been applied.
- A countdown has been added to the dialog that appears when video settings have
  been changed, which will revert the changes automatically if it runs out.

#### Project

- Added unit tests for various in-game systems using Gut v7.4.1 (#153)
- Added a fallback directory in `user://` in the event that the player's
  Documents folder could not be opened.
- Optimised the look-up algorithm for certain node structures, which should lead
  to better performance when there are many dynamic objects in play.

#### UI

- Added a fade-in effect for the main menu when the game first loads.
- Added full controller support. (#100)
- Added graphs to the debug screen showing both the frame delta, and the physics
  frame delta, over time.
- When typing a message in the chat window, the up and down arrow keys will now
  display the player's message history from that session.
- When clicking on a blank space while in-game, the game will automatically
  release the focus from any UI elements that have it at the time.
- Added more information about the connection process to the multiplayer window.
- When entering a room code, up and down arrow buttons have been added to cycle
  through the alphabet, in addition to using the keyboard to type the code in.
- Added a checkbox to the multiplayer window that hides the room code before
  entering the game.

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
- The collision shapes of the following objects have been simplified:
  'Chess Board', 'Bishop', 'King', 'Knight', 'Pawn', 'Picnic Bench', 'Pot',
  'Purse', 'Queen', 'Radio', 'Rook', 'Table'.
- The centre-of-mass of the following objects have been adjusted: 'Purse',
  'Gramophone', 'Radio'.

#### Controls

- Up to two keyboard and mouse bindings can be set per action now, instead of
  just one.
- Keyboard and controller bindings are now only stored if they are changed from
  their default values. This means that if the default value changes in a future
  version of the game, and you have not explicitly set a binding for a specific
  action, that action's binding will change to the new default.
- When changing a binding, instead of a dialog pop-up being shown, the binding's
  text simply changes to indicate it is waiting for a button press.

#### Documentation

- Updated `sphinx` from v4.5.0 to v7.2.6.
- Updated `sphinx-book-theme` from v0.3.2 to v1.1.2.
- Updated `sphinx-intl` from v2.0.1 to v2.1.0.
- The default number of levels shown by default in the contents navigation bar
  has been increased from one to two.

#### Graphics

- Restarting is no longer required to see the effects of changing the "Shadow
  Detail" level.

#### Multiplayer

- Updated the Godot WebRTC library from v0.5 to v1.0.5.
- Optimised the number of connections established between peers when using
  WebRTC.
- Lobbies will now continue if the connection to the master server is lost, but
  players will not be able to join the lobby anymore.

#### Options

- The "Effects Volume" option is now called "Object Volume" to better reflect
  its function.
- The "Multiplayer" tab in the options menu has been renamed to "Player".
- Hints for properties in the options menu are now shown in a dedicated label
  rather than in tooltips.
- Slightly adjusted the hints for properties in the options menu.
- The "Chat Font Size" option is now called "Chat Window Font Size", and has
  been moved to the "General" tab from the "Multiplayer" tab.
- "Skybox Radiance Detail" has been renamed to "Skybox Lighting Detail" in the
  options menu.
- The "Key Bindings" tab in the options menu has been removed in favour of a
  separate menu under the "Controls" tab.

#### Project

- Updated the Godot Engine from 3.4.5-stable to 3.5.2-stable.
- Updated the custom module to be more flexible in how files are imported.
- Replaced the physics frame interpolation patch with the engine-provided
  implementation.
- Changed the project's directory structure in order to comply with Godot
  conventions.
- System errors and warnings are no longer shown twice in the logs.

#### Tools

- Optimised the performance of the paint and erase tools.
- The appearance of hidden areas is now animated.

#### UI

- Changed the default window size from 1024x600 to 1920x1080.
- The importing process is now shown as an independent panel in the main menu
  instead of within the loading screen.
- Increased the font size of text on the loading screen.
- The main menu music will now fade out gradually when entering the game,
  instead of ending abruptly.
- Updated the layout of the main menu and the options menu.
- The 'Park' skybox is now the only default skybox, meaning that there is no
  longer a chance for the 'Park Winter' skybox to appear in the main menu.
- The game room is now loaded alongside the main menu, removing the need for a
  loading screen when entering singleplayer or multiplayer.
- The in-game menu screen now uses the same layout as the main menu.
- The appearance of the player list has been significantly improved.
- The colour pickers used throughout the UI have been replaced with colour
  sliders, which can be switched between two modes: HSV and RGB.
- Renamed the "Contributors" section in the credits to "Code Contributors".
- Increased the font size of the text in the debug screen.
- Optimised certain operations on the chat log.
- Improved the appearance of the chat window.
- The chat window is now also shown in the main menu, as well as in-game.
- The chat window will now become transparent when the mouse is being used
  somewhere else in the game.
- Improved the dialog that appears when attempting to run the game with a build
  of Godot that does not include the custom module.
- The game will now remember the last room code that was entered after the
  client successfully joins a multiplayer lobby.
- When attempting to host or join a multiplayer lobby, the attempt is now done
  in the main menu instead of in-game.
- Updated error messages related to the multiplayer network. In some cases,
  errors are now followed up with advice on how to solve the issue.

### Fixed

#### Assets

- Objects inside of stacks will now retain their custom colour after reloading
  a previous save.
- An object's centre-of-mass will no longer change when the object is scaled.

#### Multiplayer

- Fixed the game client not detecting when the connection to the master server
  has been lost silently.
- Fixed the game client not detecting when the connection to another client has
  been lost silently.
- Fixed the game client not detecting when a connection to the host, or to a
  client joining the room, was not able to be established.

#### Project

- Fixed a crash when attempting to run the game on macOS with a system using the
  `arm64` architecture.

#### UI

- Fixed some labels not being added to the translation template file, which was
  preventing them from being able to be translated by contributors.

### Removed

#### Assets

- Removed the `--base-asset-dir` command-line argument, as it is no longer
  required.
- The Downloads, Desktop, and installation folders are no longer scanned for
  asset packs.
- Removed the `--export-asset-db` command-line argument.
- The following properties are no longer used in configuration files: `default`,
  `main_menu`.

#### Documentation

- Removed the text title below the project logo.

#### UI

- The randomly selected pieces that were falling in the background of the main
  menu have been removed.
- The "Video Adapter" and "Physics Objects" values have been removed from the
  debug screen, as they currently do not work correctly in the engine.
- The "Send" button has been removed from the chat window.
- The import log has been removed from the main menu, as the chat window (which
  displays errors and warnings generated by assets) is now shown in the main
  menu.

[unreleased]: https://github.com/drwhut/tabletop-club/compare/HEAD...HEAD
