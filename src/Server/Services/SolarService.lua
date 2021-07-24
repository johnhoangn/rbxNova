-- Solar Service server
-- Controls solar systems and the things in them as well as sending users between systems
--
-- Dynamese (Enduo)
-- 07.20.2021
-- TODO: All the todos on here as well as warpgates


local SolarService = {Priority = 95}

local Network, EntityService, DataService
local Players, PhysicsService

local GalaxyFolder
local Systems
local ActiveUsers


-- Track a user's travels across the galaxy
-- @param user <Player>
local function ManageUser(user)
    -- TODO: Retrieve previous system from data
    local currentSystem = Systems:Get("Sol")

    ActiveUsers:Add(user, {
        System = currentSystem;
    })

    currentSystem.Players:Add(user, user)
    SolarService:StreamEntities(user, currentSystem)

    user.AncestryChanged:Connect(function()
        if (user.Parent == nil) then
            ActiveUsers:Get(user).System.Players:Remove(user)
            ActiveUsers:Remove(user)
        end
    end)
end


-- Packs all entities within a system into an array
-- @param system <SolarSystem>
-- @returns <table> <table> arrays containing bases + their entity info respectively
local function PackSystemEntities(system)
    local bases = {}

	for base, _ in system.Entities.All:KeyIterator() do
        table.insert(bases, base)
    end

    return bases, EntityService:PackEntityInfo(bases)
end


-- Creates a new system and logs it
-- @param systemName <string>
-- @param uPosition <Vector2> universal position
-- @param entities <table> array of existing entities to insert
function SolarService:CreateSystem(systemName, entities)
    local uPosition = Vector2.new(0, 0)
    local collisionGroupID = PhysicsService:CreateCollisionGroup(systemName)
    local newSystem = self.Classes.SolarSystem.new(uPosition, collisionGroupID)

    newSystem.Players = self.Classes.IndexedMap.new();

    for _, entity in ipairs(entities) do
        newSystem:AddEntity(entity)
    end

    Systems:Add(systemName, newSystem)

    return newSystem
end


-- If all we have is a part, we have its collisionGroupID to retrieve its system
-- @param collisionGroupID <integer>
-- @returns <SolarSystem>
function SolarService:GetSystemFromPhysicsGroupID(collisionGroupID)
    for _, system in Systems:Iterator() do
        if (system.CollisionGroupID == collisionGroupID) then
            return system
        end
    end

    return nil
end


-- Streams all entities within a system to a user
-- @param user <Player>
-- @param system <SolarSystem>
function SolarService:StreamEntities(user, system)
    local bases, entities = PackSystemEntities(system)

    Network:FireClient(
        user,
        Network:Pack(
            Network.NetProtocol.Forget,
            Network.NetRequestType.EntityStream,
            bases,
            entities
        )
    )
end


-- Injects an entity into a system and notifies relevant users
-- @param system <SolarSystem>
-- @param entity <T extends Entity>
function SolarService:AddEntity(system, entity)
    system:AddEntity(entity)

    local packet = Network:Pack(
        Network.NetProtocol.Forget,
        Network.NetRequestType.EntityStream,
        {entity.Base},
        EntityService:PackEntityInfo({entity.Base})
    )

    Network:FireClientList(system.Players:ToArray(), packet)
end


-- Creates a new entity and injects it into a system
-- @param system <SolarSystem>
-- @param sPosition <Vector2> solar position to place the entity
-- @param base <Model>
-- @param entityType <string>
-- @param entityParams <table>
function SolarService:CreateEntity(system, sPosition, base, entityType, entityParams)
    local entity = EntityService:CreateEntity(base, entityType, entityParams)
    self:AddEntity(system, entity)
end


-- Retrieves a system via name
-- @param systemName <string>
-- @returns <SolarSystem>
function SolarService:GetSystem(systemName)
    return Systems:Get(systemName)
end


