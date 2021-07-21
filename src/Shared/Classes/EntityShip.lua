local AssetService

local BodyVelocity2 = require(script.Parent.BodyVelocity2)
local ThrottleController = require(script.Parent.ThrottleController)
local Entity = require(script.Parent.Entity)
local EntityShip = {}
EntityShip.__index = EntityShip
setmetatable(EntityShip, Entity)


function EntityShip.new(base, initialParams)
    AssetService = AssetService or EntityShip.Services.AssetService

	local self = Entity.new(base, initialParams)
    local asset = AssetService:GetAsset(initialParams._BaseID)

    self._Asset = asset
    self._Thruster = BodyVelocity2.fromVectorForce(base.PrimaryPart.Thruster)
    self._Steer = base.PrimaryPart.Steer

    --self.Throttle = ThrottleController.new(acceleration, deceleration, minSpeed, maxSpeed)

	return setmetatable(self, EntityShip)
end


-- Forcefully places the ship
-- TODO: Implement protections against clients teleporting
-- @param cf <CFrame>
function EntityShip:PlaceAt(cf)
    self.Base:SetPrimaryPartCFrame(cf)
end


-- Steps bodymovers
-- @param dt <float>
function EntityShip:UpdatePhysics(dt)
    --self._Thruster.Velocity = Vector3.new(0, 0, -1)
    self._Thruster:Step(dt)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityShip end


-- Renders this EntityShip
function EntityShip:Draw()
    if (self._Model == nil) then
        local model = self._Asset.Model:Clone()
        local parts = {}

        for _, part in ipairs(model:GetDescendants()) do
            if (part:IsA("BasePart") and part.Transparency < 1) then
                parts[part] = part.Transparency
            end
        end

        model:SetPrimaryPartCFrame(self.Base.PrimaryPart.CFrame)
        model.Parent = self.Base
        self.Modules.WeldUtil:WeldParts(model.PrimaryPart, self.Base.PrimaryPart)
        self._Model = model
        self._Parts = parts
    else
        -- Animate EntityShip components
    end
end


-- Sets how transparent/opaque to draw this EntityShip
function EntityShip:SetOpacity()

end


-- Removes the model
function EntityShip:Hide()
    self._Model:Destroy()
    self._Model = nil
    self._Parts = nil
end


-- Destroys this instance and its physical model along with it
local superDestroy = Entity.Destroy
function EntityShip:Destroy()
    self:Hide()
    superDestroy()
end


return EntityShip
