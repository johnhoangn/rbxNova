-- Servo class, meant to replace the Constraint version when we don't need replication
-- Dynamese (Enduo)
-- 07.08.2021


local Servo = {}
Servo.__index = Servo



local ZERO_VECTOR = Vector3.new()
local ABS = math.abs
local SIGN = math.sign
local RAD = math.rad


local function ClearWelds(part)
    for _, c in ipairs(part:GetChildren()) do
        if (c:IsA("WeldConstraint")) then
            c:Destroy()
        end
    end
end


-- Creates an infinite torque servo motor
-- Pivots about the actuated part's local Y axis
--  current relative orientation and positioning is maintained
-- !! NOTE: Does not replicate when used on client !!
-- @param actuator <BasePart> serves as the servo motor
-- @param actuated <BasePart> this is rotated by the motor
-- @param speed <float> [0, INF) == 360 in degrees/s
-- @returns <Servo>
function Servo.new(actuator, actuated, speed)
    if (not (actuator.Anchored and actuated.Anchored)) then
        warn("Servo components not anchored! This could cause misalignments!", actuator.Parent:GetFullName())
    end

    local weld = Instance.new("WeldConstraint")
    local relative = actuator.CFrame:ToObjectSpace(actuated.CFrame)

    local self = setmetatable({
        _Relative = relative;
        _Weld = weld;

        Actuator = actuator;
        Actuated = actuated;
        Speed = RAD(speed or 360); -- avoids excessive RAD calls in :Step()
        Angle = 0;
        Goal = 0;
        Delta = 0;
    }, Servo)

    weld.Name = "Servo [" .. actuator.Name .. ", " .. actuated.Name .. "]"
    weld.Part0 = actuator
    weld.Part1 = actuated
    weld.Parent = actuator

    actuator.Anchored = false
    actuated.Anchored = false

    ClearWelds(actuator)
    ClearWelds(actuated)

	return setmetatable(self, Servo)
end


-- Creates an infinite torque servo, but copies the original parts into a model
-- @param actuator <BasePart>
-- @param actuated <BasePart>
-- @param speed <float> [0, INF)
-- @param name <string> == "Servo"
-- @returns <Servo>, <Model>
function Servo.new2(actuator, actuated, speed, name)
    local servo = Instance.new("Model")
    local a = actuator:Clone()
    local b = actuated:Clone()

    -- Make small
    a.Size = ZERO_VECTOR
    b.Size = ZERO_VECTOR

    -- Make invisible
    a.Transparency = 1
    b.Transparency = 1

    -- Put
    a.CFrame = actuator.CFrame
    b.CFrame = actuated.CFrame

    -- Name & parent
    a.Name = "Actuator"
    b.Name = "Actuated"
    servo.Name = name or "Servo"

    a.Parent = servo
    b.Parent = servo

    return Servo.new(a, b, speed), servo
end


-- Creates an infinite torque servo from a model instead of two parts
-- @param servoModel <Model> Model containing Actuator and Actuated parts
-- @param speed <float> [0, INF) in degrees/s
-- @returns <Servo>
function Servo.fromModel(servoModel, speed)
    return Servo.new(servoModel.Actuator, servoModel.Actuated, speed)
end


-- @param angle <float> (-360, 360)
function Servo:SetGoal(angle)
    self.Goal = SIGN(angle) * RAD(angle % 360)
    self.Delta = self.Goal - self.Angle
end


-- @param dt <float>
function Servo:Step(dt)
    if (ABS(self.Delta) > 0) then
        -- Calculate what happened in the elapsed dt
        local dir = SIGN(self.Goal - self.Angle)
        local willRotate = dir * self.Speed * dt

        -- Prevent overshoot
        if (ABS(willRotate) > ABS(self.Delta)) then
            self.Angle = self.Goal
        else
            self.Angle += willRotate
        end

        self.Delta = self.Goal - self.Angle

        -- Apply
        self._Weld.Enabled = false
        self.Actuated.CFrame = self.Actuator.CFrame * self._Relative * CFrame.Angles(0, self.Angle, 0)
        self._Weld.Enabled = true
    end
end


return Servo
