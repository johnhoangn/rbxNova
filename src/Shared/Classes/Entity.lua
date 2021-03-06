-- Entity class, represents an existence to be rendered.
--
-- Dynamese (Enduo)
-- 07.19.2021



local DeepObject = require(script.Parent.DeepObject)
local Entity = {}
Entity.__index = Entity
setmetatable(Entity, DeepObject)

local HttpService

-- Normal constructor
-- @param base <Model>
-- @param initialParams <table> == nil, convenience for entity subclasses
-- @returns <Entity>
function Entity.new(base, initialParams)
	HttpService = HttpService or Entity.RBXServices.HttpService

	assert(base:IsA("Model"), "Base must be a model " .. base:GetFullName())
	assert(base.PrimaryPart ~= nil, "Missing primary part " .. base:GetFullName())

	local self = DeepObject.new({
		InitialParams = initialParams;
		Base = base;
		SolarSystemID = base.PrimaryPart.CollisionGroupId;
		UID = initialParams.UID or HttpService:GenerateGUID();
	})

	-- Server sided system id handling
	if (game:GetService("Players").LocalPlayer == nil) then
		self:GetMaid():GiveTask(
			base.PrimaryPart:GetPropertyChangedSignal("CollisionGroupId"):Connect(function()
				self.SolarSystemID = base.PrimaryPart.CollisionGroupId
				for _, descendant in ipairs(base:GetDescendants()) do
					if (descendant:IsA("BasePart")) then
						descendant.CollisionGroupId = self.SolarSystemID
					end
				end
			end)
		)
		self:GetMaid():GiveTask(
			base.DescendantAdded:Connect(function(descendant)
				if (descendant:IsA("BasePart")) then
					descendant.CollisionGroupId = self.SolarSystemID
				end
			end)
		)
	end

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
	local self = new(...)

	self._LastOpacity = Entity.Enums.Opacity.Opaque;
	self._Opacity = Entity.Enums.Opacity.Opaque;

	self:SetCollisions()
	self:GetMaid():GiveTask(
		-- The server's constructor will be setting the id for all parts
		--	so the client only needs to re-update the hitbox parts
		self.Base.PrimaryPart:GetPropertyChangedSignal("CollisionGroupId"):Connect(function()
			wait() -- Allow the server to finish replicating hitbox collisiongroups
			self:SetCollisions() -- Then set them right back to 0
		end)
	)

	return self
end


-- Hitboxes will get in the way of effect rendering; force their collision groups to default (none)
-- This is a client-sided change so the server will still hit
function Entity:SetCollisions()
	local hitboxes = self.Base:FindFirstChild("Hitboxes")

	if (hitboxes ~= nil) then
		for _, d in ipairs(hitboxes:GetDescendants()) do
			if (d:IsA("BasePart")) then
				d.CollisionGroupId = 0
				d.Transparency = 1 -- Also get this while we're at it
			end
		end
	end
end


-- Marks this entity to be exempt or not from purges
-- @param bool, true for exempt
function Entity:MarkPurgeExempt(bool)
	self.PurgeExempt = bool or nil
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
