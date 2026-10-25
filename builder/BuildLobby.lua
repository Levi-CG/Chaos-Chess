--[[
	Chaos Chess — Lobby Builder

	HOW TO RUN
	  1. Open your place in Roblox Studio.
	  2. View > Command Bar.
	  3. Paste this whole file into the Command Bar and press Enter.

	What it does
	  * Moves your old lobby (any Workspace child named in OLD_LOBBY_NAMES) into
	    ServerStorage.OldLobbyBackup, so nothing is deleted.
	  * Builds Workspace.ChaosChessLobby: island, spawn facing the arena, a
	    glowing arrow path through a PLAY gate, a giant chessboard arena with
	    six 1v1 match pads, statues, lamps, info + leaderboard boards.
	  * Tunes Lighting (Future lighting, bloom, atmosphere).
	  * Everything is one undo step (Ctrl+Z reverts it).

	Every chess piece is built from the ground up, so nothing floats.
	Want real meshes? Put Models/MeshParts named Pawn, Rook, Knight, Bishop,
	Queen, King in a ServerStorage folder called "ChessMeshes" and run this again:
	they are auto-scaled, recoloured and set on the ground.
]]

local CONFIG = {
	ORIGIN = Vector3.new(0, 0, 0), -- where the island is centred
	OLD_LOBBY_NAMES = { "Lobby" }, -- Workspace children to move into the backup folder
	FULL_BOARDS = true, -- set up all 32 pieces on every match pad
	MESH_FOLDER = "ChessMeshes", -- optional ServerStorage folder with real piece meshes
}

local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local recording = ChangeHistoryService:TryBeginRecording("Build Chaos Chess Lobby")

local COLORS = {
	plaza = Color3.fromRGB(226, 230, 238),
	tileLight = Color3.fromRGB(240, 233, 214),
	tileDark = Color3.fromRGB(64, 78, 104),
	path = Color3.fromRGB(38, 44, 62),
	neon = Color3.fromRGB(0, 210, 255),
	gold = Color3.fromRGB(255, 194, 66),
	stone = Color3.fromRGB(46, 52, 70),
	pieceWhite = Color3.fromRGB(246, 243, 236),
	pieceBlack = Color3.fromRGB(34, 36, 46),
	rock = Color3.fromRGB(122, 114, 106),
	grass = Color3.fromRGB(96, 178, 84),
	trunk = Color3.fromRGB(110, 72, 46),
	leaves = Color3.fromRGB(78, 160, 72),
	leavesLight = Color3.fromRGB(112, 190, 92),
	lamp = Color3.fromRGB(255, 226, 170),
	text = Color3.fromRGB(255, 255, 255),
	outline = Color3.fromRGB(20, 24, 36),
}

local SMOOTH = Enum.Material.SmoothPlastic
local NEON = Enum.Material.Neon

---------------------------------------------------------------- helpers

local function make(className, props, parent)
	local inst = Instance.new(className)
	for key, value in pairs(props) do
		inst[key] = value
	end
	inst.Parent = parent
	return inst
end

local function group(name, parent, className)
	return make(className or "Model", { Name = name }, parent)
end

local function part(parent, name, size, cframe, color, material, shape)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Material = material or SMOOTH
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local ORIGIN = CFrame.new(CONFIG.ORIGIN)
local function at(x, y, z)
	return ORIGIN * CFrame.new(x, y, z)
end

-- Cylinder parts run along X; this turns them upright.
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

-- Upright cylinder whose bottom sits at local height y on `base`. Returns the part and its top height.
local function cylinder(parent, name, base, y, diameter, height, color, material)
	local p = part(
		parent,
		name,
		Vector3.new(height, diameter, diameter),
		base * CFrame.new(0, y + height / 2, 0) * UPRIGHT,
		color,
		material,
		Enum.PartType.Cylinder
	)
	return p, y + height
end

