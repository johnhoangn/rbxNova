-- EntityPlanet class, represents a planet
--
-- Dynamese (Enduo)
-- 07.19.2021



local EntityCelestial = require(script.Parent.EntityCelestial)
local EntityPlanet = {}
EntityPlanet.__index = EntityPlanet
setmetatable(EntityPlanet, EntityCelestial)


-- Normal constructor
-- @param base <Model>
-- @param initialParams <table> == nil, convenience for EntityPlanet subclasses
-- @returns <EntityPlanet>
function EntityPlanet.new(base, initialParams)
	local self = EntityCelestial.new(base, initialParams)

	return setmetatable(self, EntityPlanet)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityPlanet end


return EntityPlanet
