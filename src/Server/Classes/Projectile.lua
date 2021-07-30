local DeepObject = require(script.Parent.DeepObject)
local Projectile = {}
Projectile.__index = Projectile
setmetatable(Projectile, DeepObject)

-- Base projectile constructor
-- @param turret <Turret> specific turret that shot this
-- @param randoms <table> array of random numbers, based on Algorithm.Randoms
function Projectile.new(turret, randoms)
	local target = turret:GetTarget()
	local self = setmetatable(DeepObject.new({
        Turret = turret;
        Target = target;
        Randoms = randoms;
    }), Projectile)

    self:GetMaid():GiveTask(
        target.AncestryChanged:Connect(function()
            if (not target:IsDescendantOf(workspace)) then
                self:Destroy()
            end
        end)
    )

    self:GetMaid(
        turret.Model.AncestryChanged:Connect(function()
            if (not turret.Model:IsDescendantOf(workspace)) then
                self:Destroy()
            end
        end)
    )

	return setmetatable(self, Projectile)
end


function Projectile:Fire(dt)
    error("Attempt to :Fire() base class Projectile!")
end


return Projectile
