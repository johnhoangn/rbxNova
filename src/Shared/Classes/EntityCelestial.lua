-- EntityCelestial class, represents a celestial body in the system
--
-- Dynamese (Enduo)
-- 07.19.2021



local AssetService

local Entity = require(script.Parent.Entity)
local EntityCelestial = {}
EntityCelestial.__index = EntityCelestial
setmetatable(EntityCelestial, Entity)


-- Normal constructor
-- @param base <Model>
-- @param initialParams <table> == nil, convenience for EntityCelestial subclasses
-- @returns <EntityCelestial>
function EntityCelestial.new(base, initialParams)
    AssetService = AssetService or EntityCelestial.Services.AssetService

	local self = Entity.new(base, initialParams)

    self._Asset = AssetService:GetAsset(self._BaseID)

	return setmetatable(self, EntityCelestial)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityCelestial end


-- Renders this EntityCelestial
function EntityCelestial:Draw()
    if (self._Model == nil) then
        local model = self._Asset.Model:Clone()
        local parts = {}

        for _, part in ipairs(model:GetDescendants()) do
            if (part:IsA("BasePart") and part.Transparency < 1) then
                parts[part] = part.Transparency
            end
        end

        model:SetPrimaryPartCFrame(self._Base.PrimaryPart.CFrame)
        model.Parent = self._Base
        self.Modules.WeldUtil:WeldParts(model.PrimaryPart, self._Base.PrimaryPart)
        self._Model = model
        self._Parts = parts
    end
end


-- Sets how transparent/opaque to draw this EntityCelestial
function EntityCelestial:SetOpacity()
    error("Celestial bodies cannot change opacity")
end


-- Removes the model
function EntityCelestial:Hide()
    self._Model:Destroy()
    self._Model = nil
    self._Parts = nil
end


-- Destroys this instance and its physical model along with it
local superDestroy = Entity.Destroy
function EntityCelestial:Destroy()
    self:Hide()
    superDestroy()
end


return EntityCelestial
