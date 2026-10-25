--[[
	LobbyClient — tells the player where to go.

	* Banner at the top of the screen with the queue status.
	* A glowing guide line from the player to the best open circle
	  (circles where an opponent is already waiting come first).
	* Animated arrows along the path to the arena.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NEON = Color3.fromRGB(0, 210, 255)
local GOLD = Color3.fromRGB(255, 194, 66)

local player = Players.LocalPlayer
local lobby = workspace:WaitForChild("ChaosChessLobby")
local padsFolder = lobby:WaitForChild("Arena"):WaitForChild("MatchPads")
local queueState = ReplicatedStorage:WaitForChild("LobbyEvents"):WaitForChild("QueueState")

---------------------------------------------------------------- banner

local gui = Instance.new("ScreenGui")
gui.Name = "LobbyHud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local banner = Instance.new("Frame")
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 12)
banner.Size = UDim2.new(0.9, 0, 0, 52)
banner.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
banner.BackgroundTransparency = 0.2
banner.Parent = gui
Instance.new("UICorner", banner).CornerRadius = UDim.new(0, 14)
local bannerStroke = Instance.new("UIStroke", banner)
bannerStroke.Thickness = 2
bannerStroke.Color = NEON
local sizeLimit = Instance.new("UISizeConstraint", banner)
sizeLimit.MaxSize = Vector2.new(620, 52)

local bannerText = Instance.new("TextLabel")
bannerText.BackgroundTransparency = 1
bannerText.Size = UDim2.new(1, -24, 1, -12)
bannerText.Position = UDim2.fromOffset(12, 6)
bannerText.Font = Enum.Font.FredokaOne
bannerText.TextScaled = true
bannerText.TextColor3 = Color3.new(1, 1, 1)
bannerText.Parent = banner

local currentState = "idle"

local function render(state)
	local fields = string.split(state, ":")
	currentState = fields[1]
	if currentState == "waiting" then
		bannerText.Text = "Waiting for an opponent…  (Match " .. fields[2] .. ")"
		bannerStroke.Color = Color3.fromRGB(80, 230, 120)
	elseif currentState == "countdown" then
		bannerText.Text = "Match starting in " .. fields[3] .. "…"
		bannerStroke.Color = GOLD
	elseif currentState == "starting" then
		bannerText.Text = "Starting match!"
		bannerStroke.Color = GOLD
	else
		bannerText.Text = "▶  Follow the glowing line and step on a circle to play"
		bannerStroke.Color = NEON
	end
end

queueState.OnClientEvent:Connect(render)
render("idle")

---------------------------------------------------------------- guide line

local beam
local rootAttachment

local function onCharacter(character)
	local root = character:WaitForChild("HumanoidRootPart")
	rootAttachment = Instance.new("Attachment")
	rootAttachment.Name = "LobbyGuide"
	rootAttachment.Position = Vector3.new(0, -2.5, 0)
	rootAttachment.Parent = root

	beam = Instance.new("Beam")
	beam.Name = "LobbyGuideBeam"
	beam.Attachment0 = rootAttachment
	beam.Color = ColorSequence.new(NEON)
	beam.LightEmission = 1
	beam.Transparency = NumberSequence.new(0.3, 0.6)
	beam.Width0 = 1.2
	beam.Width1 = 0.6
	beam.FaceCamera = true
	beam.Enabled = false
	beam.Parent = root
end

player.CharacterAdded:Connect(onCharacter)
if player.Character then
	task.spawn(onCharacter, player.Character)
end

local function bestOpenSlot(position)
	local best, bestScore
	for _, pad in ipairs(padsFolder:GetChildren()) do
		if not pad:GetAttribute("Busy") then
			for _, side in ipairs({ "White", "Black" }) do
				local slot = pad:FindFirstChild("Slot" .. side)
				local other = pad:FindFirstChild(side == "White" and "SlotBlack" or "SlotWhite")
				if slot and not slot:GetAttribute("Occupied") then
					local score = (slot.Position - position).Magnitude
					if other and other:GetAttribute("Occupied") then
						score -= 1000 -- someone is already waiting here
					end
					if not bestScore or score < bestScore then
						best, bestScore = slot, score
					end
				end
			end
		end
	end
	return best
end

local sinceRetarget = math.huge
RunService.Heartbeat:Connect(function(dt)
	sinceRetarget += dt
	if not beam or not beam.Parent or sinceRetarget < 0.25 then
		return
	end
	sinceRetarget = 0

	local root = beam.Parent
	local slot = currentState == "idle" and bestOpenSlot(root.Position)
	local target = slot and slot:FindFirstChild("GuideAttachment")
	if not target then
		beam.Enabled = false
		return
	end
	local offset = slot.Position - root.Position
	beam.Attachment1 = target
	beam.Enabled = Vector2.new(offset.X, offset.Z).Magnitude > 6
end)

---------------------------------------------------------------- arrow animation

local chevrons = {}
for _, chevron in ipairs(lobby:WaitForChild("Path"):WaitForChild("Chevrons"):GetChildren()) do
	table.insert(chevrons, { order = chevron:GetAttribute("Order") or 0, parts = chevron:GetChildren() })
end

RunService.RenderStepped:Connect(function()
	local count = #chevrons
	if count == 0 then
		return
	end
	local head = os.clock() * 6
	for _, chevron in ipairs(chevrons) do
		-- bright at the travelling head, fading behind it
		local fade = math.clamp(((head - chevron.order) % count) / 3, 0, 1)
		for _, arm in ipairs(chevron.parts) do
			arm.Transparency = fade * 0.75
		end
	end
end)