local function ball(parent, name, cframe, diameter, color, material)
	return part(parent, name, Vector3.new(diameter, diameter, diameter), cframe, color, material, Enum.PartType.Ball)
end

local function ellipsoid(parent, name, size, cframe, color, material)
	local p = part(parent, name, size, cframe, color, material)
	make("SpecialMesh", { MeshType = Enum.MeshType.Sphere }, p)
	return p
end

local function pointLight(parent, range, brightness, color)
	return make("PointLight", { Range = range, Brightness = brightness, Color = color }, parent)
end

local function label(parent, props)
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextColor3 = COLORS.text
	l.TextScaled = true
	l.Size = UDim2.fromScale(1, 1)
	for key, value in pairs(props) do
		l[key] = value
	end
	make("UIStroke", { Thickness = 3, Color = COLORS.outline }, l)
	l.Parent = parent
	return l
end

local function surfaceGui(parent, face, pixelsPerStud)
	return make("SurfaceGui", {
		Face = face,
		SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
		PixelsPerStud = pixelsPerStud or 30,
		LightInfluence = 0,
	}, parent)
end

---------------------------------------------------------------- chess pieces

local PIECE_HEIGHT = { Pawn = 1.45, Rook = 1.6, Knight = 1.75, Bishop = 1.95, Queen = 2.25, King = 2.5 }
local meshFolder = ServerStorage:FindFirstChild(CONFIG.MESH_FOLDER)

-- Places a mesh template so its bounding box stands on `base` (bottom centre), scaled to the piece height.
local function placeTemplate(template, kind, color, base, s, parent)
	local clone = template:Clone()
	local model = clone
	if clone:IsA("BasePart") then
		model = Instance.new("Model")
		clone.Parent = model
		model.PrimaryPart = clone
	end
	model.Name = kind
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.Color = color
		end
	end
	model.Parent = parent
	local _, size = model:GetBoundingBox()
	if size.Y > 0 then
		model:ScaleTo(model:GetScale() * PIECE_HEIGHT[kind] * s / size.Y)
	end
	model:PivotTo(base)
	local box, boxSize = model:GetBoundingBox()
	local bottom = Vector3.new(box.X, box.Y - boxSize.Y / 2, box.Z)
	model:PivotTo(model:GetPivot() + (base.Position - bottom))
	return model
end

