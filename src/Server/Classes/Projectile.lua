local DeepObject = require(script.Parent.DeepObject)
local Projectile = {}
Projectile.__index = Projectile
setmetatable(Projectile, DeepObject)

-- How many random numbers an instance of this class needs
Projectile.NecessaryRandoms = 1


-- Base projectile constructor
-- @param baseID <string> baseID of the turret asset for information
-- @param entity <T extends Entity> source of this projectile
-- @param turretUID <string> specific turret from entityBase that shot this
-- @param randoms <table> array of random numbers, based on Projectile.NecessaryRandoms
function Projectile.new(baseID, entity, turretUID, target, randoms)
	local self = setmetatable(DeepObject.new({
        BaseID = baseID;
        Entity = entity;
        TurretUID = turretUID;
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
        entity.Base.AncestryChanged:Connect(function()
            if (not entity.Base:IsDescendantOf(workspace)) then
                self:Destroy()
            end
        end)
    )

	return setmetatable(self, Projectile)
end


function Projectile:Fire()
    error("Attempt to :Fire() base class Projectile!")
end


return Projectile
