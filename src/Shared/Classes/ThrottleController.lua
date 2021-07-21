-- ThrottleController class
-- Manages desired vehicle speed
--
-- Dynamese (Enduo)
-- 07.20.2021


local DeepObject = require(script.Parent.DeepObject)
local ThrottleController = {}
ThrottleController.__index = ThrottleController
setmetatable(ThrottleController, DeepObject)


local ABS = math.abs
local CLAMP = math.clamp
local SIGN = math.sign


-- Constructor
-- @param acceleration <float> [0, inf) rate the velocity reaches a goal
-- @param deceleration <float> [0, inf) rate the velocity returns to 0
-- @param minSpeed <float> (inf, 0] minimum speed this throttle can go
-- @param maxSpeed <float> [0, inf) maximum speed this throttle can go
-- @returns <ThrottleController>
function ThrottleController.new(acceleration, deceleration, minSpeed, maxSpeed)
    assert(maxSpeed > minSpeed, "Max must be greater than min")

	local self = setmetatable(DeepObject.new({
        _Acceleration = acceleration,
        _Deceleration = deceleration,
        _Min = minSpeed,
        _Max = maxSpeed,

        Goal = 0,
        Velocity = 0
    }), ThrottleController)

	return self
end


-- Sets the throttle goal
-- @param x <float> [minSpeed, maxSpeed]
function ThrottleController:SetGoal(x)
    self.Goal = CLAMP(x, self._Min, self._Max)
end


-- Sets the throttle target, and translates to a goal
-- @param t <float> [-1, 1]
function ThrottleController:SetThrottle(t)
    if (t >= 0) then
        -- [0, 1]
        self:SetGoal((t/1) * self._Max)
    else
        -- [-1, 0]
        self:SetGoal((-t/1) * self._Min)
    end
end


-- Sets the throttle velocity
-- @param v <float> [minSpeed, maxSpeed]
function ThrottleController:SetVelocity(v)
    self.Velocity = v
end


-- Various setters, incase other operations must be done based on the changes
-- @param v <float>
function ThrottleController:SetMaxSpeed(v)
    self._Max = v
end
function ThrottleController:SetMinSpeed(v)
    self._Min = v
end
function ThrottleController:SetAccel(v)
    self._Acceleration = v
end
function ThrottleController:SetDecel(v)
    self._Deceleration = v
end

-- Updates velocity
-- @param dt <float> delta time
function ThrottleController:Step(dt)
    local accel = ABS(self.Goal) > ABS(self.Velocity) and self._Acceleration or self._Deceleration
    local goalDiff = ABS(self.Goal - self.Velocity)

    if (goalDiff <= accel * dt) then
        self.Velocity = self.Goal
    else
        if (self.Goal == 0) then
            self.Velocity -= SIGN(self.Velocity) * accel * dt
        else
            self.Velocity = CLAMP(self.Velocity + SIGN(self.Goal) * accel * dt, self._Min, self._Max)
        end
    end
end


return ThrottleController
