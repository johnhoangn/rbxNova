-- Ship service client, keeps track of and controls the user's ship
-- NPC Vessel control may be done with a neural network... We'll see as development continues
--
-- Dynamese (Enduo)
-- 07.20.2021



local ShipService = {}
local EntityService, MetronomeService

local UserShip, ProcessJobID


-- Own ship updater job
-- @param dt <float>
local function ProcessUserShip(dt)
    UserShip:UpdatePhysics(dt)
end


-- Waits for EntityService to create our ship and saves it
-- @param base <Model>
-- @returns <boolean> success
function ShipService:SetShip(base)
    local ship = EntityService:WaitEntity(base)

    if (ship ~= nil) then
        UserShip = ship
        ProcessJobID = MetronomeService:BindToFrequency(60, ProcessUserShip)
        self.ShipCreated:Fire(base)

        return true
    else
       return false
    end
end


-- Retrieves the user's ship
-- @returns <EntityShip>
function ShipService:GetShip()
    return UserShip
end


-- Destroys the user's ship
function ShipService:RemoveShip()
    if (UserShip ~= nil) then
        MetronomeService:Unbind(ProcessJobID)
        UserShip:Destroy()
        UserShip = nil
        ProcessJobID = nil
    end
end


function ShipService:EngineInit()
    EntityService = self.Services.EntityService
    MetronomeService = self.Services.MetronomeService

    self.ShipCreated = self.Classes.Signal.new()
end


function ShipService:EngineStart()

end


return ShipService