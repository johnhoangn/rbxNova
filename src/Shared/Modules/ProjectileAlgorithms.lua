local Algorithms = {}

local TAU = math.pi * 2
local RAD = math.rad
local ZERO_VECTOR = Vector3.new()


Algorithms.ProjectileBeam = { NumRandoms = 4; }
function Algorithms.ProjectileBeam.Generate(turret, randoms, target)
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


-- More randoms than we need, but in preparation for skill-based changes
-- MUST NEED AT LEAST 2x MAX PULSES IN RANDOMS (RADIAL, DISTANCE)
-- IT IS OKAY TO GENERATE MORE THAN NECESSARY
--	AT SOME POINT, SET THIS TO 2x THE PULSE COUNT POSSIBLE IN THE GAME
Algorithms.ProjectileRepeater = { NumRandoms = 16; }
function Algorithms.ProjectileRepeater.Generate(turret, randoms, target)
	-- Straight line towards the target, generate new basis vectors for offsets
	local targetPos = target.Position
	local targetVector = targetPos - turret.Model.PitchOrigin.Position
	local spreads = table.create(turret.Asset.ProjectileCount, ZERO_VECTOR)

	-- Using the new basis, generate random offsets to shoot the pulses at
	-- TODO: reduce angles based on skills
	-- TODO: add more pulses based on skills
	for i = 1, #spreads do
		local rotation = randoms[i] * TAU
		local pitch = (randoms[i + 1] - 0.5) * 2 * RAD(turret.Asset.Spread)
		local orientation = CFrame.fromAxisAngle(targetVector, rotation)

		spreads[i] = (orientation * CFrame.fromAxisAngle(orientation.UpVector, pitch)).LookVector
	end

	return spreads
end


-- Functionally the same behavior as repeater so we just extend that
Algorithms.ProjectileTorpedo = { NumRandoms = 2; }
function Algorithms.ProjectileTorpedo.Generate(turret, randoms, target)
	return Algorithms.ProjectileRepeater.Generate(turret, randoms, target)
end


return Algorithms