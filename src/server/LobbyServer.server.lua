--[[
	LobbyServer — 1v1 matchmaking pads for the Chaos Chess lobby.

	Two players stand on a pad's WHITE and BLACK circles -> countdown -> match starts.

	Starting the match:
	  * MATCH_PLACE_ID ~= 0: both players are teleported to a reserved server of that
	    place. TeleportData = { white = userId, black = userId }.
	  * MATCH_PLACE_ID == 0: ServerStorage.LobbyEvents.MatchFound (BindableEvent) fires
	    with (whitePlayer, blackPlayer, padIndex). Connect your game-start code to it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TeleportService = game:GetService("TeleportService")

local CONFIG = {
	MATCH_PLACE_ID = 0,
	COUNTDOWN = 5, -- seconds once both circles are filled
	REQUEUE_COOLDOWN = 8, -- seconds before matched players can queue again
	LEADERBOARD_STAT = "Wins", -- leaderstats value shown on the TOP PLAYERS board
	TICK = 0.2,
}

local RING_COLORS = {
	idle = Color3.fromRGB(0, 210, 255),
	occupied = Color3.fromRGB(80, 230, 120),
	countdown = Color3.fromRGB(255, 194, 66),
}

local SIDES = { "White", "Black" }

local lobby = workspace:WaitForChild("ChaosChessLobby")
local padsFolder = lobby:WaitForChild("Arena"):WaitForChild("MatchPads")

local function getChild(parent, className, name)
	local child = parent:FindFirstChild(name)
	if not child then
		child = Instance.new(className)
		child.Name = name
		child.Parent = parent
	end
	return child
end

local queueState = getChild(getChild(ReplicatedStorage, "Folder", "LobbyEvents"), "RemoteEvent", "QueueState")
local matchFound = getChild(getChild(ServerStorage, "Folder", "LobbyEvents"), "BindableEvent", "MatchFound")

local pads = {}
for _, model in ipairs(padsFolder:GetChildren()) do
	if model:IsA("Model") then
		table.insert(pads, {
			model = model,
			index = model:GetAttribute("PadIndex") or #pads + 1,
			slots = { White = model:WaitForChild("SlotWhite"), Black = model:WaitForChild("SlotBlack") },
			rings = { White = model:WaitForChild("RingWhite"), Black = model:WaitForChild("RingBlack") },
			statusLabel = model:WaitForChild("StatusAnchor"):WaitForChild("Status"):WaitForChild("Status"),
			occupants = {},
			countdownEnds = nil,
			busy = false,
		})
	end
end
table.sort(pads, function(a, b)
	return a.index < b.index
end)

local cooldownUntil = {}
local lastState = {}
local warnedNoPlaceId = false

local function rootOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function isStandingOn(root, slot)
	local offset = root.Position - slot.Position
	-- upright cylinder: Size.Y is its diameter
	return offset.Y > -1 and offset.Y < 8 and Vector2.new(offset.X, offset.Z).Magnitude <= slot.Size.Y / 2 + 0.5
end

local function setIfChanged(inst, key, value)
	if inst[key] ~= value then
		inst[key] = value
	end
end

local function setAttributeIfChanged(inst, key, value)
	if inst:GetAttribute(key) ~= value then
		inst:SetAttribute(key, value)
	end
end

local function resetPad(pad)
	pad.busy = false
	pad.occupants = {}
	pad.countdownEnds = nil
	setAttributeIfChanged(pad.model, "Busy", false)
end

local function startMatch(pad)
	local white, black = pad.occupants.White, pad.occupants.Black
	pad.busy = true
	setAttributeIfChanged(pad.model, "Busy", true)
	local now = os.clock()
	cooldownUntil[white] = now + CONFIG.REQUEUE_COOLDOWN
	cooldownUntil[black] = now + CONFIG.REQUEUE_COOLDOWN

	if CONFIG.MATCH_PLACE_ID ~= 0 then
		task.spawn(function()
			local ok, err = pcall(function()
				local options = Instance.new("TeleportOptions")
				options.ShouldReserveServer = true
				options:SetTeleportData({ white = white.UserId, black = black.UserId })
				TeleportService:TeleportAsync(CONFIG.MATCH_PLACE_ID, { white, black }, options)
			end)
			if not ok then
				warn("[Lobby] Teleport failed: " .. tostring(err))
			end
		end)
	else
		if not warnedNoPlaceId then
			warnedNoPlaceId = true
			warn("[Lobby] MATCH_PLACE_ID is 0 — firing ServerStorage.LobbyEvents.MatchFound. Connect your match start code to it.")
		end
		matchFound:Fire(white, black, pad.index)
	end

	task.delay(4, resetPad, pad)
end

local function updatePads()
	local now = os.clock()
	local claimed = {}
	local states = {}

	for _, pad in ipairs(pads) do
		if pad.busy then
			for _, side in ipairs(SIDES) do
				local player = pad.occupants[side]
				if player then
					states[player] = "starting"
				end
			end
			setIfChanged(pad.statusLabel, "Text", "STARTING!")
			continue
		end

		for _, side in ipairs(SIDES) do
			local slot = pad.slots[side]
			local current = pad.occupants[side]
			local currentRoot = current and current.Parent and rootOf(current)
			if not (currentRoot and not claimed[current] and isStandingOn(currentRoot, slot)) then
				current = nil
				for _, player in ipairs(Players:GetPlayers()) do
					local root = not claimed[player] and (cooldownUntil[player] or 0) <= now and rootOf(player)
					if root and isStandingOn(root, slot) then
						current = player
						break
					end
				end
			end
			pad.occupants[side] = current
			if current then
				claimed[current] = true
			end
			setAttributeIfChanged(slot, "Occupied", current ~= nil)
		end

		local white, black = pad.occupants.White, pad.occupants.Black
		if white and black then
			pad.countdownEnds = pad.countdownEnds or now + CONFIG.COUNTDOWN
			local remaining = math.ceil(pad.countdownEnds - now)
			for _, side in ipairs(SIDES) do
				setIfChanged(pad.rings[side], "Color", RING_COLORS.countdown)
			end
			if remaining <= 0 then
				states[white], states[black] = "starting", "starting"
				setIfChanged(pad.statusLabel, "Text", "STARTING!")
				startMatch(pad)
			else
				local state = "countdown:" .. pad.index .. ":" .. remaining
				states[white], states[black] = state, state
				setIfChanged(pad.statusLabel, "Text", "STARTING IN " .. remaining)
			end
		else
			pad.countdownEnds = nil
			local count = 0
			for _, side in ipairs(SIDES) do
				local player = pad.occupants[side]
				setIfChanged(pad.rings[side], "Color", player and RING_COLORS.occupied or RING_COLORS.idle)
				if player then
					count += 1
					states[player] = "waiting:" .. pad.index
				end
			end
			setIfChanged(pad.statusLabel, "Text", count .. "/2 PLAYERS")
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		local state = states[player] or "idle"
		if lastState[player] ~= state then
			lastState[player] = state
			queueState:FireClient(player, state)
		end
	end
end

local function updateLeaderboard()
	local board = lobby:FindFirstChild("Boards") and lobby.Boards:FindFirstChild("Leaderboard")
	local list = board and board:FindFirstChild("List", true)
	if not list then
		return
	end
	local entries = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local stats = player:FindFirstChild("leaderstats")
		local stat = stats and stats:FindFirstChild(CONFIG.LEADERBOARD_STAT)
		table.insert(entries, { name = player.DisplayName, value = stat and tonumber(stat.Value) or 0 })
	end
	table.sort(entries, function(a, b)
		if a.value ~= b.value then
			return a.value > b.value
		end
		return a.name < b.name
	end)
	for i = 1, 10 do
		local row = list:FindFirstChild("Row" .. i)
		local entry = entries[i]
		if row then
			row.Text = entry and string.format("%d.  %s  —  %d", i, entry.name, entry.value) or ""
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	cooldownUntil[player] = nil
	lastState[player] = nil
end)

task.spawn(function()
	while true do
		updateLeaderboard()
		task.wait(5)
	end
end)

while true do
	updatePads()
	task.wait(CONFIG.TICK)
end
