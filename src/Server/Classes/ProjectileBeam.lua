local Projectile = require(script.Parent.Projectile)
local ProjectileBeam = {}
ProjectileBeam.__index = ProjectileBeam
setmetatable(ProjectileBeam, Projectile)

ProjectileBeam.RandomsNeeded = 4

local TAU = math.pi * 2
local RAD = math.rad


-- Beam constructor
function ProjectileBeam.new(turretAsset, turretModel, target, randoms)
	local self = setmetatable(
        Projectile.new(
            turretAsset,
            turretModel,
            target,
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

    -- Straight line towards the target, generate new basis vectors for offsets
    local targetPos = self.Target.Position
    local targetVector = targetPos - self.TurretModel.PitchOrigin.Position

    -- Using the new basis, generate two points the beam will sweep across
    -- TODO: reduce angles based on skills
    local rotation1 = self.Randoms[1] * TAU
    local rotation2 = self.Randoms[2] * TAU
    local pitch1 = (self.Randoms[3] - 0.5) * 2 * RAD(self.TurretAsset.Spread)
    local pitch2 = (self.Randoms[4] - 0.5) * 2 * RAD(self.TurretAsset.Spread)
    local orientation1 = CFrame.fromAxisAngle(targetVector, rotation1)
    local orientation2 = CFrame.fromAxisAngle(targetVector, rotation2)
    local offset1 = (orientation1 * CFrame.fromAxisAngle(orientation1.UpVector, pitch1)).Position
    local offset2 = (orientation2 * CFrame.fromAxisAngle(orientation2.UpVector, pitch2)).Position
--[[
    if (excludedUser) then
        local beamFx = EffectService:MakeBut(
            excludedUser,
            "FD" .. self.TurretAsset.EffectID, nil,
            self.TurretModel,
            self.Target,
            offset1,
            offset2,
            nil, nil, 1
        )
    else--]]
        local beamFx = EffectService:Make(
            "FD" .. self.TurretAsset.EffectID,
            nil,
            self.TurretModel,
            self.Target,
            offset1,
            offset2,
            nil, nil, 1
        )
   -- end
end


return ProjectileBeam
