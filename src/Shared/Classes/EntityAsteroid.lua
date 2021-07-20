-- EntityAsteroid class, represents a rock floating in the system
--
-- Dynamese (Enduo)
-- 07.19.2021



local EntityCelestial = require(script.Parent.EntityCelestial)
local EntityAsteroid = {}
EntityAsteroid.__index = EntityAsteroid
setmetatable(EntityAsteroid, EntityCelestial)


-- Normal constructor
-- @param base <Model>
-- @param initialParams <table> == nil, convenience for EntityAsteroid subclasses
-- @returns <EntityAsteroid>
function EntityAsteroid.new(base, initialParams)
	local self = EntityCelestial.new(base, initialParams)

	return setmetatable(self, EntityAsteroid)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityAsteroid end


return EntityAsteroid
