-- Battle Dice Game

-- Constants
local GRID_SIZE = 6
local HEX_SIZE = 40
local WINDOW_WIDTH = 1024
local WINDOW_HEIGHT = 768
local DICE_SIZE = 60
local DICE_SPACING = 80
local PLAYER_COLORS = {{0, 0.7, 1}, {1, 0.3, 0.3}} -- Blue and Red
local TILE_TYPES = {"normal", "attack", "defense"}

-- Game state
local gameState = {
    currentPlayer = 1,
    combatLog = {},
    combatEffects = {
        active = false,
        timer = 0,
        duration = 0.75, -- Increased by 50%
        damage = 0,
        attackerPos = nil,
        defenderPos = nil,
        player1Log = {}, -- Combat log for player 1
        player2Log = {}, -- Combat log for player 2
    },
    dice = {1, 1, 1},
    isRolling = false,
    rollTimer = 0,
    rollDuration = 1.0,
    draggedDie = nil,
    draggedSlot = nil,  -- Track if we're dragging from a slot
    dragX = 0,
    dragY = 0,
    diceAssignments = {nil, nil, nil}, -- Tracks which slot each die is assigned to (1=movement, 2=attack, 3=defense)
    showConfirm = false, -- Whether to show the confirm button
    phase = "assign", -- Current game phase: assign, move, attack, defense
    movementPointsLeft = 0, -- Track remaining movement points
    startingPos = {x = 0, y = 0}, -- Store starting position for reset
    players = {
        {hp = 21, pos = {x = 0, y = 0}, movement = nil, attack = nil, defense = nil,
         lastMove = nil, lastAttack = nil, lastDefense = nil},
        {hp = 21, pos = {x = 5, y = 4}, movement = nil, attack = nil, defense = nil,
         lastMove = nil, lastAttack = nil, lastDefense = nil}
    },
    board = {},
    gameOver = false,
    winner = nil,
    roundCount = 0,
    hearts = {}, -- List of heart positions {x=x, y=y}
    heartPickup = {
        active = false,
        diceValue = 1,
        isRolling = false,
        rollTimer = 0,
        rollDuration = 1.0,
        healAmount = 0,
        waitingForConfirm = false -- New state to wait for confirmation after roll
    }
}

-- Helper functions
local function hexToPixel(hex)
    -- Convert hex coordinates to pixel coordinates for horizontal layout
    local x = HEX_SIZE * (math.sqrt(3) * hex.x + math.sqrt(3)/2 * hex.y)
    local y = HEX_SIZE * (3/2 * hex.y)
    
    -- Center the board horizontally and vertically
    return {
        x = x + WINDOW_WIDTH/2 - (GRID_SIZE * HEX_SIZE),
        y = y + WINDOW_HEIGHT/4
    }
end

local function pixelToHex(pixel)
    -- Adjust pixel coordinates relative to the grid center
    local px = pixel.x - (WINDOW_WIDTH/2 - (GRID_SIZE * HEX_SIZE))
    local py = pixel.y - WINDOW_HEIGHT/4
    
    -- Convert to axial coordinates
    local q = (math.sqrt(3)/3 * px - 1/3 * py) / HEX_SIZE
    local r = (2/3 * py) / HEX_SIZE
    
    -- Round to nearest hex
    local x = math.floor(q + 0.5)
    local y = math.floor(r + 0.5)
    
    return {x = x, y = y}
end

local function distance(hex1, hex2)
    -- Calculate axial distance
    local dx = hex1.x - hex2.x
    local dy = hex1.y - hex2.y
    return math.abs(dx) + math.abs(dy) + math.abs(dx + dy)
end

local function isOccupiedByOtherPlayer(hex, currentPlayer)
    for i, player in ipairs(gameState.players) do
        if i ~= currentPlayer and player.pos.x == hex.x and player.pos.y == hex.y then
            return true
        end
    end
    return false
end

local function calculateDamage(attacker, defender)
    -- Get tile modifiers
    local attackerTile = gameState.board[attacker.pos.x][attacker.pos.y].type
    local defenderTile = gameState.board[defender.pos.x][defender.pos.y].type
    
    -- Base damage
    local damage = attacker.attack or 0
    local defense = defender.defense or 0
    
    -- Apply tile modifiers
    if attackerTile == "attack" then
        damage = damage * 1.5
    end
    if defenderTile == "defense" then
        defense = defense * 1.5
    end
    
    -- Calculate final damage
    local finalDamage = math.max(0, math.floor(damage - defense))
    
    -- Create combat log entry
    local logEntry = string.format(
        "Player %d attacks! (Atk:%d on %s) vs (Def:%d on %s) = %d damage",
        gameState.currentPlayer,
        attacker.attack or 0,
        attackerTile,
        defender.defense or 0,
        defenderTile,
        finalDamage
    )
    table.insert(gameState.combatLog, 1, logEntry)
    if #gameState.combatLog > 5 then
        table.remove(gameState.combatLog)
    end
    
    -- Trigger combat effects
    gameState.combatEffects.active = true
    gameState.combatEffects.timer = 0
    gameState.combatEffects.damage = finalDamage
    gameState.combatEffects.attackerPos = attacker.pos
    gameState.combatEffects.defenderPos = defender.pos
    
    return finalDamage
end

local function isAdjacent(hex1, hex2)
    return distance(hex1, hex2) == 1
end

