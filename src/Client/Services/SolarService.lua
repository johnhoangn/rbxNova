-- Solar Service client
-- Interfaces solar system swapping with the server
--
-- Dynamese (Enduo)
-- 07.20.2021
-- TODO: See server version, also the request handlers are temporary



local SolarService = {Priority = 95}
local EntityService, EffectService

local Network


local SolarSystem


-- Waits for various systems to prepare for warp
-- @param dt <float>
-- @param enterArgs <table>
-- @return <boolean> preparations completed
local function PromptWarpOkay(dt, enterArgs)
	SolarService.InSystem = false

	-- TODO: Disable controller
    SolarService.WarpPreparing:Fire(dt, enterArgs)
	EntityService:PurgeCache()

	-- TODO: Visually push the old system away to simulate warp movement
	if (SolarSystem ~= nil) then
		SolarSystem:Destroy()
		SolarSystem = nil
	end

    return true
end


-- Called when the player is inserted into a system
-- Receives entity information and asks EntityService to create them
-- DOES NOT ADD INTO SYSTEM. THAT IS DONE AUTOMATICALLY AS ENTITIES
--	ARE CREATED AND SIGNALED BY ENTITYSERVICE
-- @param dt <float>
-- @param systemData <table>
-- @param bases <table>
-- @param entityData <table>
local function HandleSystemInsert(dt, systemData, bases, entityData)
	EntityService:ReceiveEntities(dt, bases, entityData)

	SolarSystem = SolarService.Classes.SolarSystem.new(
		systemData.UniversalPosition,
		systemData.CollisionGroupID
	)

	SolarService.InSystem = true
end


-- Warp completed, process new entities and signal
-- @param dt <float>
-- @param systemData <table>
-- @param bases <table>
-- @param entityData <table>
local function HandleWarpExit(dt, systemData, bases, entityData)
	HandleSystemInsert(dt, systemData, bases, entityData)
	SolarService.WarpExited:Fire(systemData, bases)

    return true
end


-- Retrieves all entities of a type from the current system
-- @param entityType <string>
-- @return <table>
function SolarService:GetEntities(entityType)
	assert(SolarSystem ~= nil, "Attempt to get entities from nil system")
	return SolarSystem.Entities[entityType or "All"]:ToArray()
end


function SolarService:EngineInit()
	Network = self.Services.Network
	EntityService = self.Services.EntityService
	EffectService = self.Services.EffectService

    self.WarpPreparing = self.Classes.Signal.new()
    self.WarpExited = self.Classes.Signal.new()

	self.InSystem = false
end


function SolarService:EngineStart()
	Network:HandleRequestType(Network.NetRequestType.WarpPrepare, PromptWarpOkay)
    Network:HandleRequestType(Network.NetRequestType.WarpExit, HandleWarpExit)
	Network:HandleRequestType(Network.NetRequestType.SystemInsert, HandleSystemInsert)

	-- Automatically insert whatever entity is created into the current system if present
	EntityService.EntityCreated:Connect(function(base)
		if (SolarSystem ~= nil) then
			SolarSystem:AddEntity(EntityService:GetEntity(base))
		end
	end)
end


return SolarService