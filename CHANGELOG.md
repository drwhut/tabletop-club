# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- Updated Godot WebRTC library from v0.5 to v1.1.0.
- Updated the lobby server's SSL certificate.

## [0.1.3] - 2024-09-04

### Added

- The value of die faces can now be text, as well as numbers. (#209)
- Added a "Donate" button to the main menu that opens `ko-fi.com/drwhut` in the
  default browser.
- Added Brazilian Portuguese as a playable language!

### Changed

- The format of the `face_values` property has changed from `VALUE: ROTATION` to
  `ROTATION: VALUE`, allowing for multiple faces of a die to have the same
  value.
- Updated documentation domain from `tabletop-club.readthedocs.io` to
  `docs.tabletopclub.net`.
- Replaced the "itch.io" button on the main menu with a "Website" button that
  opens `tabletopclub.net` in the default browser.
- Combined the "Discord" and "Matrix" buttons on the main menu into one
  "Community" button that opens `tabletopclub.net/community` in the default
  browser.
- Updated the master server's URL and SSL certificate.
- Updated the documentation.
- Updated translations from the community.

### Removed

- The AssetDB no longer requires that the `face_values` property has the same
  number of elements as the number of faces on the die.

## [0.1.2] - 2023-09-05

### Changed

- Updated the master server's SSL certificate.

## [0.1.1] - 2023-06-06

### Added

- Added Chinese (Simplified), Polish as playable languages!

### Changed

- All links to the documentation now go to the stable version by default, rather
  than the latest version.
- The game will not longer allow stacks containing only one item to be made in
  the `stacks.cfg` file.
- Updated translations from the community.
- Object metadata shown in tooltips in the objects menu is now truncated if it
  is too long.

### Fixed

- Fixed an escape character error in the description of the music track "Lobby
  Time - Kevin MacLeod".
- Viewing the stable version of the documentation now shows the correct version
  instead of "master" in the title.
- Fixed non-ASCII characters not displaying in error and warning messages in the
  import log.

## [0.1.0] - 2023-04-29

### Added 

- Tabletop Club has been released! \o/

[unreleased]: https://github.com/drwhut/tabletop-club/compare/v0.1.3...HEAD
[0.1.3]: https://github.com/drwhut/tabletop-club/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/drwhut/tabletop-club/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/drwhut/tabletop-club/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/drwhut/tabletop-club/releases/tag/v0.1.0
