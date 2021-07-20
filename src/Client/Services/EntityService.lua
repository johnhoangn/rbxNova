-- Entity service, client
-- Responsible of keeping track of all entities present in the player's cache
--  as well as rendering them
--
-- Dynamese (Enduo)



local SQRT = math.sqrt
local RENDER_DISTANCE = 400


local EntityService = {Priority = 100}
local Network, MetronomeService
local CollectionService
local ThreadUtil

local Camera
local RenderOrigin

local AllEntities
local VisibleEntities
local CachedEntities
local CacheMutex
local RenderJobID


-- Retrieves distance to entity
-- @param entity <Entity>
-- @retuns <float>
local function DistanceTo(entity)
    local realPos = entity:RealPosition()
    return SQRT((realPos.X - RenderOrigin.X)^2 + (realPos.Y - RenderOrigin.Y)^2)
end


-- Tasker to draw/cache entities
-- @param dt <float>
local function RenderJob(dt)
    RenderOrigin.X = Camera.CFrame.Position.X
    RenderOrigin.Y = Camera.CFrame.Position.Z -- Transforming Z axis to Y
    CacheMutex:Lock()

    for base, entity in CachedEntities:KeyIterator() do
        if (DistanceTo(entity) < RENDER_DISTANCE) then
            EntityService:LoadEntity(base)
        end
    end

    for base, entity in VisibleEntities:KeyIterator() do
        -- entity:SetOpacity()
        if (DistanceTo(entity) < RENDER_DISTANCE) then
            --ThreadUtil.Spawn(entity.Draw, entity)
            entity:Draw()
        else
            EntityService:CacheEntity(base)
        end
    end

    CacheMutex:Release()
end


-- Reconstructs entities from information sent by the server
-- @param dt <float>
-- @param entities <table>, {<Model> = {Type = <string>; InitialParams = <table>}}
local function ReceiveEntities(dt, bases, entityInfo)
    CacheMutex:Lock()
    for i, base in pairs(bases) do
        local info = entityInfo[i]

        CachedEntities:Add(base,
            EntityService:CreateEntity(
                base,
                info.Type,
                info.InitialParams,
                true
            )
        )
    end
    CacheMutex:Release()
end


-- Retrieves an entity
-- @param base <Model>
-- @returns <T extends Entity>
function EntityService:GetEntity(base)
    return AllEntities:Get(base)
end


-- Creates a new entity and notifies all present players
-- @param base <Model>
-- @param entityType <string>
-- @param entityParams <table>
-- @param noLock <boolean> == false, calling thread owns lock; saves excessive calls and locking
-- @returns <T extends Entity>
function EntityService:CreateEntity(base, entityType, entityParams, noLock)
    local newEntity = self.Classes[entityType].new(base, entityParams)

    if (not noLock) then
        CacheMutex:Lock()
    end

    AllEntities:Add(base, newEntity)

    if (not noLock) then
        CacheMutex:Release()
    end

    self.EntityCreated:Fire(base)

    return newEntity
end


-- Removes an entity and its physical base
-- @param base <Model>
function EntityService:DestroyEntity(base)
    local entity = AllEntities:Get(base)

    if (entity ~= nil) then
        AllEntities:Remove(base)
        CachedEntities:Remove(base)
        VisibleEntities:Remove(base)

        self.EntityDestroyed:Fire(base)
        entity:Destroy()
    end
end


-- Removes all entities from the cache
--  useful for debugging as well as inter-system travel
-- @returns <integer> number of entries purged
function EntityService:PurgeCache()
    local size = AllEntities.Size

    CacheMutex:Lock()
    for base, _ in AllEntities:KeyIterator() do
        AllEntities:Remove(base)
        CachedEntities:Remove(base)
        VisibleEntities:Remove(base)
    end
    CacheMutex:Release()

    return size
end


-- Methods to move entities from cache/render
-- THREAD-UNSAFE, MAKE SURE TO LOCK/UNLOCK CACHEMUTEX
-- @param base <Model>
function EntityService:LoadEntity(base)
    local entity = CachedEntities:Remove(base)
    -- Entity may have been destroyed by the time we got the lock
    if (entity ~= nil) then
        VisibleEntities:Add(base, entity)
    end
end
function EntityService:CacheEntity(base)
    local entity = VisibleEntities:Remove(base)
    -- Entity may have been destroyed by the time we got the lock
    if (entity ~= nil) then
        entity:Hide()
        CachedEntities:Add(base, entity)
    end
end


function EntityService:Enable(boolean)
    if (boolean) then
        -- TODO: configuration for render-update-rate
        RenderJobID = MetronomeService:BindToFrequency(15, RenderJob)
    else
        MetronomeService:Unbind(RenderJobID)
    end

    self.Enabled = boolean
end


function EntityService:EngineInit()
    Network = self.Services.Network
    MetronomeService = self.Services.MetronomeService
	CollectionService = self.RBXServices.CollectionService

    ThreadUtil = self.Modules.ThreadUtil

    Camera = workspace.CurrentCamera
    RenderOrigin = {
        X = Camera.CFrame.Position.X,
        Y = Camera.CFrame.Position.Y
    }

    AllEntities = self.Classes.IndexedMap.new()
    CachedEntities = self.Classes.IndexedMap.new()
    VisibleEntities = self.Classes.IndexedMap.new()
    CacheMutex = self.Classes.Mutex.new()

    self.EntityCreated = self.Classes.Signal.new()
    self.EntityDestroyed = self.Classes.Signal.new()

    self.Enabled = false
end


function EntityService:EngineStart()
    self:Enable(true)

    Network:HandleRequestType(Network.NetRequestType.EntityStream, ReceiveEntities)
end


return EntityService