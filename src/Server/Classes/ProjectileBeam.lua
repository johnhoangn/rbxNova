local Projectile = require(script.Parent.Projectile)
local ProjectileBeam = {}
ProjectileBeam.__index = ProjectileBeam
setmetatable(ProjectileBeam, Projectile)


-- Beam constructor
function ProjectileBeam.new(turret, randoms)
	local self = setmetatable(
        Projectile.new(
            turret,
            randoms
        ),
        ProjectileBeam
    )

	return self
end


-- Fires the turret
-- @param dt <float> time to displace projectile by
-- @param excludedUser <Player> == nil, user who shot the turret, nil if NPC controlled
function ProjectileBeam:Fire(dt, excludedUser)
    local EffectService = self.Services.EffectService
    local Generate = self.Modules.ProjectileAlgorithms.ProjectileBeam.Generate
    local offset1, offset2 = Generate(self.Turret, self.Randoms)
	local duration = self.Turret.Asset.Duration
	local elapsed = 0
	local hitDetectionJobID

	local rayParams = RaycastParams.new()

	-- Why's this gotta be so long Roblox
	rayParams.CollisionGroup = game:GetService("PhysicsService")
		:GetCollisionGroupName(self.Turret.Hardpoint.PrimaryPart.CollisionGroupId)
	rayParams.FilterDescendantsInstances = { self.Turret.Hardpoint.Parent.Parent.Parent, workspace.GalacticBaseplate }
	rayParams.FilterType = Enum.RaycastFilterType.Blacklist

	hitDetectionJobID = self.Services.MetronomeService:BindToFrequency(4, function(dt)
		elapsed += dt
		if (elapsed >= duration) then
			self.Services.MetronomeService:Unbind(hitDetectionJobID)
		else
			local hardPointPos = self.Turret.PitchOrigin.Position
			local sweepProgress = (offset2 - offset1) * (elapsed/duration)
			local targetPos = self.Target.Position + offset1 + sweepProgress
			local targetVector = targetPos - hardPointPos
			local rayResults = self.Modules.RayUtil:CastSimple(hardPointPos, targetVector + targetVector.Unit * 5, rayParams)

			-- TODO: DamageService:Damage(targetBase, sourceBase, section, value)
			-- TODO: EntityService:GetEntityFromDescendant()
			if (rayResults ~= nil) then
				local hit = rayResults.Instance
				local entityBase = hit.Parent.Parent
				local shield = entityBase:GetAttribute("Shield" .. hit.Name)
				local armor = entityBase:GetAttribute("Armor" .. hit.Name)
				local hull = entityBase:GetAttribute("Hull" .. hit.Name)
				local damage = (elapsed/duration) * self.Turret.Asset.Damage

				if (shield ~= nil) then
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
		end
	end)

	self:GetMaid():GiveTask(function()
		if (duration > 0) then
			self.Services.MetronomeService:Unbind(hitDetectionJobID)
		end
	end)

    if (excludedUser) then
        local beamFx = EffectService:MakeBut(
            excludedUser,
            "FD" .. self.Turret.Asset.EffectID,
            0,
            self.Turret.Hardpoint,
			self.Turret.UID,
            self.Target,
            offset1,
            offset2,
            self.Turret.Asset.BeamColor,
			self.Turret.Asset.ProjectileRange,
			self.Turret.Asset.Duration
        )
    else
        local beamFx = EffectService:Make(
            "FD" .. self.Turret.Asset.EffectID,
            0,
            self.Turret.Hardpoint,
			self.Turret.UID,
            self.Target,
            offset1,
            offset2,
            self.Turret.Asset.BeamColor,
			self.Turret.Asset.ProjectileRange,
			self.Turret.Asset.Duration
        )
   end
end


return ProjectileBeam