-- Warps a user to another system, must handle async errors gracefully
-- @param user <Player>
-- @param newSystem <SolarSystem>
function SolarService:WarpUser(user, newSystem)
    if (user.Character == nil or not user.Character:IsDescendantOf(workspace)) then
        return false
    end

    local oldSystem = ActiveUsers:Get(user).System
    -- local userEntity = EntityService:GetEntity(user.Character) -- TODO: Waiting on ShipService
    local okSignal = self.Classes.Signal.new()

    -- TODO: More precision
    local readyTimeout = 5
    local warpTimeout = 5

    Network:FireClient(
        user,
        Network:Pack(
            Network.NetProtocol.Response,
            Network.NetRequestType.WarpPrepare
            --newSystem:UniversalPosition()
        ),
        function(responded, user, dt, warpOK)
            okSignal:Fire(responded and warpOK)
        end,
        readyTimeout
    )

    -- User disabled renderer and is ready to warp?
    if (not okSignal:Wait()) then
        -- Cancel warp
        return false
    end

    oldSystem.Players:Remove(user)
    -- oldSystem:RemoveEntity(userEntity)
    -- wait(10)
    -- newSystem:AddEntity(userEntity)
    newSystem.Players:Add(user)

    Network:FireClient(
        user,
        Network:Pack(
            Network.NetProtocol.Response,
            Network.NetRequestType.WarpExit,
            nil
        ),
        function(responded, user, dt, arriveOK)
            okSignal:Fire(responded and arriveOK)
        end,
        warpTimeout
    )

    -- User arrived safe and sound?
    if (not okSignal:Wait()) then
        -- Nope, undo the warp if the user is still here
        if (ActiveUsers:Get(user) ~= nil) then
            newSystem.Players:Remove(user)
            -- newSystem:RemoveEntity(userEntity)
            oldSystem.Players:Add(user)
            -- oldSystem:AddEntity(userEntity)
        end

        return false
    end

    -- We're here! Stream entities to user
    self:StreamEntities(user, newSystem)

    return true
end


function SolarService:EngineInit()
	Network = self.Services.Network
    EntityService = self.Services.EntityService
    -- DataService = self.Services.DataService

    Players = self.RBXServices.Players
    PhysicsService = self.RBXServices.PhysicsService

    GalaxyFolder = workspace.Galaxy

    Systems = self.Classes.IndexedMap.new()
    ActiveUsers = self.Classes.IndexedMap.new()
end


function SolarService:EngineStart()
    -- Create a solar system instance per prefab folder
	for _, systemFolder in ipairs(GalaxyFolder:GetChildren()) do
        local entities = {}

        for _, bodies in ipairs(systemFolder:GetChildren()) do
            for _, body in ipairs(bodies:GetChildren()) do
                table.insert(entities, EntityService:GetEntity(body))
            end
        end

        self:CreateSystem(systemFolder.Name, entities)
    end

    Players.PlayerAdded:Connect(ManageUser)
    for _, user in ipairs(Players:GetPlayers()) do
        ManageUser(user)
    end

    -- Streams information on entities to a user
    -- @param user <Player>
    -- @param dt <float>
    -- @param bases <table>, arraylike
    -- @returns <table>
    Network:HandleRequestType(
        Network.NetRequestType.EntityStream,
        function(user, dt)
            local system = Systems:Get(user)

            assert(system ~= nil, "USER NOT IN A SYSTEM!? " .. user.Name)

            return PackSystemEntities(system)
        end
    )

    Network:HandleRequestType(
        Network.NetRequestType.EntityRequest,
        function(user, dt, base)
            local system = ActiveUsers:Get(user).System
            local entity = system.Entities.All:Get(base)

            if (entity ~= nil) then
                local packet = Network:Pack(
                    Network.NetProtocol.Forget,
                    Network.NetRequestType.EntityStream,
                    {entity.Base},
                    EntityService:PackEntityInfo({entity.Base})
                )

                Network:FireClient(user, packet)
            end

            return nil
        end
    )
end


return SolarService