-- Builds a piece standing on `base` (a CFrame at floor level; local -Z is the way it faces).
-- s = studs per unit; a piece is about 1 unit wide.
local function buildPiece(kind, isWhite, base, s, parent, material)
	local color = isWhite and COLORS.pieceWhite or COLORS.pieceBlack
	local template = meshFolder and meshFolder:FindFirstChild(kind)
	if template then
		return placeTemplate(template, kind, color, base, s, parent)
	end

	material = material or SMOOTH
	local model = group(kind, parent)
	local y = 0
	local function ring(diameter, height)
		local _, top = cylinder(model, kind, base, y, diameter * s, height * s, color, material)
		y = top
	end
	-- CFrame relative to the current stack height
	local function rel(x, dy, z)
		return base * CFrame.new(x * s, y + dy * s, z * s)
	end

	ring(1.0, 0.16)
	ring(0.86, 0.1)

	if kind == "Pawn" then
		ring(0.56, 0.22)
		ring(0.42, 0.34)
		ring(0.64, 0.07)
		ball(model, kind, rel(0, 0.25, 0), 0.56 * s, color, material)
	elseif kind == "Rook" then
		ring(0.7, 0.9)
		ring(0.86, 0.1)
		ring(0.8, 0.22)
		for i = 0, 3 do
			local a = math.rad(i * 90 + 45)
			part(
				model,
				kind,
				Vector3.new(0.24, 0.2, 0.24) * s,
				rel(math.cos(a) * 0.28, 0.1, math.sin(a) * 0.28) * CFrame.Angles(0, -a, 0),
				color,
				material
			)
		end
	elseif kind == "Bishop" then
		ring(0.52, 0.28)
		ring(0.42, 0.55)
		ring(0.68, 0.07)
		ellipsoid(model, kind, Vector3.new(0.54, 0.78, 0.54) * s, rel(0, 0.36, 0), color, material)
		ball(model, kind, rel(0, 0.8, 0), 0.18 * s, color, material)
	elseif kind == "Queen" then
		ring(0.58, 0.32)
		ring(0.46, 0.78)
		ring(0.76, 0.08)
		ring(0.5, 0.1)
		ring(0.68, 0.2)
		for i = 0, 7 do
			local a = math.rad(i * 45)
			ball(model, kind, rel(math.cos(a) * 0.3, 0.04, math.sin(a) * 0.3), 0.15 * s, color, material)
		end
		ball(model, kind, rel(0, 0.14, 0), 0.24 * s, color, material)
	elseif kind == "King" then
		ring(0.6, 0.34)
		ring(0.48, 0.9)
		ring(0.8, 0.08)
		ring(0.52, 0.12)
		ring(0.7, 0.24)
		part(model, kind, Vector3.new(0.12, 0.42, 0.12) * s, rel(0, 0.21, 0), color, material)
		part(model, kind, Vector3.new(0.34, 0.12, 0.12) * s, rel(0, 0.26, 0), color, material)
	elseif kind == "Knight" then
		local eyeColor = isWhite and COLORS.pieceBlack or COLORS.gold
		part(model, kind, Vector3.new(0.5, 0.95, 0.56) * s, rel(0, 0.45, 0.06) * CFrame.Angles(math.rad(10), 0, 0), color, material) -- neck
		part(model, kind, Vector3.new(0.44, 0.36, 0.86) * s, rel(0, 0.98, -0.18) * CFrame.Angles(math.rad(-25), 0, 0), color, material) -- head
		part(model, kind, Vector3.new(0.14, 0.82, 0.22) * s, rel(0, 0.62, 0.34) * CFrame.Angles(math.rad(12), 0, 0), color, material) -- mane
		for side = -1, 1, 2 do
			part(model, kind, Vector3.new(0.1, 0.24, 0.12) * s, rel(side * 0.12, 1.22, 0.1), color, material) -- ear
			ball(model, "Eye", rel(side * 0.22, 1.04, -0.22), 0.09 * s, eyeColor, SMOOTH)
		end
	end
	return model
end

-- 8x8 board whose top surface is at `center`. Rank 1 (White) is towards +Z.
local function chessboard(parent, name, center, tile, thickness, material)
	local model = group(name, parent)
	for file = 1, 8 do
		for rank = 1, 8 do
			local isLight = (file + rank) % 2 == 1
			part(
				model,
				"Tile",
				Vector3.new(tile, thickness, tile),
				center * CFrame.new((file - 4.5) * tile, -thickness / 2, (4.5 - rank) * tile),
				isLight and COLORS.tileLight or COLORS.tileDark,
				material
			)
		end
	end
	return model
end

local BACK_RANK = { "Rook", "Knight", "Bishop", "Queen", "King", "Bishop", "Knight", "Rook" }
local FACE_SOUTH = CFrame.Angles(0, math.pi, 0)

local function setupPieces(parent, center, tile, s)
	for file = 1, 8 do
		local x = (file - 4.5) * tile
		buildPiece(BACK_RANK[file], true, center * CFrame.new(x, 0, 3.5 * tile), s, parent)
		buildPiece("Pawn", true, center * CFrame.new(x, 0, 2.5 * tile), s, parent)
		buildPiece(BACK_RANK[file], false, center * CFrame.new(x, 0, -3.5 * tile) * FACE_SOUTH, s, parent)
		buildPiece("Pawn", false, center * CFrame.new(x, 0, -2.5 * tile) * FACE_SOUTH, s, parent)
	end
end

---------------------------------------------------------------- clear old lobby

