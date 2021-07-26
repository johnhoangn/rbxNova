local Algorithms = {}

local TAU = math.pi * 2
local RAD = math.rad


Algorithms.ProjectileBeam = { Randoms = 4; }
function Algorithms.ProjectileBeam.Generate(turret, target, randoms)
	-- Straight line towards the target, generate new basis vectors for offsets
	local targetPos = target.Position
	local targetVector = targetPos - turret.Model.PitchOrigin.Position

	-- Using the new basis, generate two points the beam will sweep across
	-- TODO: reduce angles based on skills
	local rotation1 = randoms[1] * TAU
	local rotation2 = randoms[2] * TAU
	local pitch1 = (randoms[3] - 0.5) * 2 * RAD(turret.Asset.Spread)
	local pitch2 = (randoms[4] - 0.5) * 2 * RAD(turret.Asset.Spread)
	local orientation1 = CFrame.fromAxisAngle(targetVector, rotation1)
	local orientation2 = CFrame.fromAxisAngle(targetVector, rotation2)
	local offset1 = (orientation1 * CFrame.fromAxisAngle(orientation1.UpVector, pitch1)).LookVector
	local offset2 = (orientation2 * CFrame.fromAxisAngle(orientation2.UpVector, pitch2)).LookVector

	return offset1, offset2
end


Algorithms.ProjectileRepeater = { Randoms = 4; }
function Algorithms.ProjectileRepeater.Generate(turret, target, randoms)
	-- Straight line towards the target, generate new basis vectors for offsets
	local targetPos = target.Position
	local targetVector = targetPos - turret.Model.PitchOrigin.Position

	-- Using the new basis, generate two points the beam will sweep across
	-- TODO: reduce angles based on skills
	local rotation1 = randoms[1] * TAU
	local rotation2 = randoms[2] * TAU
	local pitch1 = (randoms[3] - 0.5) * 2 * RAD(turret.Asset.Spread)
	local pitch2 = (randoms[4] - 0.5) * 2 * RAD(turret.Asset.Spread)
	local orientation1 = CFrame.fromAxisAngle(targetVector, rotation1)
	local orientation2 = CFrame.fromAxisAngle(targetVector, rotation2)
	local offset1 = (orientation1 * CFrame.fromAxisAngle(orientation1.UpVector, pitch1)).LookVector
	local offset2 = (orientation2 * CFrame.fromAxisAngle(orientation2.UpVector, pitch2)).LookVector

	return offset1, offset2
end


return Algorithms