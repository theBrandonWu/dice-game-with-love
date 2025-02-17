# Changelog
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [0.1.8] - 2025-02-17
### Added
- Enhanced combat feedback system
  - Visual attack line from attacker to defender
  - Damage numbers shown above defender
  - Persistent combat logs for each player
  - Semi-transparent background for better log visibility

### Changed
- Combat effects now last 0.75 seconds (50% longer)
- Combat logs stay visible until next combat by same player
- Combat logs positioned on respective player sides

### Fixed
- Heart pickup now properly triggers before combat
- Fixed combat log visibility issues
- Improved code organization and maintainability

## [0.1.7] - 2025-02-13
### Changed
- Simplified dice rolling animation by removing rotation and scaling effects
- Made dice rolling animation consistent between normal rolls and heart pickup rolls
- updated board position 

### Added
- dice info below player info

## [0.1.6] - 2025-02-12
### Added
- Win condition when player HP reaches 0
- Game over screen with winner announcement
- Ability to restart game by pressing SPACE
- Separate board initialization function for proper game reset

## [0.1.5] - 2025-02-12
### Changed
- Improved movement tile highlighting to show yellow borders instead of fill
- Combat now only triggers when finishing movement phase
- Added detailed combat logs with damage calculations

## [0.1.4] - 2025-02-12
### Added
- Automatic combat when moving next to enemy
- Tile-based combat modifiers
- Combat damage calculation logging

### Changed
- Increased movement tile highlight opacity to 50%
- Added character collision prevention
- Improved combat feedback with detailed logs

## [0.1.3] - 2025-02-12
### Fixed
- Fixed hex coordinate conversion for accurate tile clicking
- Improved movement validation using proper axial distance calculation
- Added debug information for movement system

## [0.1.2] - 2025-02-12
### Added
- Movement system implementation
  - Visual highlighting of valid movement tiles
  - Click-to-move functionality
  - Automatic phase transitions
- Game phase system (assign, move, attack, defense)
- Improved dice assignment tracking

## [0.1.1] - 2025-02-10
### Added
- Two-player battle system with hexagonal grid
- Three dice per player with different actions (movement, attack, defense)
- Drag-and-drop system for assigning dice to actions
  - Visual feedback when dragging dice
  - Ability to swap dice between slots
  - Ability to swap between slotted and unslotted dice
- Turn-based gameplay with confirm button
- Different tile types (normal, attack, defense)
- Player health system (21 HP per player)
- Visual indicators
  - Current player turn
  - Player health
  - Action slots (movement, attack, defense)
  - Confirm button when all dice are assigned

### Changed
- Improved dice rotation animation
- Repositioned confirm button for better usability
- Updated game rules and mechanics
- Fixed dice number preservation when swapping between slots

## [0.1.0] - 2025-02-10
### Added
- Initial game setup with Love2D framework
- Basic dice rolling mechanics with 5 dice
- Visual representation of dice with dots
- Physics-based rolling animation
  - Gravity and bouncing effects
  - Rotation during rolls
  - Dynamic scaling effects
  - Smooth transitions between dice faces
- Game features
  - 3 rolls per game
  - Score calculation
  - Reset functionality
- Basic UI elements
  - Roll counter
  - Score display
  - Game instructions