local backup = ServerStorage:FindFirstChild("OldLobbyBackup") or make("Folder", { Name = "OldLobbyBackup" }, ServerStorage)
for _, name in ipairs(CONFIG.OLD_LOBBY_NAMES) do
	local old = workspace:FindFirstChild(name)
	if old then
		old.Parent = backup
		print("[LobbyBuilder] Moved old '" .. name .. "' to ServerStorage.OldLobbyBackup")
	end
end
local previous = workspace:FindFirstChild("ChaosChessLobby")
if previous then
	previous:Destroy()
end

local lobby = group("ChaosChessLobby", workspace)
-- Keep the whole lobby loaded on clients so the guide line and pads always exist.
lobby.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

---------------------------------------------------------------- island + plaza

local island = group("Island", lobby)
cylinder(island, "Rock", ORIGIN, -40, 272, 37.4, COLORS.rock, Enum.Material.Rock) -- top -2.6
cylinder(island, "Grass", ORIGIN, -2.6, 262, 2.2, COLORS.grass, Enum.Material.Grass) -- top -0.4
cylinder(island, "PlazaTrim", ORIGIN, -1.2, 244, 1.0, COLORS.gold, SMOOTH) -- top -0.2
cylinder(island, "Plaza", ORIGIN, -1.2, 240, 1.2, COLORS.plaza, SMOOTH) -- top 0 (walking height)

-- Invisible wall so nobody walks off the island
local boundary = group("Boundary", lobby, "Folder")
for i = 0, 23 do
	local a = math.rad(i * 15)
	local wall = part(boundary, "Wall", Vector3.new(36, 40, 2), at(math.sin(a) * 128, 18, math.cos(a) * 128) * CFrame.Angles(0, a, 0), COLORS.plaza)
	wall.Transparency = 1
	wall.CanQuery = false
end

---------------------------------------------------------------- spawn (faces the arena, -Z)

local SPAWN_Z = 80
local spawnArea = group("Spawn", lobby)
local spawnBase = at(0, 0, SPAWN_Z)
cylinder(spawnArea, "SpawnRim", spawnBase, -0.2, 34, 0.7, COLORS.neon, NEON)
cylinder(spawnArea, "SpawnPad", spawnBase, -0.2, 32, 1.0, COLORS.stone, SMOOTH) -- top 0.8
local spawn = make("SpawnLocation", {
	Name = "LobbySpawn",
	Anchored = true,
	CanCollide = false,
	Transparency = 1,
	Size = Vector3.new(12, 1, 12),
	CFrame = at(0, 0.3, SPAWN_Z),
	Neutral = true,
	Duration = 0,
}, spawnArea)
local spawnDecal = spawn:FindFirstChildOfClass("Decal")
if spawnDecal then
	spawnDecal:Destroy()
end

-- Knight statues guarding the spawn, facing the player
for side = -1, 1, 2 do
	local x = side * 24
	part(spawnArea, "Pedestal", Vector3.new(7, 3, 7), at(x, 1.5, SPAWN_Z), COLORS.stone, Enum.Material.Slate)
	part(spawnArea, "PedestalTrim", Vector3.new(7.6, 0.5, 7.6), at(x, 2.6, SPAWN_Z), COLORS.gold, SMOOTH)
	buildPiece("Knight", side < 0, at(x, 3, SPAWN_Z) * CFrame.Angles(0, side * math.rad(30), 0), 5, spawnArea, Enum.Material.Marble)
end

---------------------------------------------------------------- path with animated arrows

local PATH_START, PATH_END = 63, -12
local pathLength = PATH_START - PATH_END
local pathMid = (PATH_START + PATH_END) / 2
local path = group("Path", lobby)
part(path, "Walkway", Vector3.new(18, 0.3, pathLength), at(0, 0.1, pathMid), COLORS.path) -- top 0.25
for side = -1, 1, 2 do
	part(path, "EdgeGlow", Vector3.new(0.6, 0.34, pathLength), at(side * 9.3, 0.1, pathMid), COLORS.neon, NEON)
