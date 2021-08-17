-- Turretservice server, responsible for handling every non-player controlled turret in the galaxy
-- On a 5Hz (TBD) frequency, update turret targets if applicable
-- On a 15Hz (TBD) frequency, point turrets with targets, (in code, there will be no servos)
--	and check if they can shoot
--
-- Dynamese (Enduo)
-- 07.25.2021



local TurretService = {Priority = 75}

local Network, SyncRandomService, ShipService, SolarService, EntityService

local ServerRandom
local ManagedEntities, ListLock
local TurretsWithTargets
local TurretJobID
local EntityJobID


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


-- Generates random numbers using the NPC Random instance
-- @param num <integer>
local function GenerateNPCRandoms(num)
	local randoms = table.create(num, 0)

	for i = 1, num do
		randoms[i] = ServerRandom:NextNumber()
	end

	return randoms
end


-- Scans for targets for managed entities
-- @param dt <float>
local function TurretScanner(dt)
	-- For every managed entity:
	--	Retrieve all other entities in the mutual system and cache
	--	Filter hostile/within farthest turret range
	--	Select closest entity to specific turrets
	local systemShipCaches = {}

	-- TODO
end


-- Fires managed entities' turrets if applicable
-- @param dt <float>
local function TurretShooter(dt)
	local now = tick()

	for entityBase, entity in ManagedEntities:KeyIterator() do
		for uid, turret in entity.Turrets:KeyIterator() do
			if (turret:GetTarget() ~= nil) then
				turret:Step(1/30)

				if (turret:CanFire(now)) then
					turret._LastShot = now + turret.Asset.Duration
					TurretService:FireNPCTurret(turret)
				end
			end
		end
	end
end


-- Fires a turret owned by an NPC, all information 
--	is in the turret so the parameters here are simple
-- @param turret <Turret>
function TurretService:FireNPCTurret(turret)
	local projectileClassName = "Projectile" .. turret.Asset.Type
	local projectileClass = self.Classes[projectileClassName]
	local randomsNeeded = self.Modules.ProjectileAlgorithms[projectileClassName].Randoms
	local randoms = GenerateNPCRandoms(randomsNeeded)
	local projectile = projectileClass.new(
		turret,
		randoms,
		nil
	)

	projectile:Fire(0, nil)
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
	local turret = ship.Turrets:Get(turretUID)
	local turretBaseID = ship.InitialParams.Config.Sections[section].Attachments[turretUID].BaseID
	local turretAsset = self.Services.AssetService:GetAsset(turretBaseID)
	local projectileClassName = "Projectile" .. turretAsset.Type
	local randomsNeeded = self.Modules.ProjectileAlgorithms[projectileClassName].Randoms
	local projectileClass = self.Classes[projectileClassName]
	local projectile = projectileClass.new(
		turret,
		GenerateUserRandoms(randUID, user, randomsNeeded, randoms),
		target
	)

	projectile:Fire(dt, user)
end


-- Assigns turret's target, auto replicates via Roblox
-- @param uid <string>
-- @param turret <Turret>
-- @param target <BasePart>
function TurretService:SetTurretTarget(uid, turret, target)
	local users = SolarService:GetSystemFromPhysicsGroupID(
		turret.Hardpoint.PrimaryPart.CollisionGroupId
	).Players:ToArray()

	turret:SetTarget(target)
	Network:FireClientList(users,
		Network:Pack(
			Network.NetProtocol.Forget,
			Network.NetRequestType.TurretTarget,
			uid, turret.Hardpoint, target
		)
	)
end


-- Adds an entity to be managed by this service. Turrets will be controlled
-- @param entity <T extends Entity>
function TurretService:HandleEntity(entity)
	if (entity.Turrets == nil) then
		 warn("Entity has no turrets!", entity.Base:GetFullName())
		 return
	end

	ManagedEntities:Add(entity.Base, entity)
end


function TurretService:EngineInit()
	Network = self.Services.Network
	SyncRandomService = self.Services.SyncRandomService
	ShipService = self.Services.ShipService
	SolarService = self.Services.SolarService
	EntityService = self.Services.EntityService

	ManagedEntities = self.Classes.IndexedMap.new()
	TurretsWithTargets = self.Classes.IndexedMap.new()
	ListLock = self.Classes.Mutex.new()
	ServerRandom = Random.new()
end


function TurretService:EngineStart()
	Network:HandleRequestType(
		Network.NetRequestType.TurretShoot,
		function(user, dt, section, turretUID, target, randUID, randoms)
			self:FireUserTurret(user, dt, section, turretUID, target, randUID, randoms)
		end
	)

	Network:HandleRequestType(
		Network.NetRequestType.TurretTarget,
		function(user, dt, hardpoint, turretUID, target)
			local base = hardpoint.Parent.Parent.Parent
			local entity = EntityService:GetEntity(base) 
			self:SetTurretTarget(turretUID, entity.Turrets:Get(turretUID), target)
		end
	)

	-- TODO: Only shoot turrets under "TurretsWithTargets"
	-- Responsible for handling turrets that have targets
	TurretJobID = self.Services.MetronomeService:BindToFrequency(15, TurretShooter)

	-- Responsible for acquiring targets for non-player entities' turrets
	EntityJobID = self.Services.MetronomeService:BindToFrequency(5, TurretScanner)
end


return TurretService