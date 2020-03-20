local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)

-- Map modelId of player models to sholder offset factor.
cosFix.modelIdToShoulderOffsetFactor = {

  -- Alliance core races
  [1011653] = 1.26,   -- Human male                 - 2019-12-29
  [1000764] = 1.458,  -- Human female               - 2020-01-03
  [878772]  = 1.15,   -- Dwarf male                 - 2020-01-01
  [950080]  = 1.428,  -- Dwarf female               - 2020-01-03
  [974343]  = 1.20,   -- NightElf male              - 2020-01-04
  [921844]  = 1.38,   -- NightElf female            - 2019-12-29
  [900914]  = 1.392,  -- Gnome male                 - 2020-01-04
  [940356]  = 1.403,  -- Gnome female               - 2020-01-04
  [1005887] = 0.962,  -- Draenei male               - 2020-03-17
  [1022598] = 1.28,   -- Draenei female             - 2020-01-01
  [307454]  = 0.94,   -- Worgen male
  [307453]  = 1.18,   -- Worgen female

  -- Alliance allied races
  [1734034] = 1.337,  -- VoidElf male               - 2020-01-03
  [1733758] = 1.41,   -- VoidElf female             - 2020-01-03
  [1620605] = 0.965,  -- LightforgedDraenei male    - 2020-03-16
  [1593999] = 1.28,   -- LightforgedDraenei female  - 2020-03-16
  [1890765] = 1.14,   -- DarkIronDwarf male         - 2020-03-16
  [1890763] = 1.45,   -- DarkIronDwarf female       - 2020-03-16
  [1721003] = 0.999,  -- KulTiran male              - 2020-03-17
  [1886724] = 1.2,    -- KulTiran female            - 2020-03-17
  [2622502] = 1.421,  -- Mechagnome male            - 2020-03-17
  [2564806] = 1.453,  -- Mechagnome female          - 2020-03-17

  -- Horde core races
  [1968587] = 1.00,   -- (Maghar)Orc male (upright) - 2020-01-01
  [917116]  = 0.975,  -- (Maghar)Orc male (hunched) - 2020-01-01
  [949470]  = 1.229,  -- (Maghar)Orc female         - 2020-01-02
  [959310]  = 1.22,   -- Scourge male               - 2020-01-01
  [997378]  = 1.362,  -- Scourge female             - 2020-01-01
  [968705]  = 0.9,    -- Tauren male                - 2020-01-01
  [986648]  = 1.1,    -- Tauren female              - 2020-01-02
  [1022938] = 0.98,   -- Troll male                 - 2020-01-02
  [1018060] = 1.25,   -- Troll female               - 2020-01-02
  [1100087] = 1.337,  -- BloodElf male              - 2020-01-01
  [1100258] = 1.41,   -- BloodElf female            - 2020-01-02
  [119376]  = 1.31,   -- Goblin male                - 2020-01-02
  [119369]  = 1.3,    -- Goblin female              - 2020-01-02

  -- Horde allied races
  [1814471] = 1.198,  -- Nightborne male            - 2020-03-17
  [1810676] = 1.267,  -- Nightborne female          - 2020-03-17
  [1630218] = 0.9,    -- HighmountainTauren male    - 2020-03-17
  [1630402] = 1.1,    -- HighmountainTauren female  - 2020-03-17
                      -- MagharOrc male (same as Orc)
                      -- MagharOrc female (same as Orc)
  [1630447] = 1.05,   -- ZandalariTroll male
  [1662187] = 1.09,   -- ZandalariTroll female

  -- Pandaren
  [535052]  = 0.95,   -- Pandaren male              - 2020-01-01
  [589715]  = 1.07,   -- Pandaren female            - 2020-01-01




  [118653]  = 1.03,   -- Dragonmaw Fel Orc male (Dragonmaw Illusion in BC Shadowmoon Valley)
  [124118]  = 0.87,   -- Furbolg Form (Stave of Fur and Claw)
  [1113034] = 1.2,    -- Murloc Costume




}



-- We only use this for Worgen form changes (so far)...
cosFix.raceAndGenderToModelId = {
  -- race                      male           female
  ["Human"]              = {  [2] = 1011653,  [3] = 1000764 },
  ["Dwarf"]              = {  [2] = 878772,   [3] = 950080 },
  ["NightElf"]           = {  [2] = 974343,   [3] = 921844 },
  ["Gnome"]              = {  [2] = 900914,   [3] = 940356 },
  ["Draenei"]            = {  [2] = 1005887,  [3] = 1022598 },
  ["Worgen"]             = {  [2] = 307454,   [3] = 307453  },

  ["VoidElf"]            = {  [2] = 1734034,  [3] = 1733758  },
  ["LightforgedDraenei"] = {  [2] = 1620605,  [3] = 1593999  },
  ["DarkIronDwarf"]      = {  [2] = 1890765,  [3] = 1890763  },
  ["KulTiran"]           = {  [2] = 1721003,  [3] = 1886724  },

  ["Orc"]                = {  [2] = 1968587,  [3] = 949470  },
  ["Scourge"]            = {  [2] = 959310,   [3] = 997378  },
  ["Tauren"]             = {  [2] = 968705,   [3] = 986648  },
  ["Troll"]              = {  [2] = 1022938,  [3] = 1018060  },
  ["BloodElf"]           = {  [2] = 1100087,  [3] = 1100258  },
  ["Goblin"]             = {  [2] = 119376,   [3] = 119369  },

  ["Nightborne"]         = {  [2] = 1814471,  [3] = 1810676  },
  ["HighmountainTauren"] = {  [2] = 1630218,  [3] = 1630402  },
  ["MagharOrc"]          = {  [2] = 1968587,  [3] = 949470  },   -- Same as Orc
  ["ZandalariTroll"]     = {  [2] = 1630447,  [3] = 1662187  },

  ["Pandaren"]           = {  [2] = 535052,   [3] = 589715  },

};




cosFix.knownUnknownModelId = {

  -- Happens while changing from Tree of Life back to normal.
  -- [464148]  = 1.00,

  -- -- Happens when mounting while in flight form.
  -- [126077]  = 1.00,

  [926251]  = 1.00,   -- Ghostwolf

  [1270180]  = 1.00,   -- Havoc Demon Hunter, BloodElf male

};



