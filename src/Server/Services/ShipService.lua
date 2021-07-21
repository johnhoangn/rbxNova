-- Ship service server, keeps track of all ships as well as controls NPC vessels (that are server-sided)
-- NPC Vessel control may be done with a neural network... We'll see as development continues
--
-- Dynamese (Enduo)
-- 07.20.2021



local ShipService = {}
local AssetService, SolarService, EntityService
local Players

local NPCShips, NPCShipsMutex, NPCProcessJobID
local UserShips, UserShipsMutex
local ActiveUsers


-- Manages a user and gives them their ship
-- TODO: Only provide a vessel when the user departs a station OR logged off in space
-- TODO: Remove the user's vessel when they enter a station
-- @param user <Player>
local function ManageUser(user)
    if (not user.Character) then user.CharacterAdded:Wait() end

    -- TODO: Load ship data from DataService
    local shipBaseID = "061"
    local shipAsset = AssetService:GetAsset(shipBaseID)
    local shipConfig = shipAsset.DefaultConfig
    local ship = ShipService:CreateShip("061", shipConfig)
    local system = SolarService:GetSystem("Sol")

    -- TODO: Load system data from DataService
    SolarService:AddEntity(system, ship)
    ship:PlaceAt(user.Character.PrimaryPart.CFrame)
    ship.Base.Name = string.format("%s's %s", user.Name, ship.Base.Name)

    ShipService.Modules.WeldUtil:WeldParts(user.Character.PrimaryPart, ship.Base.PrimaryPart)
    user.Character.Humanoid.PlatformStand = true

    ActiveUsers:Add(user, {
        Ship = ship;
    })
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
    NPCShipsMutex:Release()
end


-- Creates a new ship base to stick the ship to, instantiates the EntityShip
--  and makes a record of it.
-- NOTE: The new ship must be placed into a SolarSystem
-- @param baseID <string>
-- @param config <table>
-- @param user <Player> == nil, user that owns this vessel
function ShipService:CreateShip(baseID, config, user)
    local base = AssetService:GetAsset("060").Model:Clone()
    local ship = EntityService:CreateEntity(base, "EntityShip", { _BaseID = baseID; Config = config; User = user})
    local hitboxes = ship._Asset.Hitboxes:Clone()

    -- Hitboxes (will be deleted on locally clients)
    hitboxes:SetPrimaryPartCFrame(base.PrimaryPart.CFrame)
    self.Modules.WeldUtil:WeldParts(hitboxes.PrimaryPart, base.PrimaryPart)
    hitboxes.Parent = base

    -- TODO: load and fix attachments' roots so that turrets have a reference to shoot from

    -- Finalized
    base.Name = ship._Asset.AssetName
    base.Parent = workspace

    -- Record
    if (user) then
        UserShipsMutex:Lock()
        UserShips:Add(base, ship)
        UserShipsMutex:Release()
    else
        NPCShipsMutex:Lock()
        NPCShips:Add(base, ship)
        NPCShipsMutex:Release()

        NPCProcessJobID = self.Services.MetronomeService:BindToFrequency(15, ProcessNPCShips)
    end

    self.ShipCreated:Fire(base)

    return ship
end


-- Retrieves a ship
-- @param base <Model>
-- @returns <EntityShip>
function ShipService:GetShip(base)
    return NPCShips:Get(base) or UserShips:Get(base)
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

    Players = self.RBXServices.Players

    NPCShipsMutex = self.Classes.Mutex.new()
    UserShipsMutex = self.Classes.Mutex.new()
    NPCShips = self.Classes.IndexedMap.new()
    UserShips = self.Classes.IndexedMap.new()
    ActiveUsers = self.Classes.IndexedMap.new()

    self.ShipCreated = self.Classes.Signal.new()
end


function ShipService:EngineStart()
	Players.PlayerAdded:Connect(ManageUser)
    for _, user in ipairs(Players:GetPlayers()) do
        ManageUser(user)
    end
end


return ShipService