end

local chevrons = group("Chevrons", path, "Folder")
local CHEVRON_ANGLE = math.rad(40)
local order = 0
for z = PATH_START - 5, PATH_END + 4, -7 do
	order += 1
	local chevron = group("Chevron", chevrons)
	chevron:SetAttribute("Order", order)
	for side = -1, 1, 2 do
		-- each arm runs from the tip (pointing to the arena) back and out to one side
		local offset = Vector3.new(side * math.sin(CHEVRON_ANGLE), 0, math.cos(CHEVRON_ANGLE)) * 3
		part(chevron, "Arm", Vector3.new(0.9, 0.12, 6), at(offset.X, 0.31, z + offset.Z) * CFrame.Angles(0, side * CHEVRON_ANGLE, 0), COLORS.neon, NEON)
	end
end

-- Lamps along the path
local lamps = group("Lamps", lobby, "Folder")
local function lamp(x, z)
	local base = at(x, 0, z)
	cylinder(lamps, "LampBase", base, 0, 1.6, 0.6, COLORS.stone, SMOOTH)
	local _, top = cylinder(lamps, "LampPost", base, 0.6, 0.7, 9, COLORS.stone, SMOOTH)
	local bulb = ball(lamps, "LampBulb", base * CFrame.new(0, top + 0.8, 0), 1.8, COLORS.lamp, NEON)
	pointLight(bulb, 22, 1.4, COLORS.lamp)
end
for _, z in ipairs({ 56, 42, 8, -6 }) do
	lamp(-12, z)
	lamp(12, z)
end

---------------------------------------------------------------- PLAY gate + giant King & Queen

local GATE_Z = 24
local gate = group("PlayGate", lobby)
for side = -1, 1, 2 do
	local x = side * 13
	part(gate, "PillarFoot", Vector3.new(5, 1, 5), at(x, 0.5, GATE_Z), COLORS.gold, SMOOTH)
	part(gate, "Pillar", Vector3.new(4, 22, 4), at(x, 12, GATE_Z), COLORS.stone, Enum.Material.Slate)
	part(gate, "PillarGlow", Vector3.new(0.5, 18, 4.2), at(x - side * 2, 12, GATE_Z), COLORS.neon, NEON)
end
local sign = part(gate, "Sign", Vector3.new(32, 7, 3), at(0, 26.5, GATE_Z), COLORS.stone, Enum.Material.Slate)
part(gate, "SignTrimTop", Vector3.new(33, 0.6, 3.4), at(0, 30.3, GATE_Z), COLORS.gold, SMOOTH)
part(gate, "SignTrimBottom", Vector3.new(33, 0.6, 3.4), at(0, 22.7, GATE_Z), COLORS.gold, SMOOTH)
for _, face in ipairs({ Enum.NormalId.Back, Enum.NormalId.Front }) do
	local gui = surfaceGui(sign, face, 30)
	label(gui, { Name = "Title", Text = "▶ PLAY", TextColor3 = COLORS.gold, Size = UDim2.fromScale(1, 0.65) })
	label(gui, { Name = "Subtitle", Text = "STEP ON A GLOWING CIRCLE", Size = UDim2.fromScale(1, 0.3), Position = UDim2.fromScale(0, 0.65) })
end

for side = -1, 1, 2 do
	local x = side * 27
	part(gate, "StatuePedestal", Vector3.new(10, 3, 10), at(x, 1.5, GATE_Z), COLORS.stone, Enum.Material.Slate)
	part(gate, "StatueTrim", Vector3.new(10.6, 0.5, 10.6), at(x, 2.6, GATE_Z), COLORS.gold, SMOOTH)
	buildPiece(side < 0 and "King" or "Queen", side < 0, at(x, 3, GATE_Z) * FACE_SOUTH, 8, gate, Enum.Material.Marble)
end

