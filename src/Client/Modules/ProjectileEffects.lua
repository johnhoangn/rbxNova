-- Projectile effects module, similar to the Server's Projectile base class and derived classes,
--	but this one doesn't do hit detection. It is purely responsible for gathering the necessary information
--	to create and play local effects for ONLY the user's ship's turrets.
-- We generate the effects only for the usership to mitigate any latency-related effect desyncs. Other entities'
--	projectiles will be handled automatically via receiving the packet and routing directly to EffectService
-- In summary, since we don't have the packet, we create it ourselves.
-- Intent is to store all projectile effect parameter generators in this module.
--
-- Dynamese (Enduo)
-- 07.29.2021



local Effects = {}


function Effects.Beam(projectileAlgo, turret, turretAsset, randoms)
	local offset1, offset2 = projectileAlgo.Generate(turret, randoms)

	return turret.Hardpoint,
		turret.UID,
		turret:GetTarget(),
		offset1,
		offset2,
		Color3.new(0,1,1), --turretAsset.BeamColor,
		turretAsset.ProjectileRange,
		turretAsset.Duration
end


function Effects.Repeater(projectileAlgo, turret, randoms)
	local turretAsset = turret.Asset
	local spreads = projectileAlgo.Generate(turret, randoms)

	return turret.Hardpoint,
		turret.UID,
		turret:GetTarget(),
		turretAsset.ProjectileSpeed,
		turretAsset.ProjectileLength,
		spreads,
		turretAsset.BeamColor,
		turretAsset.ProjectileRange
end


function Effects.Torpedo(projectileAlgo, turret, randoms)
	local turretAsset = turret.Asset

end


function Effects.MissileBarrage(projectileAlgo, turret, randoms)
	local turretAsset = turret.Asset

end


return Effects