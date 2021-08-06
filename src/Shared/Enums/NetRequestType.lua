-- BUILT-IN ENUMS MOVE NEGATIVE

return {
    RandomOverwrite = -14;
    RandomRequest = -13;

	DataChange = -12;
	DataStream = -11;

	EffectChange = -10;
	EffectStop = -9;
	Effect = -8;

	SoundChange = -7;
	SoundStop = -6;
	Sound = -5;

	AssetRequest = -4;
	Quick = -3;
	Ready = -2;
	Test = -1;
	BulkRequest = 0;

    EntityStream = 1;
    EntityRequest = 2;

    WarpPrepare = 3;
    WarpExit = 4;
	WarpPreparing = 5; -- Replication
	WarpExited = 6; -- Replication

    ShipControl = 7;

    TurretShoot = 8;
	TurretTarget = 9; -- Used only for users to replicate their targeting, server does it automatically
	TurretMode = 10; -- Used only for users to replicate their mode switching, server does it automatically
}