-- Solar Service server
-- Controls solar systems and the things in them as well as sending users between systems
--
-- Dynamese (Enduo)
-- 07.20.2021
-- TODO: All the todos on here as well as warpgates


local SolarService = {Priority = 95}

local Network, EntityService, DataService, ShipService, ReadyService
local Players, PhysicsService

local GalaxyFolder
local Systems
local ActiveUsers


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


-- Track a user's travels across the galaxy
-- @param user <Player>
local function ManageUser(user)
	-- Hold until user is ready to go
	--ShipService:WaitForUserShip(user)
	if (not ReadyService:WaitReady(user, 300)) then
		user:Kick("Took too long to load!")
		return
	end

    -- TODO: Retrieve previous system from data
    local currentSystem = Systems:Get("Sol")
	local systemBases, systemEntityData = PackSystemEntities(currentSystem)

	ActiveUsers:Add(user, {
		System = currentSystem;
	})

	-- User joined, insert into system and signal appropriately
	-- TODO: BigBrother, set position/speed tracking
	-- TODO: Move the ship base via server, do not forget to return network ownership
	currentSystem.Players:Add(user, user)
	Network:FireClient(
		user,
		Network:Pack(
			Network.NetProtocol.Forget,
			Network.NetRequestType.SystemInsert, {
				UniversalPosition = currentSystem.UniversalPosition;
				CollisionGroupID = currentSystem.CollisionGroupID;
			}, systemBases, systemEntityData
		)
	)

	user.AncestryChanged:Connect(function()
		if (user.Parent == nil) then
			ActiveUsers:Get(user).System.Players:Remove(user)
			ActiveUsers:Remove(user)
		end
	end)
end


-- Makes sure the new system is completely independent from others
-- @param systemName <string>
-- @returns <integer>
local function ReserveCollisionGroup(systemName)
	local id = PhysicsService:CreateCollisionGroup(systemName)

	for _, groupInfo in pairs(PhysicsService:GetCollisionGroups()) do
		if (groupInfo.name ~= systemName) then
			PhysicsService:CollisionGroupSetCollidable(groupInfo.name, systemName, false)
		end
	end

	return id
end


-- Creates a new system and logs it
-- @param systemName <string>
-- @param uPosition <Vector2> universal position
-- @param entities <table> array of existing entities to insert
function SolarService:CreateSystem(systemName, entities)
    local uPosition = Vector2.new(0, 0)
    local collisionGroupID = ReserveCollisionGroup(systemName)
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


-- Retrieves a copy of the systems list
-- @returns <Map>
function SolarService:GetAllSystems()
	return Systems:ToMap()
end


-- Warps a user to another system, must handle async errors gracefully
-- @param user <Player>
-- @param newSystem <SolarSystem>
function SolarService:WarpUser(user, newSystem)
    if (user.Character == nil or not user.Character:IsDescendantOf(workspace)) then
        return false
    end

    local oldSystem = ActiveUsers:Get(user).System
    local userEntity = ShipService:GetUserShip(user) -- TODO: Waiting on ShipService
    local okSignal = self.Classes.Signal.new()

    -- TODO: More precision
    local readyTimeout = 5
    local warpTimeout = 5

	-- Prompts the user for confirmation that they want to warp
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

    -- User confirmed and is ready to warp?
    if (not okSignal:Wait()) then
        -- Cancel warp
        return false
    end

	-- Replicate warp preparation (including warping user)
	Network:FireClientList(
        oldSystem.Players:ToArray(),
        Network:Pack(
            Network.NetProtocol.Response,
            Network.NetRequestType.WarpPreparing
            --newSystem:UniversalPosition()
        )
    )

	oldSystem.Players:Remove(user)
    oldSystem:RemoveEntity(userEntity)
    -- wait(10)
	local newSystemPlayers = newSystem.Players:ToArray()
	local newSystemBases, newSystemEntities = PackSystemEntities(newSystem)
    newSystem:AddEntity(userEntity)
    newSystem.Players:Add(user)

	-- Warp arrival, we're here! Stream entities to the user so their EntityService picks them up
	--	as well as use the request to signal that they have exited warp including where in the system
	--	they exited at
	-- TODO: BigBrother, reset position/speed tracking
	-- TODO: Move the ship base via server, do not forget to return network ownership
    Network:FireClient(
        user,
        Network:Pack(
            Network.NetProtocol.Forget,
            Network.NetRequestType.WarpExit, {
				UniversalPosition = newSystem.UniversalPosition;
				CollisionGroupID = newSystem.CollisionGroupID;
			}, newSystemBases, newSystemEntities
        )
    )

	-- Replicate warp arrival
	Network:FireClientList(
        newSystemPlayers,
        Network:Pack(
            Network.NetProtocol.Forget,
            Network.NetRequestType.WarpExited,
            userEntity.Base
        )
    )

    return true
end


function SolarService:EngineInit()
	Network = self.Services.Network
    EntityService = self.Services.EntityService
    -- DataService = self.Services.DataService
	ReadyService = self.Services.ReadyService
	ShipService = self.Services.ShipService

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