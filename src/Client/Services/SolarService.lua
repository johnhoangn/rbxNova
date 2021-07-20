-- Solar Service client
-- Interfaces solar system swapping with the server
--
-- Dynamese (Enduo)
-- 07.20.2021
-- TODO: See server version, also the request handlers are temporary



local SolarService = {Priority = 95}

local Network


-- Waits for various systems to prepare for warp
-- @param dt <float>
-- @param enterArgs <table>
-- @return <boolean> preparations completed
local function PromptWarpOkay(dt, enterArgs)
    SolarService.WarpPreparing:Fire(dt, enterArgs)
    SolarService.Services.EntityService:PurgeCache()
    return true
end


-- Signals a warp completion
-- @param dt <float>
-- @param exitArgs <table>
local function SignalWarpExit(dt, exitArgs)
    SolarService.WarpExited:Fire(dt, exitArgs)
    return true
end


function SolarService:EngineInit()
	Network = self.Services.Network

    self.WarpPreparing = self.Classes.Signal.new()
    self.WarpExited = self.Classes.Signal.new()
end


function SolarService:EngineStart()
	Network:HandleRequestType(Network.NetRequestType.WarpPrepare, PromptWarpOkay)
    Network:HandleRequestType(Network.NetRequestType.WarpExit, SignalWarpExit)
end


return SolarService