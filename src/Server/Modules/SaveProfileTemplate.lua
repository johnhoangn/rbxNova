return {
    Whereabouts = {
        System = "Sol";
        SolarPosition = {0, 0};
        SolarOrientation = {0, 0};
    };
    Warehouse = {
        --[[
        [BaseID] = 3;
        --]]
    }; -- Owned attachments, hangars, bays, ammo, etc.
	OwnedShips = {}; -- Configs and appearances only
    CurrentShip = {
        BaseID = "061";
        Appearance = {};
        WeaponGroups = {};
        Skills = {
            Exp = 0;
            Points = 0;
            Handling = {};
            Engineering = {};
            Turrets = {};
        };
        Config = {
            Modifications = {};
            Sections = {
                Bow = {
                    Shield = 10; -- Allocated
                    Armor = 10;
                    Attachments = {
                        --[[
                        [UID] = {
                            BaseID = "070";
                            Hardpoint = "A";
                        };
                        [UID] = {
                            BaseID = "0A0";
                            Qty = 1000;
                        }
                        --]]
                    };
                };
                Aft = {
                    Shield = 10;
                    Armor = 10;
                    Attachments = {

                    };
                };
                Port = {
                    Shield = 10;
                    Armor = 10;
                    Attachments = {

                    };
                };
                Starboard = {
                    Shield = 10;
                    Armor = 10;
                    Attachments = {

                    };
                };
                Core = {
                    Shield = 10;
                    Armor = 10;
                    Attachments = {

                    };
                };
            };
        };
        Status = {
            Bow = {
                Armor = 10; -- Current
                Hull = 10;
                Attachments = {

                };
            };
            Aft = {
                Armor = 10;
                Hull = 10;
                Attachments = {

                };
            };
            Port = {
                Armor = 10;
                Hull = 10;
                Attachments = {

                };
            };
            Starboard = {
                Armor = 10;
                Hull = 10;
                Attachments = {

                };
            };
            Core = {
                Armor = 10;
                Hull = 10;
                Attachments = {

                };
            };
        };
    };
    Pilot = {
        Exp = 0;
        Level = 0;
    };
    Settings = {

    };
    UIConfig = {

    };
    Misc = {

    };
}