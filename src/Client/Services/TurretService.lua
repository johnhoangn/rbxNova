-- TurretService client, controls turret behavior, and handles
--	the projectile visual effects that the managed turrets create
--
-- Dynamese (Enduo)
-- 07.24.2021



local TurretService = {Priority = 75}

local AssetService, ShipService, MetronomeService,
	Network, SyncRandomService, EffectService, SolarService

local ProjectileEffects
local TurretMode

local TURRET_AI_FREQUENCY_1 = 5 --Hz
local TURRET_AI_FREQUENCY_2 = 15 --Hz

local UserShip
local TurretScanJobID, TurretShootJobID
local TurretRandUID


-- Goes through the ship's turrets and tries to find targets (if on priority mode)
-- @param dt <float>
local function ScanTurrets(dt)
	if (SolarService.InSystem and UserShip ~= nil and UserShip.Turrets ~= nil) then
		local systemShips = SolarService:GetEntities("EntityShip")
		local currentPosition = UserShip:RealPosition()

		-- Filter only hostile ships, ~O(n), n = #ships in the system
		-- TODO: Consider what to do with mining lasers
		-- TODO: Actually filter
		systemShips = TurretService.Modules.TableUtil.Filter(systemShips, function(entity)
			print(entity)
			return entity ~= UserShip
		end)

		if (#systemShips == 0) then
			print("No qualifying ships")
			return
		end

		-- Sort by ascending distance, ~O(mlogm) ship to ship, m = #filtered, worst case m == n
		table.sort(systemShips, function(a, b)
			return (a:RealPosition() - currentPosition).Magnitude
				> (b:RealPosition() - currentPosition).Magnitude
		end)

		-- O(h), h = #turrets
		for uid, turret in UserShip.Turrets:KeyIterator() do print(uid, turret:GetTarget() ~= nil)
			if (turret:GetTarget() == nil) then
				if (turret.Mode == TurretMode.Priority) then
					local turretPosition = turret.Model.PitchOrigin.Position
					local closest = systemShips[1]
					local cDist = (systemShips[1].Base.PrimaryPart.Position - turretPosition).Magnitude

					-- Turret has no target, and is in priority mode (auto)
					-- Search for a target
					-- TODO: Efficient target search algorithm please, brain
					-- TODO: Actually add priority setting, for now we grab ships

					-- Iterate through the ship to ship distance sorted array
					--	to find the closest ship to this turret.
					-- O(m)
					for _, ship in ipairs(systemShips) do
						local thisDist = (ship.Base.PrimaryPart.Position - turretPosition).Magnitude

						if (thisDist < cDist) then
							closest = ship
							cDist = thisDist
						end
					end

					turret:SetTarget(closest.Base.PrimaryPart)

				-- elseif (turret.Mode == TurretMode.Off) then
				-- elseif (turret.Mode == TurretMode.Target) then
				--	These modes don't need scanning; here for logic visualization
				end
			end
		end

		-- O(n + mlogm + h*m)
	end
end


-- Loops through the ship's currently attached turrets
--	and attempts to shoot them
-- @param dt <float>
local function ShootTurrets(dt)
	local now = tick()

	if (UserShip ~= nil and UserShip.Turrets ~= nil) then
		for uid, turret in UserShip.Turrets:KeyIterator() do
			if (turret:GetTarget() ~= nil) then
				if (turret:CanFire(now)) then
					-- Turret has a target, check if eligible to fire and shoot
					TurretService:Fire(turret, turret.Asset)
					turret._LastShot = now + turret.Asset.Duration

				elseif (turret.Mode == TurretMode.Priority) then
					-- Last selected target out of range, nil so scanner can pick up a new one
					turret:SetTarget(nil)

				-- elseif (turret.Mode == TurretMode.Target) then
				-- When explicitly targeting something, do not set to nil even if out of range
				--	this is here just for visualizing the logic
				end
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
	local randoms = {}
	local projectileType = turretAsset.Type
	local projectileAlgo = self.Modules.ProjectileAlgorithms["Projectile" .. projectileType]

	for i = 1, projectileAlgo.Randoms do
		randoms[i] = SyncRandomService:NextNumber(TurretRandUID)
	end

	EffectService:Make(
		"FD" .. turretAsset.EffectID,
		nil, 0,
		ProjectileEffects[projectileType](projectileAlgo, turret, randoms)
	)

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


function TurretService:Enable(state)
	if (state) then
		UserShip = ShipService:GetShip()
		TurretScanJobID = MetronomeService:BindToFrequency(TURRET_AI_FREQUENCY_1, ScanTurrets)
		TurretShootJobID = MetronomeService:BindToFrequency(TURRET_AI_FREQUENCY_2, ShootTurrets)
	else
		UserShip = nil
		MetronomeService:Unbind(TurretScanJobID)
		MetronomeService:Unbind(TurretShootJobID)
		TurretScanJobID = nil
		TurretShootJobID = nil
	end
end


function TurretService:EngineInit()
	AssetService = self.Services.AssetService
	ShipService = self.Services.ShipService
	MetronomeService = self.Services.MetronomeService
	Network = self.Services.Network
	SyncRandomService = self.Services.SyncRandomService
	EffectService = self.Services.EffectService
	SolarService = self.Services.SolarService

	ProjectileEffects = self.Modules.ProjectileEffects
	TurretMode = self.Enums.TurretMode
end


function TurretService:EngineStart()
	TurretRandUID = SyncRandomService:NewSyncRandom()
	ShipService.EnableStateChanged:Connect(function(state)
		self:Enable(state)
	end)

	if (UserShip == nil and ShipService:GetShip() ~= nil) then
		self:Enable(true)
	end
end


return TurretService