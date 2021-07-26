-- TurretService client, controls turret behavior, and handles
--	the projectile visual effects that the managed turrets create
--
-- Dynamese (Enduo)
-- 07.24.2021



local TurretService = {Priority = 75}

local AssetService, ShipService, MetronomeService,
	Network, SyncRandomService, EffectService, SolarService
local TurretMode

local TURRET_AI_FREQUENCY = 5 --Hz

local UserShip
local TurretJobID
local TurretRandUID


-- Loops through the ship's currently attached turrets
--	and attempts to shoot them
local function StepTurrets(dt)
	local now = tick()

	if (UserShip ~= nil and UserShip.Turrets ~= nil) then
		for uid, turret in UserShip.Turrets:KeyIterator() do
			if (turret:GetTarget() ~= nil) then
				if (turret:CanFire(now)) then
					-- Turret has a target, check if eligible to fire and shoot
					TurretService:Fire(turret, turret.Asset)
					turret._LastShot = now + turret.Asset.Duration
				end

			elseif (turret.Mode == TurretMode.Priority) then
				-- Turret has no target, and is in priority mode
				-- Search for a target
				-- TODO: Efficient target search algorithm please, brain
			end
		end
	end
end

-- Shoots this turret using its stored target info
-- For beam, constant-type weapons, cut off the shot early if the
--	target moves out of range or angle
-- @param turret <Turret>
-- @param turretAsset <table>
function TurretService:Fire(turret, turretAsset)
	--local turretAsset = AssetService:GetAsset("070")
	local randoms = {}

	for i = 1, 4 do
		randoms[i] = SyncRandomService:NextNumber(TurretRandUID)
	end

	local Generate = self.Modules.ProjectileAlgorithms.ProjectileBeam.Generate
	local offset1, offset2 = Generate(turret, turret:GetTarget(), randoms)

	-- TODO: This is hardcoded for beam turrets
	--	the parameter list will not be the same for every turret
	-- EffectService:Make(
	-- 	"FD" .. turretAsset.EffectID,
	-- 	nil,
	-- 	0,
	-- 	turret.Hardpoint,
	-- 	turret.UID,
	-- 	turret:GetTarget(),
	-- 	offset1,
	-- 	offset2,
	-- 	Color3.new(0,1,1),
	-- 	turret.Asset.ProjectileRange,
	-- 	1
	-- )

	Network:FireServer(
		Network:Pack(
			Network.NetProtocol.Forget,
			Network.NetRequestType.TurretShoot,
			"Core", turret.Model.Name, turret:GetTarget(), TurretRandUID, randoms
		)
	)
end


-- Sets this turret's mode
-- If the new mode is TurretMode.Off, point the turret forward
-- @param turret <Turret>
-- @param mode <integer>
function TurretService:SetTurretMode(turret, mode)

end


-- Sets this turret's priority (for priority mode)
-- @param turret <Turret>
-- @param priority <integer>
function TurretService:SetTurretPriority(turret, priority)
	
end


-- Sets this turret's target (for target mode)
-- @param turret <Turret>
-- @param target <BasePart>
function TurretService:SetTurretTarget(turret, target)
	turret:SetTarget(target)
	Network:FireServer(
		Network:Pack(
			Network.NetProtocol.Forget,
			Network.NetRequestType.TurretTarget,
			turret.Hardpoint, turret.Model.Name, target
		)
	)
end


function TurretService:EngineInit()
	AssetService = self.Services.AssetService
	ShipService = self.Services.ShipService
	MetronomeService = self.Services.MetronomeService
	Network = self.Services.Network
	SyncRandomService = self.Services.SyncRandomService
	EffectService = self.Services.EffectService
	SolarService = self.Services.SolarService

	TurretMode = self.Enums.TurretMode
end


function TurretService:EngineStart()
	TurretRandUID = SyncRandomService:NewSyncRandom()
	ShipService.EnableStateChanged:Connect(function(state)
		if (state) then
			UserShip = ShipService:GetShip()
			TurretJobID = MetronomeService:BindToFrequency(TURRET_AI_FREQUENCY, StepTurrets)
		else
			UserShip = nil
			MetronomeService:Unbind(TurretJobID)
			TurretJobID = nil
		end
	end)
end


return TurretService