---------------------------------------------------------------- arena: giant chessboard + match pads

local ARENA_Z = -58
local arena = group("Arena", lobby)
part(arena, "BoardFrame", Vector3.new(92, 0.6, 92), at(0, -0.15, ARENA_Z), COLORS.gold, SMOOTH) -- top 0.15
chessboard(arena, "GiantBoard", at(0, 0.2, ARENA_Z), 11, 0.6, SMOOTH)

for _, corner in ipairs({ { -47, -13 }, { 47, -13 }, { -47, -103 }, { 47, -103 } }) do
	lamp(corner[1], corner[2])
end

local padsFolder = make("Folder", { Name = "MatchPads" }, arena)
local PAD_POSITIONS = { { -29, -36 }, { 0, -36 }, { 29, -36 }, { -29, -80 }, { 0, -80 }, { 29, -80 } }
local SLOT_OFFSET = 15.5

for i, pos in ipairs(PAD_POSITIONS) do
	local px, pz = pos[1], pos[2]
	local pad = group("Pad" .. i, padsFolder)
	pad:SetAttribute("PadIndex", i)

	part(pad, "DaisTrim", Vector3.new(20.6, 0.3, 20.6), at(px, 1.3, pz), COLORS.gold, SMOOTH)
	part(pad, "Dais", Vector3.new(20, 1.3, 20), at(px, 0.85, pz), COLORS.stone, Enum.Material.Slate) -- top 1.5
	local boardTop = at(px, 1.8, pz)
	chessboard(pad, "Board", boardTop, 2, 0.3, SMOOTH)
	if CONFIG.FULL_BOARDS then
		setupPieces(group("Pieces", pad), boardTop, 2, 1.25)
	end

	for _, info in ipairs({ { "White", SLOT_OFFSET, COLORS.pieceWhite }, { "Black", -SLOT_OFFSET, COLORS.pieceBlack } }) do
		local side, dz, color = info[1], info[2], info[3]
		local slotBase = at(px, 0.2, pz + dz)
		cylinder(pad, "Ring" .. side, slotBase, 0, 9.4, 0.2, COLORS.neon, NEON)
		local slot = cylinder(pad, "Slot" .. side, slotBase, 0, 8, 0.35, color, SMOOTH)
		slot:SetAttribute("Side", side)
		-- slot's local +X is world up (upright cylinder)
		make("Attachment", { Name = "GuideAttachment", Position = Vector3.new(1, 0, 0) }, slot)
		local tag = make("BillboardGui", {
			Name = "SideTag",
			Size = UDim2.fromScale(6, 1.5),
			StudsOffsetWorldSpace = Vector3.new(0, 3.5, 0),
			MaxDistance = 90,
			LightInfluence = 0,
		}, slot)
		label(tag, { Text = string.upper(side), TextColor3 = side == "White" and COLORS.text or COLORS.gold })
	end

	local anchor = part(pad, "StatusAnchor", Vector3.new(1, 1, 1), at(px, 10, pz), COLORS.neon, NEON)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	local status = make("BillboardGui", {
		Name = "Status",
		Size = UDim2.fromScale(16, 5),
		MaxDistance = 220,
		LightInfluence = 0,
	}, anchor)
	label(status, { Name = "Title", Text = "MATCH " .. i, TextColor3 = COLORS.gold, Size = UDim2.fromScale(1, 0.55) })
	label(status, { Name = "Status", Text = "0/2 PLAYERS", Size = UDim2.fromScale(1, 0.45), Position = UDim2.fromScale(0, 0.55) })
end

---------------------------------------------------------------- info boards

local boards = group("Boards", lobby)
local function infoBoard(name, x, z, face)
	local model = group(name, boards)
	for _, dz in ipairs({ -11, 11 }) do
		part(model, "Post", Vector3.new(1.5, 21, 1.5), at(x, 10.5, z + dz), COLORS.stone, Enum.Material.Slate)
	end
	part(model, "Frame", Vector3.new(1.4, 15, 25), at(x, 14, z), COLORS.gold, SMOOTH)
	local screen = part(model, "Screen", Vector3.new(1.6, 14, 24), at(x, 14, z), COLORS.stone, SMOOTH)
	return surfaceGui(screen, face, 25)
