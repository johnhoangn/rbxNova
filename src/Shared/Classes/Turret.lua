local Servo = require(script.Parent.Servo)
local DeepObject = require(script.Parent.DeepObject)
local Turret = {}
Turret.__index = Turret
setmetatable(Turret, DeepObject)

local ATAN = math.atan2
local ASIN = math.asin
local RAD = math.rad
local DEG = math.deg

-- Turret constructor. This class exists to simplify pointing the turret (all things rendering)
-- @param hardpoint <Model> that this turret is mounted on
-- @param asset <table> turret asset
-- @param uid <string> turret's uid
-- @param yawSpeed <number> DEGREES/s
-- @param pitchSpeed <number> DEGREES/s
-- @param yawRange <NumberRange> [-180, 180) DEGREES
-- @param pitchRange <NumberRange> [-180, 180) DEGREES
function Turret.new(hardpoint, uid, asset, yawSpeed, pitchSpeed, yawRange, pitchRange)
    local turretModel = asset.Model:Clone()
	local self = setmetatable(DeepObject.new({
        _Asset = asset;

        PitchOrigin = turretModel.PitchOrigin;
        YawSpeed = yawSpeed;
        YawRange = NumberRange.new(RAD(yawRange.Min), RAD(yawRange.Max));
        PitchSpeed = pitchSpeed;
        PitchRange = NumberRange.new(RAD(pitchRange.Min), RAD(pitchRange.Max));
    }), Turret)

    turretModel:SetPrimaryPartCFrame(hardpoint.PrimaryPart.CFrame)
    self.Modules.WeldUtil:WeldParts(turretModel.PrimaryPart, hardpoint.PrimaryPart)
    turretModel.Name = uid
    turretModel.Parent = hardpoint

    self.Model = turretModel

	return self
end


-- Checks if a position is in our range of motion
-- @param target <Vector3>
-- @returns <boolean> if target is in our range of motion
-- @returns <float> closest the turret can yaw towards the target in DEGREES
-- @returns <float> closest the turret can pitch towards the target in DEGREES
function Turret:CanPointAt(target)
    local targetVector = target - self.PitchOrigin.Position

    -- Relative vectors, representing deltas per axis
    local relative = self.PitchOrigin.CFrame:VectorToObjectSpace(targetVector).Unit

    -- Necessary angles to reach target
    local nYaw = ATAN(relative.X, -relative.Z)
    local nPitch = ASIN(relative.Y) -- Hypotenuse is always 1 (unit vector)

    -- Reachable angles
    local yaw = math.clamp(nYaw, self.YawRange.Min, self.YawRange.Max)
    local pitch = math.clamp(nPitch, self.PitchRange.Min, self.PitchRange.Max)

    return yaw == nYaw and pitch == nPitch, -DEG(yaw), DEG(pitch)
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return Turret end


local serverConstructor = Turret.new
function Turret.new(model, ...)
    local self = serverConstructor(...)
    local turretModel = self.Model

    self._YawServo = Servo.new(turretModel.YawActuator,
        self.Model.Upper.YawActuated,
        self.YawSpeed
    )
    self._PitchServo = Servo.new(
        turretModel.Upper.PitchActuator,
        turretModel.Upper.Pitcher.PitchActuated,
        self.PitchSpeed
    )

    -- Put this turret in the render model not the base model
    self.Model.Parent = model

    return self
end


-- Starts pointing this turret as close as possible to the provided target
-- @param target <Vector3>
-- @returns <boolean> if target is in our range of motion
-- @returns <number> how far the turret's current lookvector is from the target DEGREES
function Turret:PointAt(target)
    local targetVector = self.PitchOrigin.CFrame:VectorToObjectSpace(target - self.PitchOrigin.Position)
    local reachable, yaw, pitch = self:CanPointAt(target)

    self._YawServo:SetGoal(yaw)
    self._PitchServo:SetGoal(pitch)

    return reachable, self.Modules.VectorUtil.AngleBetween(
        Vector3.new(
            self._YawServo.Angle, 0,
            self._PitchServo.Angle
        ), targetVector
    )
end


-- Necessary to step the servos
-- @param dt <float>
function Turret:Step(dt)
    self._YawServo:Step(dt)
    self._PitchServo:Step(dt)
end


return Turret
