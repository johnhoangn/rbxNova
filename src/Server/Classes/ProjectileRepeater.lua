local Projectile = require(script.Parent.Projectile)
local ProjectileRepeater = {}
ProjectileRepeater.__index = ProjectileRepeater
setmetatable(ProjectileRepeater, Projectile)


-- Beam constructor
function ProjectileRepeater.new(turret, randoms, forceTarget)
	local self = setmetatable(
		Projectile.new(
			turret,
			randoms,
			forceTarget
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
	local spreads = Generate(self.Turret, self.Randoms, self.Target)
	local maxDistance = self.Turret.Asset.ProjectileRange
	local numPulses = #spreads
	local hitDetectionJobIDs = table.create(#spreads, "")
	local rayParams = RaycastParams.new()

	rayParams.CollisionGroup = game:GetService("PhysicsService")
		:GetCollisionGroupName(self.Turret.Hardpoint.PrimaryPart.CollisionGroupId)
	rayParams.FilterDescendantsInstances = { self.Turret.Hardpoint.Parent.Parent.Parent, workspace.GalacticBaseplate }
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist

	for i = 1, numPulses do
		local origin = self.Turret.PitchOrigin.Position
		local targetPos = self.Target.Position + spreads[i]
		local targetDirection = (targetPos - origin).Unit
		local travelled = 0

		hitDetectionJobIDs[i] = self.Services.MetronomeService:BindToFrequency(30, function(dt)
			if (travelled >= maxDistance) then
				self.Services.MetronomeService:Unbind(hitDetectionJobIDs[i])
			else
				local forward = targetDirection * dt * self.Turret.Asset.ProjectileSpeed
				local rayResults = self.Modules.RayUtil:CastSimple(
					origin,
					forward,
					rayParams
				)

				-- TODO: DamageService:Damage(targetBase, sourceBase, section, value)
				-- TODO: EntityService:GetEntityFromDescendant()
				if (rayResults ~= nil) then
					local hit = rayResults.Instance
					local entityBase = hit.Parent.Parent
					local shield = entityBase:GetAttribute("Shield" .. hit.Name)
					local armor = entityBase:GetAttribute("Armor" .. hit.Name)
					local hull = entityBase:GetAttribute("Hull" .. hit.Name)
					local damage = self.Turret.Asset.Damage/numPulses

					if (shield ~= nil) then
						self.Services.MetronomeService:Unbind(hitDetectionJobIDs[i])

						if (shield > 0) then
							entityBase:SetAttribute("Shield" .. hit.Name, shield - damage)
						elseif (armor > 0) then
							entityBase:SetAttribute("Armor" .. hit.Name, armor - damage)
						elseif (hull > 0) then
							entityBase:SetAttribute("Hull" .. hit.Name, hull - damage)
							-- TODO: Damage core if this hitbox got blown up
						else
							print("Blew up", hit)
						end
					end
				end

				origin += forward
				travelled += forward.Magnitude
			end
		end)
	end

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
