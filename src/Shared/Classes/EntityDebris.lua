-- EntityDebris class, represents junk floating amongst the cosmos
--
-- Dynamese (Enduo)
-- 08.11.2021



local EntityCelestial = require(script.Parent.EntityCelestial)
local EntityDebris = {}
EntityDebris.__index = EntityDebris
setmetatable(EntityDebris, EntityCelestial)


-- Normal constructor
-- @param base <Model>
-- @param initialParams <table> == nil, convenience for EntityDebris subclasses
-- @returns <EntityDebris>
function EntityDebris.new(base, initialParams)
	local self = EntityCelestial.new(base, initialParams)

	return setmetatable(self, EntityDebris)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityDebris end


return EntityDebris
