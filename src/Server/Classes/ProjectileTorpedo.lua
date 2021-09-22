local ProjectileRepeater = require(script.Parent.ProjectileRepeater)
local ProjectileTorpedo = {}
ProjectileTorpedo.__index = ProjectileTorpedo
setmetatable(ProjectileTorpedo, ProjectileRepeater)


-- Torpedo constructor
function ProjectileTorpedo.new(turret, randoms, forceTarget)
	local self = setmetatable(
		ProjectileRepeater.new(
			turret,
			randoms,
			forceTarget
		),
		ProjectileTorpedo
	)

	return self
end


return ProjectileTorpedo
