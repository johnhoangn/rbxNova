-- Entity class, represents an existence to be rendered.
--
-- Dynamese (Enduo)
-- 07.19.2021



local DeepObject = require(script.Parent.DeepObject)
local Entity = {}
Entity.__index = Entity
setmetatable(Entity, DeepObject)


-- Normal constructor
-- @param base <Model>
-- @param initialParams <table> == nil, convenience for entity subclasses
-- @returns <Entity>
function Entity.new(base, initialParams)
    assert(base:IsA("Model"), "Base must be a model " .. base:GetFullName())
    assert(base.PrimaryPart ~= nil, "Missing primary part " .. base:GetFullName())

	local self = DeepObject.new({
        _InitialParams = initialParams;
        Base = base;
    })

    if (initialParams ~= nil) then
        for k, v in pairs(initialParams) do
            self[k] = v
        end
    end

	return setmetatable(self, Entity)
end


-- Retrieves the position of this entity when centered at REAL ORIGIN
-- @returns <Vector3>
function Entity:RealPosition()
    return Vector2.new(
        self.Base.PrimaryPart.Position.X,
        self.Base.PrimaryPart.Position.Z
    )
end


-- Retrieves the position of this entity relative to the virtual galaxy
-- @returns <Vector3>
function Entity:UniversalPosition()
    assert(self._System ~= nil, "This entity is not part of a solar system")
    return Vector3.new()
end


-- Destroys this instance and its physical model along with it
local superDestroy = Entity.Destroy
function Entity:Destroy()
    self.Base:Destroy()
    self.Base = nil
    superDestroy()
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return Entity end


-- Client constructor variant, adds on data that only the client needs
local new = Entity.new
function Entity.new(...)
    local newEntity = new(...)
    newEntity._LastOpacity = Entity.Enums.Opacity.Opaque;
    newEntity._Opacity = Entity.Enums.Opacity.Opaque;
    return newEntity
end


-- Renders this entity
function Entity:Draw()
    error("Entity itself cannot be rendered, maybe you intended to render a subclass?")
end


-- Hides this entity
function Entity:Hide()
    error("Entity itself cannot be hidden, maybe you intended to render a subclass?")
end


-- Sets how transparent/opaque to draw this entity
function Entity:SetOpacity()
    error("Entity itself cannot have its opacity changed, maybe you intended to edit a subclass?")
end


return Entity
