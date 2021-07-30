local Projectile = require(script.Parent.Projectile)
local ProjectileRepeater = {}
ProjectileRepeater.__index = ProjectileRepeater
setmetatable(ProjectileRepeater, Projectile)


-- Beam constructor
function ProjectileRepeater.new(turret, randoms)
	local self = setmetatable(
		Projectile.new(
			turret,
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
	local spreads = Generate(self.Turret, self.Randoms)
	local duration = self.Turret.Asset.Duration
	local elapsed = 0
	local hitDetectionJobID

	if (excludedUser) then
		local beamFx = EffectService:MakeBut(
			excludedUser,
			"FD" .. self.Turret.Asset.EffectID,
			0,
			self.Turret.Hardpoint,
			self.Turret.UID,
			self.Target,
			self.Turret.Asset.ProjectileSpeed,
			self.Turret.Asset.ProjectileLength,
			spreads,
			self.Turret.Asset.BeamColor,
			self.Turret.Asset.ProjectileRange
		)
	else
		local beamFx = EffectService:Make(
			"FD" .. self.Turret.Asset.EffectID,
			0,
			self.Turret.Hardpoint,
			self.Turret.UID,
			self.Target,
			self.Turret.Asset.ProjectileSpeed,
			self.Turret.Asset.ProjectileLength,
			spreads,
			self.Turret.Asset.BeamColor,
			self.Turret.Asset.ProjectileRange
		)
   end
end


return ProjectileRepeater
