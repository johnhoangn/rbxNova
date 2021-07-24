local DeepObject = require(script.Parent.DeepObject)
local Projectile = {}
Projectile.__index = Projectile
setmetatable(Projectile, DeepObject)

-- How many random numbers an instance of this class needs
-- Each random will be a float in the range [0, 1)
Projectile.RandomsNeeded = 1


-- Base projectile constructor
-- @param turretAsset <table> turret asset for information
-- @param turretModel <Model> specific turret that shot this
-- @param target <BasePart> ship section part
-- @param randoms <table> array of random numbers, based on Projectile.RandomsNeeded
function Projectile.new(turretAsset, turretModel, target, randoms)
	local self = setmetatable(DeepObject.new({
        TurretAsset = turretAsset;
        TurretModel = turretModel;
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
        turretModel.AncestryChanged:Connect(function()
            if (not turretModel:IsDescendantOf(workspace)) then
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
