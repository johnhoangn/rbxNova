local Servo = require(script.Parent.Servo)
local DeepObject = require(script.Parent.DeepObject)
local Turret = {}
Turret.__index = Turret
setmetatable(Turret, DeepObject)

local ATAN = math.atan2
local ASIN = math.asin
local RAD = math.rad
local DEG = math.deg
local SQRT = math.sqrt


-- Turret constructor. This class exists to simplify pointing the turret (all things rendering)
-- @param hardpoint <Model> that this turret is mounted on
-- @param asset <table> turret asset
-- @param uid <string> turret's uid
-- @param speed <number> DEGREES/s
-- @param yawRange <NumberRange> [-180, 180) DEGREES
-- @param pitchRange <NumberRange> [-180, 180) DEGREES
function Turret.new(hardpoint, uid, asset, speed, yawRange, pitchRange)
	local turretModel = asset.Model:Clone()
	local self = setmetatable(DeepObject.new({
		_LastShot = 0;
		_TargetReachable = false;

		UID = uid;
		Asset = asset;
		Model = turretModel;
		Hardpoint = hardpoint;
		PitchOrigin = turretModel.PitchOrigin;
		LookVector = hardpoint.PrimaryPart.CFrame.LookVector;
		Speed = speed;
		YawRange = NumberRange.new(RAD(yawRange.Min), RAD(yawRange.Max));
		PitchRange = NumberRange.new(RAD(pitchRange.Min), RAD(pitchRange.Max));
	}), Turret)

	turretModel:SetPrimaryPartCFrame(hardpoint.PrimaryPart.CFrame)
	self.Modules.WeldUtil:WeldParts(turretModel.PrimaryPart, hardpoint.PrimaryPart)
	turretModel.Name = uid
	turretModel.Parent = hardpoint

	self.Mode = self.Enums.TurretMode.Priority

	-- Lua-only servos for the server
	if (game:GetService("Players").LocalPlayer == nil) then
		self._YawServo = Servo.new(nil, nil, self.Speed)
		self._PitchServo = Servo.new(nil, nil, self.Speed)
	end

	return self
end


-- Calculates lead time based on relative velocities
-- https://devforum.roblox.com/t/making-a-lead-shot-indicator/325666/9
-- TODO: Consider inheriting velocity of the hardpoint
-- @param target <BasePart>
function Turret:LeadTime(target)
	local f = self.Asset.ProjectileSpeed
	local s = target.Position - self.Model.PitchOrigin.Position
	local m = target.Velocity
	local t

	local a = f^2 - m:Dot(m)
	local b = -2 * m:Dot(s)
	local c = -s:Dot(s)
	local d = b^2 - 4*a*c

	if (d < 0) then
		return -1
	else
		t = math.max(
			(-b + SQRT(d)) / (2 * a),
			(-b - SQRT(d)) / (2 * a)
		)

		if (t < 0) then
			return -1
		else
			return t
		end
	end
end


-- Checks if a position is in our range of motion
-- @param targetPos <Vector3>
-- @returns <boolean> if targetPos is in our range of motion
-- @returns <float> closest the turret can yaw towards the targetPos in DEGREES
-- @returns <float> closest the turret can pitch towards the targetPos in DEGREES
function Turret:CanPointAt(targetPos)
	local targetVector = targetPos - self.PitchOrigin.Position

	-- Relative vectors, representing deltas per axis
	local relative = self.PitchOrigin.CFrame:VectorToObjectSpace(targetVector).Unit

	-- Necessary angles to reach targetPos
	local nYaw = ATAN(relative.X, -relative.Z)
	local nPitch = ASIN(relative.Y) -- Hypotenuse is always 1 (unit vector)

	-- Reachable angles
	local yaw = math.clamp(nYaw, self.YawRange.Min, self.YawRange.Max)
	local pitch = math.clamp(nPitch, self.PitchRange.Min, self.PitchRange.Max)

	return yaw == nYaw and pitch == nPitch, -DEG(yaw), DEG(pitch)
end


-- Starts pointing this turret as close as possible to the provided position
-- Leads the turret by relative velocities and distance
-- @param target <BasePart>
function Turret:PointAt(target)
	local airTime = self:LeadTime(target)
	local maxAirTime = self.Asset.ProjectileRange / self.Asset.ProjectileSpeed
	local reachable, yaw, pitch

	-- TODO: Affect max range with skills
	if (airTime > -1 and airTime <= maxAirTime) then
		reachable, yaw, pitch = self:CanPointAt(target.Position + target.Velocity * airTime)
		self._TargetReachable = reachable
	else
		reachable, yaw, pitch = self:CanPointAt(target.Position)
		self._TargetReachable = false
	end

	self._YawServo:SetGoal(yaw)
	self._PitchServo:SetGoal(pitch)
end


-- Syntax sugar for retrieving the turret's target
-- @returns <BasePart> == nil
function Turret:GetTarget()
	return self.Hardpoint.Target.Value
end


-- Assigns this turret's target, behavior defined by .Mode
-- @param target <BasePart>
function Turret:SetTarget(target)
	if (self:GetTarget() ~= nil) then
		-- Clean up the previous tracker if previous still exists
		self._TargetTracker:Disconnect()
	end

	if (target ~= nil) then
		-- When targets are assigned, we want to automatically stop tracking if it dies
		self._TargetTracker = target.AncestryChanged:Connect(function()
			if (not target:IsDescendantOf(workspace)) then
				self._TargetTracker:Disconnect()
				self:SetTarget(nil)
			end
		end)
	end

	self.Hardpoint.Target.Value = target
end


-- Checks if a target is shootable based on current lookvector
-- Assumes distance check was already done
-- @param target
-- @return <boolean>
function Turret:TargetInTolerance(target)
	return true
end


-- Checks if this turret's target is within range and in view
-- @param now <float> current tick()
-- @returns <boolean>
function Turret:CanFire(now)
	return now - self._LastShot > self.Asset.Cooldown
		--and self:InRange(self:GetTarget().Position)
		and self._TargetReachable and self:TargetInTolerance(self:GetTarget())
end


-- Necessary to step the servos
-- @param dt <float>
function Turret:Step(dt)
	if (self:GetTarget() ~= nil) then
		-- Turret has a target, attempt to point at it
		self:PointAt(self:GetTarget())
	end

	self._YawServo:Step(dt)
	self._PitchServo:Step(dt)

	self.LookVector = (self.PitchOrigin.CFrame * CFrame.Angles(
		self._PitchServo.Angle,
		self._YawServo.Angle,
		0
	)).LookVector
end


-- CLIENT METHODS
if (game:GetService("Players").LocalPlayer == nil) then return Turret end


local serverConstructor = Turret.new
function Turret.new(model, ...)
	local self = serverConstructor(...)
	local turretModel = self.Model

	self.Mode = self.Enums.TurretMode.Priority -- Integer
	self._TargetReachable = false

	self._YawServo = Servo.new(
		turretModel.YawActuator,
		self.Model.Upper.YawActuated,
		self.Speed
	)
	self._PitchServo = Servo.new(
		turretModel.Upper.PitchActuator,
		turretModel.Upper.Pitcher.PitchActuated,
		self.Speed
	)

	-- Put this turret in the render model not the base model
	turretModel.Parent = model

	return self
end


return Turret
