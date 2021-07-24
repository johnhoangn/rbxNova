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


local function DebugPart(c)
    local p = Instance.new("Part")

    p.Anchored = true
    p.CanTouch = false
    p.CanCollide = false
    p.Material = Enum.Material.Neon
    p.Color = c or Color3.new(0.443137, 0.925490, 0.886274)

    return p
end


function EntityShip.new(base, initialParams)
    AssetService = AssetService or EntityShip.Services.AssetService

	local self = Entity.new(base, initialParams)
    local asset = AssetService:GetAsset(initialParams._BaseID)

    self._Root = base.PrimaryPart
    self._Asset = asset

    self.ThrustCoaxial = asset.ShipData.ThrustCoaxial
    self.ThrustLateral = asset.ShipData.ThrustLateral
    self.ThrustYaw = math.rad(asset.ShipData.ThrustYaw)
    self.SpeedFwd = asset.ShipData.SpeedFwd
    self.SpeedRev = asset.ShipData.SpeedRev
    self.SpeedYaw = math.rad(asset.ShipData.SpeedYaw)

    -- Auto update attributes
    self:GetMaid():GiveTask(
        base.AttributeChanged:Connect(function(attr)
            local attrVal = base:GetAttribute(attr)
            local thrustSubStr, b = attr:find("Thrust")

            if (thrustSubStr ~= nil) then
                local target = attr:sub(b + 1)

                if (target == "Yaw") then
                    attrVal = math.rad(attrVal)
                end

                self._PIDs[target].Bounds.Min = -attrVal
                self._PIDs[target].Bounds.Max = attrVal
                self[attr] = attrVal

            elseif (attr:find("Speed") ~= nil) then
                if (attr == "SpeedYaw") then
                    attrVal = math.rad(attrVal)
                end
                self[attr] = attrVal
                self:SetThrottle(self._Throttle.Value)
            end
        end)
    )

    -- Thrusters
    self._Forces = {
        Coaxial = base.PrimaryPart.CoaxialForce;
        Lateral = base.PrimaryPart.LateralForce;
        Yaw = base.PrimaryPart.YawTorque;
    };

    -- Thrust controllers
    self._PIDs = {
        -- Tuning PID gains is actually just an art; these are 100% trial + error
        Coaxial = PID.new(1, 0, 0, -self.ThrustCoaxial, self.ThrustCoaxial);
        Lateral = PID.new(1, 0, 0, -self.ThrustLateral, self.ThrustLateral);
        Yaw = PID.new(1, 0, 0, -self.ThrustYaw, self.ThrustYaw)
    }

    -- PID inputs
    self._SteerDirection = 0
    self._Throttle = {
        Ratio = 0;
        Value = 0;
    }

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
        targetPosition = targetPosition * XZ_PLANE
        self._SteerDirection = self._Root.CFrame.LookVector:Cross((targetPosition - self._Root.Position).Unit).Y
    else
        self._SteerDirection = 0
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
    local desiredYawSpeed = self._SteerDirection * self.SpeedYaw

    -- Figure the speed components to divide the thrust into two: coaxial (main thruster) and lateral (side thrusters)
    -- Yielding two scalars, so the PIDs only compute their respective local axes
    local coaxialDot = currentSpeed > 0 and desiredDirection:Dot(currentVelocity.Unit) or 0
    local lateralDot = currentSpeed > 0 and root.CFrame.RightVector:Dot(currentVelocity.Unit) or 0

    -- Calculate necessary forces
    local coaxialOutput = self._PIDs.Coaxial:Calculate(SIGN(self._Throttle.Ratio) * desiredSpeed, currentSpeed * coaxialDot, dt)
    local lateralOutput = self._PIDs.Lateral:Calculate(0, currentSpeed * lateralDot, dt)
    local yawOutput = self._PIDs.Yaw:Calculate(desiredYawSpeed, root.AssemblyAngularVelocity.Y, dt)

    -- Scale thrust up by mass to achieve target speeds at defined acceleration rates
    self._Forces.Coaxial.Force = coaxialOutput * root.AssemblyMass * COAXIAL
    self._Forces.Lateral.Force = lateralOutput * root.AssemblyMass * LATERAL

    -- Also update yaw torque
    self._Forces.Yaw.Torque = yawOutput * root.AssemblyMass * YAW

    self._DebugVelocityPart.Size = Vector3.new(.2, .2, currentSpeed)
    self._DebugVelocityPart.CFrame = CFrame.lookAt(root.Position, root.Position + currentVelocity) * CFrame.new(0, 0, -self._DebugVelocityPart.Size.Z/2)
    -- TODO: Apply thruster effectiveness modifiers (when a side or the aft is blown up or the ship is in a weight threshold)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return EntityShip end