end

local howTo = infoBoard("HowToPlay", -64, 30, Enum.NormalId.Right)
label(howTo, { Text = "HOW TO PLAY", TextColor3 = COLORS.gold, Size = UDim2.fromScale(1, 0.18) })
label(howTo, {
	Text = "1. Follow the glowing arrows\n2. Stand on a WHITE or BLACK circle\n3. When both circles are filled, the match starts!\n\nChaos events can flip the board at any moment...",
	Size = UDim2.fromScale(0.9, 0.72),
	Position = UDim2.fromScale(0.05, 0.22),
	TextXAlignment = Enum.TextXAlignment.Left,
	TextYAlignment = Enum.TextYAlignment.Top,
})

local leaderboard = infoBoard("Leaderboard", 64, 30, Enum.NormalId.Left)
label(leaderboard, { Text = "TOP PLAYERS", TextColor3 = COLORS.gold, Size = UDim2.fromScale(1, 0.18) })
local list = make("Frame", {
	Name = "List",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(0.9, 0.78),
	Position = UDim2.fromScale(0.05, 0.2),
}, leaderboard)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder }, list)
for i = 1, 10 do
	label(list, { Name = "Row" .. i, Text = "", LayoutOrder = i, Size = UDim2.fromScale(1, 0.1), TextXAlignment = Enum.TextXAlignment.Left })
end

---------------------------------------------------------------- trees around the edge

local trees = group("Trees", lobby, "Folder")
for i = 0, 35 do
	local a = math.rad(i * 10 + 5)
	local r = 125 + (i % 2) * 3
	local base = at(math.sin(a) * r, -0.4, math.cos(a) * r)
	local height = 7 + (i % 3) * 1.5
	local _, top = cylinder(trees, "Trunk", base, 0, 1.8, height, COLORS.trunk, Enum.Material.Wood)
	ball(trees, "Leaves", base * CFrame.new(0, top + 2, 0), 9, COLORS.leaves, SMOOTH)
	ball(trees, "Leaves", base * CFrame.new(1.2, top + 5, 0.6), 6, COLORS.leavesLight, SMOOTH)
end

---------------------------------------------------------------- lighting

pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)
Lighting.ClockTime = 14.5
Lighting.Brightness = 2.5
Lighting.Ambient = Color3.fromRGB(70, 72, 84)
Lighting.OutdoorAmbient = Color3.fromRGB(140, 142, 156)
Lighting.EnvironmentDiffuseScale = 1
Lighting.EnvironmentSpecularScale = 1
Lighting.GlobalShadows = true

local function effect(className, props)
	local e = Lighting:FindFirstChildOfClass(className) or Instance.new(className)
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = Lighting
end
effect("Atmosphere", { Density = 0.28, Offset = 0.1, Haze = 1.2, Glare = 0.2, Color = Color3.fromRGB(199, 220, 255), Decay = Color3.fromRGB(106, 140, 190) })
effect("BloomEffect", { Intensity = 0.5, Size = 24, Threshold = 1.4 })
effect("ColorCorrectionEffect", { Saturation = 0.12, Contrast = 0.06, Brightness = 0.02 })
effect("SunRaysEffect", { Intensity = 0.06, Spread = 0.6 })

---------------------------------------------------------------- done

for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("SpawnLocation") and not d:IsDescendantOf(lobby) then
		warn("[LobbyBuilder] Another SpawnLocation exists at " .. d:GetFullName() .. " — delete or disable it so players spawn at the new lobby.")
	end
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[LobbyBuilder] Built Workspace.ChaosChessLobby with " .. #lobby:GetDescendants() .. " instances.")
