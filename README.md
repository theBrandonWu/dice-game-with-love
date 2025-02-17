# Die Die Dice
a Local, Hotseat, 1v1 Battle Dice Game

![Screenshot 2025-02-17 at 21 02 24](https://github.com/user-attachments/assets/01c0a80e-2ab8-4500-9d4d-564815574665)

A tactical dice-based combat game created with LÖVE (Love2D) framework.

## How to Run

``open -n -a love .``
or
``love .``

## Requirements

- LÖVE (Love2D) framework

## Gameplay Rules

### Game Setup
- 2 players start at opposite corners of a hexagonal grid
- Each player begins with 21 HP
- Board contains three tile types:
  - Normal tiles (gray)
  - Attack tiles (red) - 50% damage bonus
  - Defense tiles (green) - 50% defense bonus
- Hearts spawn randomly on the board for healing

### Turn Structure
1. **Dice Rolling Phase**
   - Press SPACE to roll three dice
   - Each die shows a value from 1 to 6

2. **Dice Assignment Phase**
   - Drag each die to one of three slots:
     - Movement (M)
     - Attack (A)
     - Defense (D)
   - Each slot must receive exactly one die
   - Values cannot be changed after assignment

3. **Movement Phase**
   - Move up to the number of hexes shown on Movement die
   - Valid moves are highlighted in yellow
   - Can only move to adjacent hexes
   - Cannot move through or onto opponent's position
   - Click Reset button to return to starting position
   - Click Finish button when done moving

### Combat Rules
1. **Initiating Combat**
   - Combat triggers automatically when ending movement adjacent to opponent
   - Attacker uses their Attack die value
   - Defender uses their Defense die value

2. **Damage Calculation**
   - Base damage = Attack value
   - Base defense = Defense value
   - Attack tiles provide 50% damage bonus
   - Defense tiles provide 50% defense bonus
   - Final damage = (Attack ± bonus) - (Defense ± bonus)
   - Minimum damage is 0

3. **Combat Feedback**
   - Red line shows attack direction
   - Damage number appears above defender
   - Combat log shows detailed calculations
   - Logs persist until player's next combat

### Heart Pickup Rules
1. **Triggering Pickup**
   - Move onto a heart tile
   - Takes priority over combat
   - Automatically rolls healing die

2. **Healing**
   - Healing amount = Die roll + 3
   - New heart spawns after pickup
   - Maximum 2 hearts on board

### Game End
- Game ends when a player's HP reaches 0
- Winner is the last player with HP remaining
- Press SPACE to start new game

### Additional Rules
- Last turn's dice values (M/A/D) are shown below player HP
- Combat and healing effects must complete before turn changes
- Players can see both combat logs simultaneously
- Each player's combat log stays on their side of the screen