-- Clientside constructor
local serverConstructor = EntityShip.new
function EntityShip.new(...)
    local self = serverConstructor(...)

    -- Hitboxes will get in the way of effect rendering; store their offsets for
    --  targeting and delete the parts
    self.SectionOffsets = {};
    for _, section in ipairs(self.Base.Hitboxes:GetChildren()) do
        self.SectionOffsets[section.Name] = self._Root.Position - section.Position
    end
    self.Base.Hitboxes:Destroy()

    -- Attach debug
    self._DebugVelocityPart = DebugPart()
    self._DebugVelocityPart.Parent = self.Base

    return self
end


-- Renders this EntityShip
-- @param dt <float>
-- @param isMyShip <boolean> if this is the local user's ship
function EntityShip:Draw(dt, isMyShip)
    if (self.Model == nil) then
        local config = self._InitialParams.Config
        local model = self._Asset.Model:Clone()
        local hardpoints = self.Base.Hardpoints
        local turrets = self.Classes.IndexedMap.new()

        -- Stick the chassis on the base
        model:SetPrimaryPartCFrame(self.Base.PrimaryPart.CFrame)
        model.Parent = self.Base
        self.Modules.WeldUtil:WeldParts(model.PrimaryPart, self.Base.PrimaryPart)

        for section, sectionData in pairs(config.Sections) do
            local modelSection = hardpoints:FindFirstChild(section)

            if (modelSection == nil) then continue end
            for uid, attachmentData in pairs(sectionData.Attachments) do
                if (attachmentData.Hardpoint ~= nil) then
                    local turretAsset = AssetService:GetAsset(attachmentData.BaseID, self.Base)
                    local hardpoint = modelSection[attachmentData.Hardpoint]

                    -- TODO: Remove hardcoding, retrieve turret ranges from asset, etc.
                    turrets:Add(uid,
                        self.Classes.Turret.new(
                            model,
                            hardpoint,
                            uid,
                            turretAsset,
                            isMyShip and 90 or nil,
                            isMyShip and 90 or nil,
                            NumberRange.new(-120, 120),
                            NumberRange.new(-15, 80)
                        )
                    )
                end
            end
        end

        -- Opacity aesthetics
        local parts = {}
        for _, part in ipairs(model:GetDescendants()) do
            if (part:IsA("BasePart") and part.Transparency < 1) then
                parts[part] = part.Transparency
            end
        end

        self.Model = model
        self._Parts = parts
        self._Turrets = turrets
    else
        -- Animate EntityShip components
        if (self._Turrets ~= nil) then
            for _, turret in self._Turrets:Iterator() do
                turret:PointAt(workspace.b.Position)
                turret:Step(dt)
            end
        end
    end
end


-- Sets how transparent/opaque to draw this EntityShip
function EntityShip:SetOpacity()

end


-- Removes the model
function EntityShip:Hide()
    self.Model:Destroy()
    self.Model = nil
    self._Parts = nil
    self._Turrets = nil
end


-- Destroys this instance and its physical model along with it
local superDestroy = Entity.Destroy
function EntityShip:Destroy()
    self:Hide()
    superDestroy()
end


return EntityShip
