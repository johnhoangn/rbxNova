-- SolarSystem class, defines an independent render group
--
-- Dynamese (Enduo)
-- 07.20.2021


local Mutex = require(script.Parent.Mutex)
local IndexedMap = require(script.Parent.IndexedMap)
local DeepObject = require(script.Parent.DeepObject)
local SolarSystem = {}
SolarSystem.__index = SolarSystem
setmetatable(SolarSystem, DeepObject)


-- Creates a new solar system
-- @param universalPosition <Vector2>
-- @param collisionGroupID <integer>
function SolarSystem.new(universalPosition, collisionGroupID)
	local self = DeepObject.new({
        UniversalPosition = universalPosition;
        ModLock = Mutex.new();
        CollisionGroupID = collisionGroupID;
        Entities = {
            All = IndexedMap.new();
            EntityStar = IndexedMap.new();
            EntityPlanet = IndexedMap.new();
            EntityShip = IndexedMap.new();
            EntityAsteroid = IndexedMap.new();
            EntityDebris = IndexedMap.new();
			EntityMissile = IndexedMap.new();
			EntityStation = IndexedMap.new();
			EntityWarpgate = IndexedMap.new();
        };
    })

	return setmetatable(self, SolarSystem)
end


-- Adds an entity to this system
-- @param entity <T extends Entity>
function SolarSystem:AddEntity(entity)
    self.ModLock:Lock()
    entity.Base.PrimaryPart.CollisionGroupId = self.CollisionGroupID
    self.Entities.All:Add(entity.Base, entity)
    self.Entities[entity.ClassName]:Add(entity.Base, entity)
    self.ModLock:Unlock()
end


-- Removes an entity from the system's records
-- @param entity <T extends Entity>
function SolarSystem:RemoveEntity(entity)
    self.ModLock:Lock()
    self.Entities.All:Remove(entity.Base)
    self.Entities[entity.ClassName]:Remove(entity.Base)
    self.ModLock:Unlock()
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return SolarSystem end


-- Updates light block positioning
function SolarSystem:UpdateLighting()
end


return SolarSystem
