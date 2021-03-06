-- Ship service server, keeps track of all ships as well as controls NPC vessels (that are server-sided)
-- NPC Vessel control may be done with a neural network... We'll see as development continues
--
-- Dynamese (Enduo)
-- 07.20.2021



local ShipService = {Priority = 80}
local AssetService, SolarService, EntityService, Network, DataService
local Players

local HardpointType
local NPCShips, NPCShipsMutex, NPCProcessJobID
local UserShips, UserShipsMutex
local ActiveUsers


-- Manages a user and gives them their ship
-- TODO: Only provide a vessel when the user departs a station OR logged off in space
-- TODO: Remove the user's vessel when they enter a station
-- TODO: Put the user's ship at their last known solar position and orientation
-- @param user <Player>
local function ManageUser(user)
    if (not user.Character) then user.CharacterAdded:Wait() end

    local userData = DataService:GetData(user)
    local shipData = userData.CurrentShip

    -- TODO: Load ship config instead of default config
    -- TODO: Load ship status from shipData.Status

    local shipBaseID = shipData.BaseID
    local shipAsset = AssetService:GetAsset(shipBaseID)
	local system = SolarService:GetSystem(userData.Whereabouts.System)
    local ship = ShipService:CreateShip(shipBaseID, require(shipAsset.DefaultConfig), system, nil, user)

    --ship:PlaceAt(user.Character.PrimaryPart.CFrame)
    ship.Base.Name = string.format("%s", user.UserId)
    ship.Base.PrimaryPart:SetNetworkOwner(user)

    ActiveUsers:Add(user, {
        Ship = ship;
    })

    user.AncestryChanged:Connect(function()
        if (not user:IsDescendantOf(Players)) then
            ActiveUsers:Remove(user)
        end
    end)

    -- TODO: Take control if the user leaves, and return it if they rejoin

    local attemptsLeft = 3
    local function TryGiveControl()
        Network:FireClient(user,
            Network:Pack(
                Network.NetProtocol.Response,
                Network.NetRequestType.ShipControl,
                ship.Base
            ),
            function (responded, user, dt, success)
                if (not responded or not success) then
                    if (attemptsLeft > 0) then
                        wait(1)
                        TryGiveControl()
                        attemptsLeft -= 1
                    else
                        user:Kick("ERR_SHIP_ACCESS_FAILURE")
                    end
                end
            end, 5
        )
    end

    TryGiveControl()
end


-- NPC ship updater job
-- @param dt <float>
local function ProcessNPCShips(dt)
    -- This operation has no yielding code, but in the very
    --  unlikely scenario that the scheduler decides to interupt
    --  this iteration, lock it so nothing bad happens
    NPCShipsMutex:Lock()
    for _, ship in NPCShips:Iterator() do
        ship:UpdatePhysics(dt)
    end
    NPCShipsMutex:Unlock()
end


