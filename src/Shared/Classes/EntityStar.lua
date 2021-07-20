-- EntityStar class, represents a system's star
--
-- Dynamese (Enduo)
-- 07.19.2021



local EntityCelestial = require(script.Parent.EntityCelestial)
local EntityStar = {}
EntityStar.__index = EntityStar
setmetatable(EntityStar, EntityCelestial)


-- Normal constructor
-- @param base <Model>
-- @param initialParams <table> == nil, convenience for EntityStar subclasses
-- @returns <EntityStar>
function EntityStar.new(base, initialParams)
	local self = EntityCelestial.new(base, initialParams)

	return setmetatable(self, EntityStar)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityStar end


return EntityStar