local function drawHexagon(x, y, size, filled)
    local vertices = {}
    for i = 0, 5 do
        -- Rotate hexagon 90 degrees by starting at math.pi/2
        local angle = math.pi/2 + math.pi/3 * i
        vertices[#vertices + 1] = x + size * math.cos(angle)
        vertices[#vertices + 1] = y + size * math.sin(angle)
    end
    if filled then
        love.graphics.polygon('fill', vertices)
    else
        love.graphics.polygon('line', vertices)
    end
end

local function drawDie(x, y, value, size, rotation, scale)
    -- Save current graphics state
    love.graphics.push()
    
    -- Move to die center for rotation
    love.graphics.translate(x + size/2, y + size/2)
    love.graphics.rotate(rotation)
    love.graphics.scale(scale, scale)
    
    -- Draw die background
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle('fill', -size/2, -size/2, size, size, 5, 5)
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle('line', -size/2, -size/2, size, size, 5, 5)
    
    local dotSize = size/10
    local padding = size/4
    love.graphics.setColor(0, 0, 0)
    
    if value == 1 then
        love.graphics.circle('fill', 0, 0, dotSize)
    elseif value == 2 then
        love.graphics.circle('fill', -size/2 + padding, -size/2 + padding, dotSize)
        love.graphics.circle('fill', size/2 - padding, size/2 - padding, dotSize)
    elseif value == 3 then
        love.graphics.circle('fill', -size/2 + padding, -size/2 + padding, dotSize)
        love.graphics.circle('fill', 0, 0, dotSize)
        love.graphics.circle('fill', size/2 - padding, size/2 - padding, dotSize)
    elseif value == 4 then
        love.graphics.circle('fill', -size/2 + padding, -size/2 + padding, dotSize)
        love.graphics.circle('fill', size/2 - padding, -size/2 + padding, dotSize)
        love.graphics.circle('fill', -size/2 + padding, size/2 - padding, dotSize)
        love.graphics.circle('fill', size/2 - padding, size/2 - padding, dotSize)
    elseif value == 5 then
        love.graphics.circle('fill', -size/2 + padding, -size/2 + padding, dotSize)
        love.graphics.circle('fill', size/2 - padding, -size/2 + padding, dotSize)
        love.graphics.circle('fill', 0, 0, dotSize)
        love.graphics.circle('fill', -size/2 + padding, size/2 - padding, dotSize)
        love.graphics.circle('fill', size/2 - padding, size/2 - padding, dotSize)
    elseif value == 6 then
        love.graphics.circle('fill', -size/2 + padding, -size/2 + padding, dotSize)
        love.graphics.circle('fill', size/2 - padding, -size/2 + padding, dotSize)
        love.graphics.circle('fill', -size/2 + padding, 0, dotSize)
        love.graphics.circle('fill', size/2 - padding, 0, dotSize)
        love.graphics.circle('fill', -size/2 + padding, size/2 - padding, dotSize)
        love.graphics.circle('fill', size/2 - padding, size/2 - padding, dotSize)
    end
    
    -- Restore graphics state
    love.graphics.pop()
end

-- Initialize the game board with random tile types
function initializeBoard()
    for x = 0, GRID_SIZE-1 do
        gameState.board[x] = {}
        for y = 0, GRID_SIZE-1 do
            -- Create a horizontal board shape
            if math.abs(y - 2) <= 2 then
                gameState.board[x][y] = {
                    type = TILE_TYPES[love.math.random(#TILE_TYPES)]
                }
            end
        end
    end
    gameState.hearts = {}
    gameState.roundCount = 0
    
    -- Add initial heart at the center of the board
    local centerX = math.floor(GRID_SIZE/2)
    local centerY = math.floor(GRID_SIZE/2)
    if gameState.board[centerX] and gameState.board[centerX][centerY] then
        table.insert(gameState.hearts, {x=centerX, y=centerY})
    end
end

-- Try to spawn a heart at a random position
local function trySpawnHeart()
    if #gameState.hearts >= 2 then return end
    
    -- Get all valid positions (not occupied by players or other hearts)
    local validPositions = {}
    for x = 0, GRID_SIZE-1 do
        for y = 0, GRID_SIZE-1 do
            if gameState.board[x] and gameState.board[x][y] then
                local isValid = true
                -- Check if position is occupied by a player
                for _, player in ipairs(gameState.players) do
                    if player.pos.x == x and player.pos.y == y then
                        isValid = false
                        break
                    end
                end
                -- Check if position already has a heart
                for _, heart in ipairs(gameState.hearts) do
                    if heart.x == x and heart.y == y then
                        isValid = false
                        break
                    end
                end
                if isValid then
                    table.insert(validPositions, {x=x, y=y})
                end
            end
        end
    end
    
    -- If there are valid positions, spawn a heart at a random one
    if #validPositions > 0 then
        local pos = validPositions[love.math.random(#validPositions)]
        table.insert(gameState.hearts, {x=pos.x, y=pos.y})
    end
end

function love.load()
    love.window.setMode(WINDOW_WIDTH, WINDOW_HEIGHT)
    love.window.setTitle("Battle Dice Game")
    
    -- Initialize game board
    initializeBoard()
    
    -- Initialize combat logs as empty tables
    gameState.combatEffects.player1Log = {}
    gameState.combatEffects.player2Log = {}
end

function love.update(dt)
    -- Update combat effects
    if gameState.combatEffects.active then
        gameState.combatEffects.timer = gameState.combatEffects.timer + dt
        if gameState.combatEffects.timer >= gameState.combatEffects.duration then
            -- Only clear visual effects, keep the log
            gameState.combatEffects.active = false
            
            -- Switch players after combat effects finish
            local currentPlayer = gameState.players[gameState.currentPlayer]
            currentPlayer.lastMove = currentPlayer.movement
            currentPlayer.lastAttack = currentPlayer.attack
            currentPlayer.lastDefense = currentPlayer.defense

            -- Switch to other player and reset dice state
            gameState.currentPlayer = gameState.currentPlayer == 1 and 2 or 1
            gameState.isRolling = true
            gameState.rollTimer = 0
            gameState.phase = "assign"
            
            -- Reset next player's action slots and dice assignments
            local nextPlayer = gameState.players[gameState.currentPlayer]
            nextPlayer.movement = nil
            nextPlayer.attack = nil
            nextPlayer.defense = nil
            
            -- Reset dice-related state only
            for i = 1, 3 do
                gameState.diceAssignments[i] = nil
            end
            gameState.draggedDie = nil
            gameState.draggedSlot = nil
            gameState.dragX = 0
            gameState.dragY = 0
        end
    end
    
    if gameState.heartPickup.active and gameState.heartPickup.isRolling then
        gameState.heartPickup.rollTimer = gameState.heartPickup.rollTimer + dt
        
        -- Update dice value during rolling
        if gameState.heartPickup.rollTimer < gameState.heartPickup.rollDuration then
            gameState.heartPickup.diceValue = love.math.random(6)
        else
            gameState.heartPickup.isRolling = false
            gameState.heartPickup.healAmount = gameState.heartPickup.diceValue + 3
        end
    end
    
    if gameState.isRolling then
        gameState.rollTimer = gameState.rollTimer + dt
        
        -- Update dice values during rolling
        if gameState.rollTimer < gameState.rollDuration then
            for i = 1, 3 do
                gameState.dice[i] = love.math.random(6)
            end
        else
            gameState.isRolling = false
            gameState.rollTimer = 0
            -- Set final dice values
            for i = 1, 3 do
                gameState.dice[i] = love.math.random(6)
            end
        end
    end
end

function love.draw()
    -- Draw regular game state
    if not gameState.gameOver then
        -- Draw combat log
        love.graphics.setColor(1, 1, 1)
        for i, log in ipairs(gameState.combatLog) do
            love.graphics.print(log, 10, WINDOW_HEIGHT - 20 * i - 10)
        end
        
        -- Draw board and hearts
        for x = 0, GRID_SIZE-1 do
            for y = 0, GRID_SIZE-1 do
                if gameState.board[x] and gameState.board[x][y] then
                    local hex = hexToPixel({x = x, y = y})
                    
                    -- Draw base tile with type color
                    if gameState.board[x][y].type == "attack" then
                        love.graphics.setColor(1, 0.8, 0.8)
                    elseif gameState.board[x][y].type == "defense" then
                        love.graphics.setColor(0.8, 0.8, 1)
                    else
                        love.graphics.setColor(0.9, 0.9, 0.9)
                    end
                    drawHexagon(hex.x, hex.y, HEX_SIZE, true)
                    
                    -- Draw tile border (black by default, yellow for valid moves)
                    if gameState.phase == "move" and
                       distance(gameState.players[gameState.currentPlayer].pos, {x = x, y = y}) == 2 and
                       gameState.movementPointsLeft > 0 and
                       not (gameState.players[gameState.currentPlayer == 1 and 2 or 1].pos.x == x and 
                            gameState.players[gameState.currentPlayer == 1 and 2 or 1].pos.y == y) then
                        love.graphics.setColor(1, 1, 0, 1)  -- Bright yellow border
                        love.graphics.setLineWidth(3)  -- Make the border thicker
                        drawHexagon(hex.x, hex.y, HEX_SIZE, false)
                        love.graphics.setLineWidth(1)  -- Reset line width
                    else
                        love.graphics.setColor(0.2, 0.2, 0.2)
                        drawHexagon(hex.x, hex.y, HEX_SIZE, false)
                    end
                    
                    -- Draw heart if present
                    for _, heart in ipairs(gameState.hearts) do
                        if heart.x == x and heart.y == y then
                            love.graphics.setColor(1, 0.3, 0.3)
                            love.graphics.circle('fill', hex.x, hex.y, HEX_SIZE/3)
                            -- Draw a small white heart shape
                            love.graphics.setColor(1, 1, 1)
                            love.graphics.circle('fill', hex.x - HEX_SIZE/8, hex.y, HEX_SIZE/8)
                            love.graphics.circle('fill', hex.x + HEX_SIZE/8, hex.y, HEX_SIZE/8)
                            love.graphics.polygon('fill', 
                                hex.x, hex.y + HEX_SIZE/6,
                                hex.x - HEX_SIZE/4, hex.y - HEX_SIZE/8,
                                hex.x + HEX_SIZE/4, hex.y - HEX_SIZE/8
                            )
                            break
                        end
                    end
                end
            end
        end
    
    -- Draw player HP and last turn dice values
    local SMALL_DICE_SIZE = 25 -- Size for the history dice display
    
    -- Player 1 (Blue)
    love.graphics.setColor(0, 0.6, 1)
    love.graphics.print("Player 1 HP: " .. gameState.players[1].hp, 10, 10)
    if gameState.players[1].lastMove then
        -- Draw small labels
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("M", 15, 35)
        love.graphics.print("A", 15, 65)
        love.graphics.print("D", 15, 95)
        
        -- Draw dice with values
        love.graphics.setColor(0, 0.6, 1, 0.8)
        drawDie(40, 40, gameState.players[1].lastMove, SMALL_DICE_SIZE, 0, 1)
        drawDie(40, 70, gameState.players[1].lastAttack, SMALL_DICE_SIZE, 0, 1)
        drawDie(40, 100, gameState.players[1].lastDefense, SMALL_DICE_SIZE, 0, 1)
    end

    -- Player 2 (Red)
    love.graphics.setColor(1, 0, 0)
    love.graphics.print("Player 2 HP: " .. gameState.players[2].hp, WINDOW_WIDTH - 150, 10)
    if gameState.players[2].lastMove then
        -- Draw small labels
        love.graphics.setColor(0.7, 0.7, 0.7)
        love.graphics.print("M", WINDOW_WIDTH - 125, 35)
        love.graphics.print("A", WINDOW_WIDTH - 125, 65)
        love.graphics.print("D", WINDOW_WIDTH - 125, 95)
        
        -- Draw dice with values
        love.graphics.setColor(1, 0, 0, 0.8)
        drawDie(WINDOW_WIDTH - 100, 40, gameState.players[2].lastMove, SMALL_DICE_SIZE, 0, 1)
        drawDie(WINDOW_WIDTH - 100, 70, gameState.players[2].lastAttack, SMALL_DICE_SIZE, 0, 1)
        drawDie(WINDOW_WIDTH - 100, 100, gameState.players[2].lastDefense, SMALL_DICE_SIZE, 0, 1)
    end

    -- Draw players
    for i, player in ipairs(gameState.players) do
        local pos = hexToPixel(player.pos)
        love.graphics.setColor(PLAYER_COLORS[i])
        love.graphics.circle('fill', pos.x, pos.y, HEX_SIZE/2)
        
        -- Draw heart on top if player is on a heart tile
        for _, heart in ipairs(gameState.hearts) do
            if heart.x == player.pos.x and heart.y == player.pos.y then
                love.graphics.setColor(1, 0.3, 0.3)
                love.graphics.circle('fill', pos.x, pos.y, HEX_SIZE/3)
                -- Draw a small white heart shape
                love.graphics.setColor(1, 1, 1)
                love.graphics.circle('fill', pos.x - HEX_SIZE/8, pos.y, HEX_SIZE/8)
                love.graphics.circle('fill', pos.x + HEX_SIZE/8, pos.y, HEX_SIZE/8)
                love.graphics.polygon('fill', 
                    pos.x, pos.y + HEX_SIZE/6,
                    pos.x - HEX_SIZE/4, pos.y - HEX_SIZE/8,
                    pos.x + HEX_SIZE/4, pos.y - HEX_SIZE/8
                )
                break
            end
        end
    end
    end  -- end of if not gameState.gameOver
    
    -- Draw dice and slots
    local diceY = WINDOW_HEIGHT - 150
    local slotsY = WINDOW_HEIGHT - 250
    local startX = WINDOW_WIDTH/2 - (DICE_SPACING * 2)
    
    -- Draw slots
    love.graphics.setColor(0.3, 0.3, 0.3)
    love.graphics.rectangle('fill', startX, slotsY, DICE_SIZE, DICE_SIZE)
    love.graphics.rectangle('fill', startX + DICE_SPACING, slotsY, DICE_SIZE, DICE_SIZE)
    love.graphics.rectangle('fill', startX + DICE_SPACING * 2, slotsY, DICE_SIZE, DICE_SIZE)
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Move", startX, slotsY - 30)
    love.graphics.print("Attack", startX + DICE_SPACING, slotsY - 30)
    love.graphics.print("Defense", startX + DICE_SPACING * 2, slotsY - 30)
    
    -- Draw dice in slots first
    local player = gameState.players[gameState.currentPlayer]
    if player.movement then
        drawDie(startX, slotsY, player.movement, DICE_SIZE, 0, 1)
    end
    if player.attack then
        drawDie(startX + DICE_SPACING, slotsY, player.attack, DICE_SIZE, 0, 1)
    end
    if player.defense then
        drawDie(startX + DICE_SPACING * 2, slotsY, player.defense, DICE_SIZE, 0, 1)
    end

    -- Draw unassigned dice first
    for i = 1, 3 do
        -- Draw die in its original position if it hasn't been assigned and isn't being dragged
        if not gameState.diceAssignments[i] and gameState.draggedDie ~= i then
            drawDie(startX + (i-1) * DICE_SPACING, diceY, gameState.dice[i], DICE_SIZE, 
                   0, 1)
        end
    end

    -- Draw dragged dice on top
    -- Draw heart pickup UI if active
    if gameState.heartPickup.active then
        -- Draw semi-transparent black overlay
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        
        -- Draw heart pickup die in center
        love.graphics.setColor(1, 1, 1)
        drawDie(WINDOW_WIDTH/2 - DICE_SIZE/2, WINDOW_HEIGHT/2 - DICE_SIZE/2, 
                gameState.heartPickup.diceValue, DICE_SIZE, 0, 1)
        
        -- Draw instruction text
        love.graphics.setColor(1, 1, 1)
        if not gameState.heartPickup.isRolling then
            if gameState.heartPickup.healAmount == 0 then
                love.graphics.print("Press SPACE to roll for healing!", 
                    WINDOW_WIDTH/2 - 100, WINDOW_HEIGHT/2 + DICE_SIZE)
            else
                local text = string.format("%d + 3 = %d HP", 
                    gameState.heartPickup.diceValue, gameState.heartPickup.healAmount)
                love.graphics.print(text, WINDOW_WIDTH/2 - 50, WINDOW_HEIGHT/2 + DICE_SIZE)
                
                -- Show equation and wait for player to continue
                love.graphics.print("Press SPACE to apply healing and continue", 
                    WINDOW_WIDTH/2 - 120, WINDOW_HEIGHT/2 + DICE_SIZE + 30)
                
                -- Add a state to wait for confirmation
                if not gameState.heartPickup.waitingForConfirm then
                    gameState.heartPickup.waitingForConfirm = true
                end
            end
        end
    end
    
    if not gameState.isRolling then
        local mx, my = love.mouse.getPosition()
        if gameState.draggedDie then
            -- Draw dragged unassigned die
            drawDie(mx - gameState.dragX, my - gameState.dragY, gameState.dice[gameState.draggedDie], DICE_SIZE, 0, 1)
        elseif gameState.draggedSlot then
            -- Draw dragged slot die
            local player = gameState.players[gameState.currentPlayer]
            local value
            if gameState.draggedSlot == 1 then value = player.movement
            elseif gameState.draggedSlot == 2 then value = player.attack
            else value = player.defense end
            drawDie(mx - gameState.dragX, my - gameState.dragY, value, DICE_SIZE, 0, 1)
        end
    end
    
    -- Draw player info
    love.graphics.setColor(PLAYER_COLORS[1])
    love.graphics.print("Player 1 HP: " .. gameState.players[1].hp, 10, 10)
    love.graphics.setColor(PLAYER_COLORS[2])
    love.graphics.print("Player 2 HP: " .. gameState.players[2].hp, WINDOW_WIDTH - 150, 10)
    
    -- Draw game over screen if game is over
    if gameState.gameOver then
        love.graphics.setColor(0, 0, 0, 0.7)
        love.graphics.rectangle('fill', 0, 0, WINDOW_WIDTH, WINDOW_HEIGHT)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Player " .. gameState.winner .. " Wins!", WINDOW_WIDTH/2 - 50, WINDOW_HEIGHT/2 - 20)
        love.graphics.print("Press SPACE to restart", WINDOW_WIDTH/2 - 70, WINDOW_HEIGHT/2 + 20)
    end
    
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Player " .. gameState.currentPlayer .. "'s turn", WINDOW_WIDTH/2 - 50, 10)
    
    if gameState.phase == "move" then
        -- Draw movement points
        love.graphics.print("Movement points left: " .. gameState.movementPointsLeft, WINDOW_WIDTH/2 - 70, 40)
        
        -- Draw Reset button
        love.graphics.setColor(0.8, 0.2, 0.2, 0.8)
        love.graphics.rectangle('fill', WINDOW_WIDTH/2 - 150, WINDOW_HEIGHT - 100, 100, 40, 5, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("RESET", WINDOW_WIDTH/2 - 130, WINDOW_HEIGHT - 90)
        
        -- Draw Finish button if all movement points are used
        if gameState.movementPointsLeft <= 0 then
            love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
            love.graphics.rectangle('fill', WINDOW_WIDTH/2 + 50, WINDOW_HEIGHT - 100, 100, 40, 5, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("FINISH", WINDOW_WIDTH/2 + 70, WINDOW_HEIGHT - 90)
        end
    elseif not gameState.isRolling then
        if gameState.showConfirm then
            -- Draw confirm button
            love.graphics.setColor(0.2, 0.8, 0.2, 0.8)
            love.graphics.rectangle('fill', startX + DICE_SPACING * 3 + 20, slotsY, 100, 40, 5, 5)
            love.graphics.setColor(1, 1, 1)
            love.graphics.print("CONFIRM", startX + DICE_SPACING * 3 + 40, slotsY + 10)
        else
            love.graphics.print("Press SPACE to roll", WINDOW_WIDTH/2 - 70, 40)
        end
    end
    
    -- Draw combat effects on top of everything
    if not gameState.gameOver then
        -- Draw combat logs for both players if they exist
        -- Player 1 log (right side)
        if #gameState.combatEffects.player1Log > 0 then
            -- Draw semi-transparent black background
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle('fill', WINDOW_WIDTH - 310, WINDOW_HEIGHT - 210, 290, 120)
            
            -- Draw white text
            love.graphics.setColor(1, 1, 1, 1)
            for i, log in ipairs(gameState.combatEffects.player1Log) do
                love.graphics.print(log, WINDOW_WIDTH - 300, WINDOW_HEIGHT - 200 + (i * 20))
            end
        end
        
        -- Player 2 log (left side)
        if #gameState.combatEffects.player2Log > 0 then
            -- Draw semi-transparent black background
            love.graphics.setColor(0, 0, 0, 0.7)
            love.graphics.rectangle('fill', 40, WINDOW_HEIGHT - 210, 290, 120)
            
            -- Draw white text
            love.graphics.setColor(1, 1, 1, 1)
            for i, log in ipairs(gameState.combatEffects.player2Log) do
                love.graphics.print(log, 50, WINDOW_HEIGHT - 200 + (i * 20))
            end
        end
        
        -- Draw active combat effects
        if gameState.combatEffects.active then
            local attackerPixel = hexToPixel(gameState.combatEffects.attackerPos)
            local defenderPixel = hexToPixel(gameState.combatEffects.defenderPos)
            
            -- Draw attack line
            love.graphics.setLineWidth(4) -- Thicker line
            love.graphics.setColor(1, 0, 0, 0.7) -- More opaque red
            love.graphics.line(attackerPixel.x, attackerPixel.y, defenderPixel.x, defenderPixel.y)
            love.graphics.setLineWidth(1) -- Reset line width
            
            -- Draw damage number
            love.graphics.setColor(1, 0, 0)
            love.graphics.print(
                "-" .. gameState.combatEffects.damage,
                defenderPixel.x - 15,
                defenderPixel.y - 40,
                0,
                2.0, -- Bigger text
                2.0
            )
        end
    end
end  -- End of love.draw

function love.mousepressed(x, y, button)
    if not gameState.isRolling and button == 1 then
        if gameState.phase == "move" and not gameState.heartPickup.active then
            -- Check if Finish button was clicked
            if gameState.movementPointsLeft <= 0 then
                local finishX = WINDOW_WIDTH/2 + 50
                local finishY = WINDOW_HEIGHT - 100
                if x >= finishX and x <= finishX + 100 and
                   y >= finishY and y <= finishY + 40 then
                    local currentPlayer = gameState.players[gameState.currentPlayer]
                    local otherPlayer = gameState.players[gameState.currentPlayer == 1 and 2 or 1]
                    
                    -- Check for heart pickup first
                    local currentPlayerPos = currentPlayer.pos
                    for i = #gameState.hearts, 1, -1 do
                        local heart = gameState.hearts[i]
                        if heart.x == currentPlayerPos.x and heart.y == currentPlayerPos.y then
                            -- Start heart pickup sequence
                            gameState.heartPickup.active = true
                            gameState.heartPickup.diceValue = 1
                            gameState.heartPickup.isRolling = false
                            gameState.heartPickup.healAmount = 0
                            table.remove(gameState.hearts, i)
                            -- Spawn a new heart immediately
                            trySpawnHeart()
                            return -- Don't switch players yet
                        end
                    end
                    
                    -- Then check for combat if adjacent to enemy
                    if distance(currentPlayer.pos, otherPlayer.pos) == 2 then
                        -- Calculate and apply damage
                        local attackerTile = gameState.board[currentPlayer.pos.x][currentPlayer.pos.y].type
                        local defenderTile = gameState.board[otherPlayer.pos.x][otherPlayer.pos.y].type
                        
                        local damage = currentPlayer.attack or 0
                        local defense = otherPlayer.defense or 0
                        
                        -- Apply tile modifiers
                        if attackerTile == "attack" then
                            damage = damage * 1.5
                        end
                        if defenderTile == "defense" then
                            defense = defense * 1.5
                        end
                        
                        -- Calculate final damage
                        local finalDamage = math.max(0, math.floor(damage - defense))
                        otherPlayer.hp = otherPlayer.hp - finalDamage
                        
                        -- Trigger combat effects
                        gameState.combatEffects.active = true
                        gameState.combatEffects.attackerPos = currentPlayer.pos
                        gameState.combatEffects.defenderPos = otherPlayer.pos
                        gameState.combatEffects.damage = finalDamage
                        gameState.combatEffects.timer = 0
                        
                        -- Store combat log for the current player
                        local newLog = {
                            "Combat Log:",
                            string.format("Attacker(P%d): %d damage on %s tile", gameState.currentPlayer, currentPlayer.attack, attackerTile),
                            string.format("Defender(P%d): %d defense on %s tile", gameState.currentPlayer == 1 and 2 or 1, otherPlayer.defense, defenderTile),
                            string.format("Damage Calculation: %d - %d = %d final damage", damage, defense, finalDamage),
                            string.format("Player %d HP reduced to: %d", gameState.currentPlayer == 1 and 2 or 1, otherPlayer.hp)
                        }
                        if gameState.currentPlayer == 1 then
                            gameState.combatEffects.player1Log = newLog
                        else
                            gameState.combatEffects.player2Log = newLog
                        end
                        
                        -- Check for win condition
                        if otherPlayer.hp <= 0 then
                            gameState.gameOver = true
                            gameState.winner = gameState.currentPlayer
                            return
                        end
                        
                        -- Don't switch players immediately if combat occurred
                        return
                    end
                    
                    -- Switch players only if no combat occurred
                    -- Store current player's dice values before switching
                    local currentPlayer = gameState.players[gameState.currentPlayer]
                    currentPlayer.lastMove = currentPlayer.movement
                    currentPlayer.lastAttack = currentPlayer.attack
                    currentPlayer.lastDefense = currentPlayer.defense

                    -- Switch to other player and reset all dice state
                    gameState.currentPlayer = gameState.currentPlayer == 1 and 2 or 1
                    gameState.isRolling = true
                    gameState.rollTimer = 0
                    gameState.phase = "assign"
                    
                    -- If it's player 1's turn, increment round counter
                    if gameState.currentPlayer == 1 then
                        gameState.roundCount = gameState.roundCount + 1
                    end
                    
                    -- Store current player's dice values
                    local currentPlayer = gameState.players[gameState.currentPlayer]
                    currentPlayer.lastMove = currentPlayer.movement
                    currentPlayer.lastAttack = currentPlayer.attack
                    currentPlayer.lastDefense = currentPlayer.defense

                    -- Reset next player's action slots and dice assignments
                    local nextPlayer = gameState.players[gameState.currentPlayer]
                    nextPlayer.movement = nil
                    nextPlayer.attack = nil
                    nextPlayer.defense = nil
                    
                    -- Reset all dice positions and assignments
                    for i = 1, 3 do
                        gameState.diceAssignments[i] = nil
                    end
                    
                    -- Reset any dragged dice state
                    gameState.draggedDie = nil
                    gameState.draggedSlot = nil
                    gameState.dragX = 0
                    gameState.dragY = 0
                    return
                end
            end
            
            -- Check if Reset button was clicked
            if not gameState.heartPickup.active then
                local resetX = WINDOW_WIDTH/2 - 150
                local resetY = WINDOW_HEIGHT - 100
                if x >= resetX and x <= resetX + 100 and
                   y >= resetY and y <= resetY + 40 then
                    -- Reset position and movement points
                    local currentPlayer = gameState.players[gameState.currentPlayer]
                    currentPlayer.pos = {x = gameState.startingPos.x, y = gameState.startingPos.y}
                    gameState.movementPointsLeft = currentPlayer.movement
                    return
                end
            end
        end
        
        if gameState.phase == "move" then
            -- Convert mouse position to hex coordinates
            local hex = pixelToHex({x = x, y = y})
            local currentPlayer = gameState.players[gameState.currentPlayer]
            local otherPlayer = gameState.players[gameState.currentPlayer == 1 and 2 or 1]
            
            -- Debug print
            print(string.format("Click at hex: %d,%d, Player at: %d,%d",
                  hex.x, hex.y, currentPlayer.pos.x, currentPlayer.pos.y))
            
            -- Check if the clicked hex is adjacent, valid, and not occupied
            if gameState.board[hex.x] and gameState.board[hex.x][hex.y] and
               distance(currentPlayer.pos, hex) == 2 and -- Distance of 2 in axial coordinates means adjacent
               gameState.movementPointsLeft > 0 and
               not (otherPlayer.pos.x == hex.x and otherPlayer.pos.y == hex.y) then
                -- Move player to new position
                currentPlayer.pos = hex
                -- Decrease movement points
                gameState.movementPointsLeft = gameState.movementPointsLeft - 1
                return
            end
        end
        
        -- Check if confirm button was clicked
        local startX = WINDOW_WIDTH/2 - (DICE_SPACING * 2)
        local slotsY = WINDOW_HEIGHT - 250
        if gameState.showConfirm and
           x >= startX + DICE_SPACING * 3 + 20 and x <= startX + DICE_SPACING * 3 + 120 and
           y >= slotsY and y <= slotsY + 40 then
            -- Handle confirm button click
            gameState.showConfirm = false
            
            -- Start movement phase if player has movement dice
            if gameState.players[gameState.currentPlayer].movement then
                gameState.phase = "move"
                gameState.movementPointsLeft = gameState.players[gameState.currentPlayer].movement
                gameState.startingPos = {
                    x = gameState.players[gameState.currentPlayer].pos.x,
                    y = gameState.players[gameState.currentPlayer].pos.y
                }
            else
                -- If no movement dice, go straight to attack phase
                gameState.phase = "attack"
            end
            return
        end

        local diceY = WINDOW_HEIGHT - 150
        local slotsY = WINDOW_HEIGHT - 250
        local startX = WINDOW_WIDTH/2 - (DICE_SPACING * 2)
        
        -- Check if a slot die was clicked
        for i = 1, 3 do
            local slotX = startX + (i-1) * DICE_SPACING
            if x >= slotX and x <= slotX + DICE_SIZE and
               y >= slotsY and y <= slotsY + DICE_SIZE then
                local player = gameState.players[gameState.currentPlayer]
                if (i == 1 and player.movement) or
                   (i == 2 and player.attack) or
                   (i == 3 and player.defense) then
                    gameState.draggedDie = nil
                    gameState.draggedSlot = i
                    gameState.dragX = x - slotX
                    gameState.dragY = y - slotsY
                    return
                end
            end
        end
        
        -- Check if an unassigned die was clicked
        for i = 1, 3 do
            local diceX = startX + (i-1) * DICE_SPACING
            if x >= diceX and x <= diceX + DICE_SIZE and
               y >= diceY and y <= diceY + DICE_SIZE and
               not gameState.diceAssignments[i] then
                gameState.draggedDie = i
                gameState.draggedSlot = nil
                gameState.dragX = x - diceX
                gameState.dragY = y - diceY
                break
            end
        end
    end
end

function love.mousereleased(x, y, button)
    if (gameState.draggedDie or gameState.draggedSlot) and button == 1 then
        local slotsY = WINDOW_HEIGHT - 250
        local diceY = WINDOW_HEIGHT - 150
        local startX = WINDOW_WIDTH/2 - (DICE_SPACING * 2)
        local player = gameState.players[gameState.currentPlayer]

        -- Check if dragging from a slot and dropping on unassigned die
        if gameState.draggedSlot then
            -- Get the source value from the slot
            local sourceValue
            if gameState.draggedSlot == 1 then sourceValue = player.movement
            elseif gameState.draggedSlot == 2 then sourceValue = player.attack
            else sourceValue = player.defense end

            -- Check if dropping on unassigned die
            for j = 1, 3 do
                local diceX = startX + (j-1) * DICE_SPACING
                if x >= diceX and x <= diceX + DICE_SIZE and
                   y >= diceY and y <= diceY + DICE_SIZE and
                   not gameState.diceAssignments[j] then
                    -- Swap values
                    if gameState.draggedSlot == 1 then
                        player.movement = gameState.dice[j]
                        gameState.diceAssignments[j] = nil
                    elseif gameState.draggedSlot == 2 then
                        player.attack = gameState.dice[j]
                        gameState.diceAssignments[j] = nil
                    else
                        player.defense = gameState.dice[j]
                        gameState.diceAssignments[j] = nil
                    end
                    gameState.dice[j] = sourceValue
                    gameState.draggedSlot = nil
                    gameState.draggedDie = nil
                    return
                end
            end

            -- Check if dropping on another slot
            for i = 1, 3 do
                local slotX = startX + (i-1) * DICE_SPACING
                if x >= slotX and x <= slotX + DICE_SIZE and
                   y >= slotsY and y <= slotsY + DICE_SIZE and
                   i ~= gameState.draggedSlot then
                    -- Get target value
                    local targetValue
                    if i == 1 then targetValue = player.movement
                    elseif i == 2 then targetValue = player.attack
                    else targetValue = player.defense end

                    -- Swap values
                    if gameState.draggedSlot == 1 then player.movement = targetValue
                    elseif gameState.draggedSlot == 2 then player.attack = targetValue
                    else player.defense = targetValue end

                    if i == 1 then player.movement = sourceValue
                    elseif i == 2 then player.attack = sourceValue
                    else player.defense = sourceValue end
                    
                    gameState.draggedSlot = nil
                    gameState.draggedDie = nil
                end
            end
        else
            -- Dragging from unassigned die to slot
            for i = 1, 3 do
                local slotX = startX + (i-1) * DICE_SPACING
                if x >= slotX and x <= slotX + DICE_SIZE and
                   y >= slotsY and y <= slotsY + DICE_SIZE then
                    local value = gameState.dice[gameState.draggedDie]
                    
                    -- If slot is empty, place the die
                    if (i == 1 and not player.movement) or
                       (i == 2 and not player.attack) or
                       (i == 3 and not player.defense) then
                        -- Place in empty slot
                        if i == 1 then
                            player.movement = value
                            gameState.diceAssignments[gameState.draggedDie] = 1
                        elseif i == 2 then
                            player.attack = value
                            gameState.diceAssignments[gameState.draggedDie] = 2
                        else
                            player.defense = value
                            gameState.diceAssignments[gameState.draggedDie] = 3
                        end
                        gameState.draggedDie = nil
                    else
                        -- Swap with occupied slot
                        local slotValue
                        if i == 1 then slotValue = player.movement
                        elseif i == 2 then slotValue = player.attack
                        else slotValue = player.defense end
                        
                        -- Store the unassigned die in the slot
                        if i == 1 then player.movement = value
                        elseif i == 2 then player.attack = value
                        else player.defense = value end
                        
                        -- Move the slot's die to the unassigned position
                        gameState.dice[gameState.draggedDie] = slotValue
                        gameState.draggedDie = nil
                    end
                    
                    -- Check if all dice are assigned
                    if player.movement and player.attack and player.defense then
                        gameState.showConfirm = true
                    end
                    return
                end
            end
        end
        
        -- Always reset drag state
        gameState.draggedDie = nil
        gameState.draggedSlot = nil
    end
end

function love.keypressed(key)
    if key == "space" then

        
        -- Handle heart pickup state first
        if gameState.heartPickup.active then
            if gameState.heartPickup.waitingForConfirm then
                -- Apply healing and continue turn
                local currentPlayer = gameState.players[gameState.currentPlayer]
                currentPlayer.hp = currentPlayer.hp + gameState.heartPickup.healAmount
                
                -- Remove the heart
                for i = #gameState.hearts, 1, -1 do
                    local heart = gameState.hearts[i]
                    if heart.x == currentPlayer.pos.x and heart.y == currentPlayer.pos.y then
                        table.remove(gameState.hearts, i)
                        break
                    end
                end
                
                -- Reset heart pickup state
                gameState.heartPickup.active = false
                gameState.heartPickup.waitingForConfirm = false
                
                -- Check for combat after heart pickup
                local currentPlayerPos = currentPlayer.pos
                local otherPlayer = gameState.players[gameState.currentPlayer == 1 and 2 or 1]
                
                if isAdjacent(currentPlayerPos, otherPlayer.pos) then
                    -- Start combat sequence
                    local damage = calculateDamage(currentPlayer, otherPlayer)
                    otherPlayer.hp = otherPlayer.hp - damage
                    
                    -- Check for game over
                    if otherPlayer.hp <= 0 then
                        gameState.gameOver = true
                        gameState.winner = gameState.currentPlayer
                        return
                    end
                end
                
                -- Store current player's dice values before switching
                local currentPlayer = gameState.players[gameState.currentPlayer]
                currentPlayer.lastMove = currentPlayer.movement
                currentPlayer.lastAttack = currentPlayer.attack
                currentPlayer.lastDefense = currentPlayer.defense

                -- Switch to other player and reset all dice state
                gameState.currentPlayer = gameState.currentPlayer == 1 and 2 or 1
                gameState.isRolling = true
                gameState.rollTimer = 0
                gameState.phase = "assign"
                
                -- If it's player 1's turn, increment round counter
                if gameState.currentPlayer == 1 then
                    gameState.roundCount = gameState.roundCount + 1
                end
                
                -- Reset next player's action slots and dice assignments
                local nextPlayer = gameState.players[gameState.currentPlayer]
                nextPlayer.movement = nil
                nextPlayer.attack = nil
                nextPlayer.defense = nil
                
                -- Reset all dice positions and assignments
                for i = 1, 3 do
                    gameState.diceAssignments[i] = nil
                end
                
                -- Reset any dragged dice state
                gameState.draggedDie = nil
                gameState.draggedSlot = nil
                gameState.dragX = 0
                gameState.dragY = 0
                return
            elseif not gameState.heartPickup.isRolling then
                -- Start rolling for heart pickup
                gameState.heartPickup.isRolling = true
                gameState.heartPickup.rollTimer = 0
                return
            end
        end
        
        if gameState.gameOver then
            gameState.roundCount = 0
            -- Reset game state
            gameState = {
                currentPlayer = 1,
                dice = {1, 1, 1},
                isRolling = true,
                rollTimer = 0,
                rollDuration = 1.0,
                draggedDie = nil,
                draggedSlot = nil,
                dragX = 0,
                dragY = 0,
                diceAssignments = {nil, nil, nil},
                showConfirm = false,
                phase = "assign",
                movementPointsLeft = 0,
                startingPos = {x = 0, y = 0},
                players = {
                    {hp = 21, pos = {x = 0, y = 0}, movement = nil, attack = nil, defense = nil},
                    {hp = 21, pos = {x = 5, y = 5}, movement = nil, attack = nil, defense = nil}
                },
                board = {},
                gameOver = false,
                winner = nil
            }
            initializeBoard()
        -- Only handle normal dice rolling if not in heart pickup
        elseif not gameState.heartPickup.active and not gameState.isRolling then
            gameState.isRolling = true
            gameState.rollTimer = 0
            
            -- Reset player action slots and dice assignments
            local player = gameState.players[gameState.currentPlayer]
            player.movement = nil
            player.attack = nil
            player.defense = nil
            for i = 1, 3 do
                gameState.diceAssignments[i] = nil
            end
        end
    end
end


