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


-- Warp completed, process new entities and signal
-- @param dt <float>
-- @param systemData <table>
-- @param bases <table>
-- @param entityData <table>
local function HandleWarpExit(dt, systemData, bases, entityData)
	EntityService:ReceiveEntities(dt, bases, entityData)

	SolarSystem = SolarService.Classes.SolarSystem.new(
		systemData.UniversalPosition,
		systemData.CollisionGroupID
	)

	for _, base in ipairs(bases) do
		SolarSystem:AddEntity(EntityService:GetEntity(base))
	end

	SolarService.WarpExited:Fire(bases)

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
end


function SolarService:EngineStart()
	Network:HandleRequestType(Network.NetRequestType.WarpPrepare, PromptWarpOkay)
    Network:HandleRequestType(Network.NetRequestType.WarpExit, HandleWarpExit)
end


return SolarService