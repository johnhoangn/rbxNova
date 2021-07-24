local TurretService = {Priority = 81}

local Network, SyncRandomService, ShipService


-- Creates a list of random numbers [0, 1) of length num
-- @param randUID <string> to draw random numbers from
-- @param num <integer> how many randoms to generate
local function GenerateUserRandoms(randUID, user, num, randoms)
    for i = 1, num do
        -- The more proper approach to generating spread values is by using
        --  one Random instance per turret, but that's a headache of housekeeping
        --  so we'll be using one instance for all turrets ever fired
        randoms[i] = SyncRandomService:NextNumber(randUID, user, randoms[i])
    end

    return randoms
end


-- Fires a user's turret
-- @param user <Player> who shot the turret
-- @param dt <float> time it took for the request to reach the server
-- @param section <string> section of the ship the user is shooting from
-- @param turretUID <string> uid of the turret the user is shooting
-- @param target <BasePart> part the user is shooting at
-- @param randUID <string> uid of the random seed the user used to generate numbers
-- @param randoms <table> of user generated randoms
function TurretService:FireUserTurret(user, dt, section, turretUID, target, randUID, randoms)
    local ship = ShipService:GetUserShip(user)
    local turretModel = ship.Base.Hardpoints[section].Attachments[turretUID]
    local turretBaseID = ship.InitialParams.Config.Sections[section].Attachments[turretUID].BaseID
    local turretAsset = self.Services.AssetService:GetAsset(turretBaseID)
    local projectileClass = self.Classes["Projectile" .. turretAsset.Type]
    local projectile = projectileClass.new(
        turretAsset,
        turretModel,
        target,
        GenerateUserRandoms(randUID, user, projectileClass.RandomsNeeded, randoms)
    )

    projectile:Fire(dt, user)
end


function TurretService:EngineInit()
	Network = self.Services.Network
    SyncRandomService = self.Services.SyncRandomService
    ShipService = self.Services.ShipService
end


function TurretService:EngineStart()
	Network:HandleRequestType(
        Network.NetRequestType.Test,
        function(user, dt, section, turretUID, target, randUID, randoms)
            self:Fire(user, dt, section, turretUID, target, randUID, randoms)
        end
    )
end


return TurretService