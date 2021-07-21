local AssetService

-- RoPID.new(kP: number, kI: number, kD: number, min: number?, max: number?)
--      :Calculate(setPoint: number, processValue: number, deltaTime: number)
local PID = require(script.Parent.RoPID)
local Entity = require(script.Parent.Entity)
local EntityShip = {}
EntityShip.__index = EntityShip
setmetatable(EntityShip, Entity)

local ABS = math.abs
local SIGN = math.sign

local COAXIAL = Vector3.new(0, 0, -1)
local LATERAL = Vector3.new(1, 0, 0)
local YAW = Vector3.new(0, 1, 0)
local XZ_PLANE = Vector3.new(1, 0, 1)


function EntityShip.new(base, initialParams)
    AssetService = AssetService or EntityShip.Services.AssetService

	local self = Entity.new(base, initialParams)
    local asset = AssetService:GetAsset(initialParams._BaseID)

    self._Root = base.PrimaryPart
    self._Asset = asset

    -- Grab attributes for convenience
    self.ThrustCoaxial = base:GetAttribute("ThrustCoaxial")
    self.ThrustLateral = base:GetAttribute("ThrustLateral")
    self.ThrustYaw = base:GetAttribute("ThrustYaw")
    self.SpeedFwd = base:GetAttribute("SpeedFwd")
    self.SpeedRev = base:GetAttribute("SpeedRev")
    self.SpeedYaw = base:GetAttribute("SpeedYaw")

    self._Forces = {
        Coaxial = base.PrimaryPart.CoaxialForce;
        Lateral = base.PrimaryPart.LateralForce;
        Yaw = base.PrimaryPart.YawTorque;
    };

    self._PIDs = {
        Coaxial = PID.new(1, 0, 0, -self.ThrustCoaxial, self.ThrustCoaxial);
        Lateral = PID.new(1, 0, 0, -self.ThrustLateral, self.ThrustLateral);
        Yaw = PID.new(1, 0, 0, -self.SpeedYaw, self.SpeedYaw)
    }

    self._SteerDelta = 0

    self._Throttle = {
        Ratio = 0;
        Value = 0;
    }

    -- Auto track and auto cleanup attributes
    self:GetMaid():GiveTask(
        base.AttributeChanged:Connect(function(attr)
            local attrVal = base:GetAttribute(attr)
            local thrustSubStr, b = attr:find("Thrust")

            self[attr] = attrVal

            if (thrustSubStr ~= nil) then
                self._PIDs[attr:sub(b + 1)].Bounds.Min = -attrVal
                self._PIDs[attr:sub(b + 1)].Bounds.Max = attrVal

            elseif (attr:find("Speed") ~= nil) then
                self:SetThrottle(self.Throttle.Value)
            end
        end)
    )

	return setmetatable(self, EntityShip)
end


-- Forcefully places the ship
-- TODO: Implement protections against clients teleporting
-- @param cf <CFrame>
function EntityShip:PlaceAt(cf)
    self.Base:SetPrimaryPartCFrame(cf)
end


-- Puts the throttle handle in a position, from which the desired speed is calculated
--  from which the PID responsible for forward thrust will determine how hard to push
-- The lateral thrusters will always attempt to zero out any lateral slip
-- @param ratio <float> [0, 1]
function Entity:SetThrottle(ratio)
    self._Throttle.Ratio = ratio
    self._Throttle.Value = ratio > 0 and ratio * self.SpeedFwd or ratio * self.SpeedRev
end


-- Gives the ship a position to look at and we calculate how "in common" the angles are
--  from which the complement implies how "different" they are. This info is enough for
--  the PID responsible for calculating the torque necessary to turn towards the position
-- If given nil, the delta will be set to zero, and the PID will output zero torque
-- @param targetPosition <Vector3> == nil
function EntityShip:SetSteer(targetPosition)
    if (targetPosition ~= nil) then
        self._SteerDelta = (targetPosition - self._Root.Position).Unit:Dot(self._Root.CFrame.LookVector)
    else
        self._SteerDelta = 0
    end
end


-- Steps bodymovers
-- @param dt <float>
function EntityShip:UpdatePhysics(dt)
    local root = self._Root

    local currentVelocity = root.AssemblyLinearVelocity * XZ_PLANE
    local currentSpeed = currentVelocity.Magnitude
    local desiredDirection = root.CFrame.LookVector * XZ_PLANE
    local desiredSpeed = self._Throttle.Value

    -- Figure the speed components to divide the thrust into two: coaxial (main thruster) and lateral (side thrusters)
    -- Yielding two scalars, so the PIDs only compute their respective local axes
    local coaxialDot = currentSpeed > 0 and desiredDirection:Dot(currentVelocity.Unit) or 0
    local lateralDot = currentSpeed > 0 and root.CFrame.RightVector:Dot(currentVelocity.Unit) or 0

    -- Calculate necessary forces
    local coaxialOutput = self._PIDs.Coaxial:Calculate(SIGN(self._Throttle.Ratio) * desiredSpeed, currentSpeed * coaxialDot, dt)
    local lateralOutput = self._PIDs.Lateral:Calculate(0, currentSpeed * lateralDot, dt)

    -- Scale thrust up by mass to achieve target speeds at defined acceleration rates
    self._Forces.Coaxial.Force = coaxialOutput * root.AssemblyMass * COAXIAL
    self._Forces.Lateral.Force = lateralOutput * root.AssemblyMass * LATERAL

    -- Lastly, also update the yaw controller
    
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
