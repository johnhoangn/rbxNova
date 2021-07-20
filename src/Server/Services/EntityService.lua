-- Entity service, server
-- Responsible of keeping track of all entities present in the game
--
-- Dynamese (Enduo)
-- 07.19.2021



local EntityService = {Priority = 100}
local Network, AssetService
local CollectionService, Players


local AllEntities
local CacheMutex


-- Creates an entity based on a prefabricated entity
-- e.g. the galaxy during dev
-- @param base <Model>
local function Prefab(base)
    local entityParams = {}

    for _, parameter in ipairs(base.Configuration:GetChildren()) do
        entityParams[parameter.Name] = parameter.Value
    end

    local classID = entityParams._BaseID:sub(1, 2)
    local entityType = AssetService:GetClassName(classID)

    return EntityService.Classes[entityType].new(base, entityParams)
end


-- Grabs necessary information that would enable clients to
--  reconstruct all entities from the bases given
-- @param bases <table>, list of entity information
-- @returns <table>
local function PackEntityInfo(bases)
    local entities = {}

    -- Pack only relevant info, omitting functions and signals
    CacheMutex:Lock()
    for i, base in ipairs(bases) do
        local entity =  EntityService:GetEntity(base)
        entities[i] = {
            Type = entity.ClassName;
            InitialParams = entity._InitialParams;
        }
    end
    CacheMutex:Release()

    return entities
end


-- Retrieves an entity
-- @param base <Model>
-- @returns <T extends Entity>
function EntityService:GetEntity(base)
    return AllEntities:Get(base)
end


-- Retrieves a list of entities
-- @param bases <table>
-- @returns <table>
function EntityService:GetEntities(bases)
    local entities = {}

    for i, base in ipairs(bases) do
        entities[i] = self:GetEntity(base)
    end

    return entities
end


-- Creates a new entity and notifies all present players
-- @param base <Model>
-- @param entityType <string>
-- @param entityParams <table>
-- @returns <T extends Entity>
function EntityService:CreateEntity(base, entityType, entityParams)
    local newEntity = self.Classes[entityType].new(base, entityParams)

    CacheMutex:Lock()
    AllEntities:Add(base, newEntity)
    CacheMutex:Release()
    self.EntityCreated:Fire(base)

    -- Communicate the change
    -- TODO: Remove this after SolarService is up and send only to users in the same system
    for _, user in ipairs(Players:GetPlayers()) do
        Network:FireClient(
            user, 0,
            Network:Pack(
                Network.NetProtocol.None,
                Network.NetRequestType.EntityStream,
                PackEntityInfo({base})
            )
        )
    end

    return newEntity
end


-- Removes an entity and its physical base
-- @param base <Model>
function EntityService:DestroyEntity(base)
    local entity = AllEntities:Get(base)

    if (entity ~= nil) then
        AllEntities:Remove(base)
        self.EntityDestroyed:Fire(base)
        entity:Destroy()

        -- entity destroyed replication automatically handled when "base"
        --  is destroyed and that state is communicated via Roblox
    end
end


function EntityService:EngineInit()
    AssetService = self.Services.AssetService
    Network = self.Services.Network
	CollectionService = self.RBXServices.CollectionService
    Players = self.RBXServices.Players

    CacheMutex = self.Classes.Mutex.new()
    AllEntities = self.Classes.IndexedMap.new()

    self.EntityCreated = self.Classes.Signal.new()
    self.EntityDestroyed = self.Classes.Signal.new()
end


function EntityService:EngineStart()
	-- Gather galaxy entity placements and log them
    for _, model in ipairs(CollectionService:GetTagged("EntityInit")) do
        AllEntities:Add(model, Prefab(model))
        model.Model:Destroy()
        model.PrimaryPart.Transparency = 1
        model.Configuration:Destroy()
        -- Don't waste memory on storing/replicating the models
    end

    -- Streams information on entities to a user
    -- TODO: Move to SolarService, a user should only have access to entities within the system
    -- @param user <Player>
    -- @param dt <float>
    -- @param bases <table>, arraylike
    -- @returns <table>
    Network:HandleRequestType(
        Network.NetRequestType.EntityStream,
        function(user, dt, bases)
            return bases, PackEntityInfo(bases)
        end
    )


    -- THIS IS TEMPORARY TEST CODE
    delay(5, function()
        local bases = CollectionService:GetTagged("EntityInit")
        local packet = Network:Pack(
            Network.NetProtocol.Forget,
            Network.NetRequestType.EntityStream,
            bases,
            PackEntityInfo(bases)
        )
    
        Network:FireClient(
            Players.Dynamese,
            packet
        )
    end)
end


return EntityService