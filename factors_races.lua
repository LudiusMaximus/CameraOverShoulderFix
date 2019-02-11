local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)






cosFix.modelIdToShoulderOffsetFactor = {

  [1011653] = 1.25,   -- Human male
  [1000764] = 1.45,   -- Human female
  [878772]  = 1.13,   -- Dwarf male
  [950080]  = 1.46,   -- Dwarf female
  [974343]  = 1.20,   -- NightElf male
  [921844]  = 1.40,   -- NightElf female
  [900914]  = 1.60,   -- Gnome male
  [940356]  = 1.62,   -- Gnome female
  [1005887] = 0.98,   -- Draenei male
  [1022598] = 1.28,   -- Draenei female
  [307454]  = 0.94,   -- Worgen male
  [307453]  = 1.18,   -- Worgen female

  [1734034] = 1.32,   -- VoidElf male
  [1733758] = 1.40,   -- VoidElf female
  [1620605] = 0.98,   -- LightforgedDraenei male
  [1593999] = 1.28,   -- LightforgedDraenei female
  [1890765] = 1.13,   -- DarkIronDwarf male
  [1890763] = 1.46,   -- DarkIronDwarf female
  [1721003] = 1.00,   -- KulTiran male
  [1886724] = 1.21,   -- KulTiran female


  [1968587] = 1.00,   -- Orc male (upright)
  [917116]  = 0.97,   -- Orc male (hunched)
  [949470]  = 1.25,   -- Orc female
  [959310]  = 1.20,   -- Scourge male
  [997378]  = 1.40,   -- Scourge female
  [968705]  = 1.00,   -- Tauren male
  [986648]  = 1.15,   -- Tauren female
  [1022938] = 0.98,   -- Troll male
  [1018060] = 1.25,   -- Troll female
  [1100087] = 1.32,   -- BloodElf male
  [1100258] = 1.40,   -- BloodElf female
  [119376]  = 1.32,   -- Goblin male
  [119369]  = 1.32,   -- Goblin female

  [1814471]  = 1.20,  -- Nightborne male
  [1810676]  = 1.27,  -- Nightborne female


  [535052]  = 0.95,   -- Pandaren male
  [589715]  = 1.07,   -- Pandaren female

}



-- We only use this for Worgen form changes (so far)...
cosFix.raceAndGenderToModelId = {
  -- race                         male         female
  ["Human"]              = {  [2] = 1011653,  [3] = 1000764 },
  ["Worgen"]             = {  [2] = 307454,   [3] = 307453  },
};

