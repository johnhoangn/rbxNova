local Projectile = require(script.Parent.Projectile)
local ProjectileRepeater = {}
ProjectileRepeater.__index = ProjectileRepeater
setmetatable(ProjectileRepeater, Projectile)


-- Beam constructor
function ProjectileRepeater.new(turret, target, randoms)
	local self = setmetatable(
		Projectile.new(
			turret,
			target,
			randoms
		),
		ProjectileRepeater
	)

	return self
end


-- Fires the turret
-- @param dt <float> time to displace projectile by
-- @param excludedUser <Player> == nil, user who shot the turret, nil if NPC controlled
function ProjectileRepeater:Fire(dt, excludedUser)
	local EffectService = self.Services.EffectService
	local Generate = self.Modules.ProjectileAlgorithms.ProjectileRepeater.Generate
	local spreads = Generate(self.Turret, self.Target, self.Randoms)
	local duration = self.Turret.Asset.Duration
	local elapsed = 0
	local hitDetectionJobID
	--(dt, hardpoint, turretUID, target, speed, length, spreads, clr, dist)
	-- if (excludedUser) then
	-- 	local beamFx = EffectService:MakeBut(
	-- 		excludedUser,
	-- 		"FD" .. self.Turret.Asset.EffectID,
	-- 		0,
	-- 		self.Turret.Hardpoint,
	-- 		self.Turret.UID,
	-- 		self.Target,
	-- 		self.Turret.Asset.ProjectileSpeed,
	-- 		self.Turret.Asset.ProjectileLength,
	-- 		self.Turret.Asset.BeamColor,
	-- 		self.Turret.Asset.ProjectileRange,
	-- 		self.Turret.Asset.Duration
	-- 	)
	-- else
		local beamFx = EffectService:Make(
			"FD" .. self.Turret.Asset.EffectID,
			0,
			self.Turret.Hardpoint,
			self.Turret.UID,
			self.Target,
			self.Turret.Asset.ProjectileSpeed,
			self.Turret.Asset.ProjectileLength,
			self.Randoms,
			self.Turret.Asset.BeamColor,
			self.Turret.Asset.ProjectileRange
		)
   --end
end


return ProjectileRepeater