-- Creates a new ship base to stick the ship to, instantiates the EntityShip
--  and makes a record of it.
-- NOTE: The new ship must be placed into a SolarSystem
-- @param baseID <string>
-- @param config <table>
-- @param system <SolarSystem>
-- @param status <table> == nil, information on the ship's status; defaults to asset values
-- @param user <Player> == nil, user that owns this vessel
function ShipService:CreateShip(baseID, config, system, status, user)
    local asset = AssetService:GetAsset(baseID)
    local base = AssetService:GetAsset("060").Model:Clone()

    -- Handle attributes
    base:SetAttribute("ThrustCoaxial", asset.ShipData.ThrustCoaxial)
    base:SetAttribute("ThrustLateral", asset.ShipData.ThrustLateral)
    base:SetAttribute("ThrustYaw", asset.ShipData.ThrustYaw)
    base:SetAttribute("SpeedFwd", asset.ShipData.SpeedFwd)
    base:SetAttribute("SpeedRev", asset.ShipData.SpeedRev)
    base:SetAttribute("SpeedYaw", asset.ShipData.SpeedYaw)

    for section, sectionData in pairs(config.Sections) do
        base:SetAttribute("MaxShield" .. section, sectionData.Shield)
        base:SetAttribute("MaxArmor" .. section, sectionData.Armor)
        base:SetAttribute("MaxHull" .. section, asset.ShipData.Sections[section].Hull)
        base:SetAttribute("Shield" .. section, sectionData.Shield)
        base:SetAttribute("Armor" .. section, sectionData.Armor)
        base:SetAttribute("Hull" .. section, asset.ShipData.Sections[section].Hull)
    end

    local ship = EntityService:CreateEntity(base, "EntityShip", {
        _BaseID = baseID;
        Config = config;
        User = user;
    })

    local hitboxes = asset.Hitboxes:Clone()
    local hardpoints = asset.Hardpoints:Clone()
	local turrets = self.Classes.IndexedMap.new()

    -- Hitboxes (will be deleted locally on clients)
    hitboxes:SetPrimaryPartCFrame(base.PrimaryPart.CFrame)
    self.Modules.WeldUtil:WeldParts(hitboxes.PrimaryPart, base.PrimaryPart)
    hitboxes.Parent = base

    -- Hardpoints, used for hit detection
    -- TODO: in ship combat: add AND subtract ship's velocity * ping for origins of two raycasts as a barebones netcode solution
    hardpoints:SetPrimaryPartCFrame(base.PrimaryPart.CFrame)
    self.Modules.WeldUtil:WeldParts(hardpoints.PrimaryPart, base.PrimaryPart)
    hardpoints.Parent = base

    for section, sectionData in pairs(config.Sections) do
        local modelSection = hardpoints:FindFirstChild(section)

        if (modelSection == nil) then continue end
        for uid, attachmentData in pairs(sectionData.Attachments) do
            if (attachmentData.Hardpoint ~= nil) then
				local attachAsset = AssetService:GetAsset(attachmentData.BaseID)
                local hardpoint = modelSection[attachmentData.Hardpoint]
				local hardpointType = hardpoint.Type.Value

				-- The attachment won't be here if it weren't allowed to be placed in the first place
				--	so just check the hardpoint type
				if (hardpointType == self.Enums.HardpointType.Energy
					or hardpointType == self.Enums.HardpointType.Ballistic) then

					turrets:Add(uid,
						self.Classes.Turret.new(
							hardpoint,
							uid,
							attachAsset,
							attachAsset.TurnSpeed,
							NumberRange.new(hardpoint.YawMin.Value, hardpoint.YawMax.Value),
							NumberRange.new(hardpoint.PitchMin.Value, hardpoint.PitchMax.Value)
						)
					)
				end
            end
        end
    end

	ship.Turrets = turrets

    -- Finalized
    base.Name = ship._Asset.AssetName
    base.Parent = workspace

    -- Record
    if (user) then
        UserShipsMutex:Lock()
        UserShips:Add(base, ship)
        UserShipsMutex:Unlock()
    else
        NPCShipsMutex:Lock()
        NPCShips:Add(base, ship)
        NPCShipsMutex:Unlock()

        NPCProcessJobID = self.Services.MetronomeService:BindToFrequency(15, ProcessNPCShips)
    end

	SolarService:AddEntity(system, ship)
    self.ShipCreated:Fire(base, user)

    return ship
end


-- Retrieves a ship
-- @param base <Model>
-- @returns <EntityShip>
function ShipService:GetShip(base)
    return NPCShips:Get(base) or UserShips:Get(base)
end


-- Retrieves a user's ship
-- @param user <Player>
-- @returns <EntityShip>
function ShipService:GetUserShip(user)
	local record = ActiveUsers:Get(user)
    return record and record.Ship
end

-- Retrieves a user's ship or waits until it exists
-- @param user <Player>
-- @param timeout <float> == 30
-- @returns <EntityShip>
function ShipService:WaitForUserShip(user, timeout)
	local ship = self:GetUserShip(user)

	if (ship ~= nil) then
		return ship
	else
		local returned = false
		local retrieved = self.Classes.Signal.new()
		local tempConn = self.ShipCreated:Connect(function(base, _user)
			if (_user == user) then
				retrieved:Fire(true)
			end
		end)

		self.Modules.ThreadUtil.Delay(timeout or 5, function()
			if (not returned) then
				retrieved:Fire(false)
			end
		end)

		returned = retrieved:Wait()
		tempConn:Disconnect()

		return self:GetUserShip(user)
	end
end


-- Destroys a ship
-- @param base <Model>
function ShipService:RemoveShip(base)
    local ship = self:GetShip(base)

    if (ship ~= nil) then
        ship:Destroy()
        if (ship.User) then
            UserShips:Remove(base)
        else
            NPCShips:Remove(base)

            if (NPCShips.Size == 0) then
                self.Services.MetronomeService:Unbind(NPCProcessJobID)
            end
        end
    end
end


function ShipService:EngineInit()
    AssetService = self.Services.AssetService
    SolarService = self.Services.SolarService
    EntityService = self.Services.EntityService
    Network = self.Services.Network
    DataService = self.Services.DataService

    Players = self.RBXServices.Players

    NPCShipsMutex = self.Classes.Mutex.new()
    UserShipsMutex = self.Classes.Mutex.new()
    NPCShips = self.Classes.IndexedMap.new()
    UserShips = self.Classes.IndexedMap.new()
    ActiveUsers = self.Classes.IndexedMap.new()

    self.ShipCreated = self.Classes.Signal.new()

	HardpointType = self.Enums.HardpointType
end


function ShipService:EngineStart()
	Players.PlayerAdded:Connect(ManageUser)
    for _, user in ipairs(Players:GetPlayers()) do
        self.Modules.ThreadUtil.Spawn(function()
            ManageUser(user)
        end)
    end
end


return ShipService