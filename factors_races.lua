local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)


cosFix.raceAndGenderToShoulderOffsetFactor = {

  -- http://wowwiki.wikia.com/wiki/API_UnitRace
  -- https://wow.gamepedia.com/RaceId
  -- race                         male         female
  ["Orc"]                 = {  [2] = 1.00,  [3] = 1.26  },
  ["MagharOrc"]           = {  [2] = 1.00,  [3] = 1.26  },   -- Assumed same as Orc (not tested).
  ["Scourge"]             = {  [2] = 1.20,  [3] = 1.40  },
  ["Tauren"]              = {  [2] = 1.00,  [3] = 1.15  },
  ["HighmountainTauren"]  = {  [2] = 1.00,  [3] = 1.15  },   -- Assumed same as Tauren (not tested).
  ["Troll"]               = {  [2] = 0.98,  [3] = 1.25  },
  ["BloodElf"]            = {  [2] = 1.32,  [3] = 1.38  },
  ["VoidElf"]             = {  [2] = 1.32,  [3] = 1.38  },   -- Assumed same as BloodElf (not tested).
  ["Goblin"]              = {  [2] = 1.32,  [3] = 1.32  },
  ["Human"]               = {  [2] = 1.25,  [3] = 1.45  },
  ["Dwarf"]               = {  [2] = 1.13,  [3] = 1.42  },
  ["DarkIronDwarf"]       = {  [2] = 1.13,  [3] = 1.42  },   -- Assumed same as Dwarf (not tested).
  ["NightElf"]            = {  [2] = 1.20,  [3] = 1.40  },
  ["Nightborne"]          = {  [2] = 1.20,  [3] = 1.40  },   -- Assumed same as NightElf (not tested).
  ["Gnome"]               = {  [2] = 1.60,  [3] = 1.62  },
  ["Draenei"]             = {  [2] = 0.98,  [3] = 1.28  },
  ["LightforgedDraenei"]  = {  [2] = 0.98,  [3] = 1.28  },   -- Assumed same as Draenei (not tested).
  ["Pandaren"]            = {  [2] = 0.95,  [3] = 1.07  },
  -- These are the factors for Worgen form. For Human form take Human factors.
  ["Worgen"]              = {  [2] = 0.94,  [3] = 1.18  },
  ["WorgenRunningWild"]   = {  [2] = 9.40,  [3] = 11.8  },

};


cosFix.modelId = {
  ["Human"]              = {  [2] = 1011653,  [3] = 1000764 },
  ["Worgen"]             = {  [2] = 307454,   [3] = 307453  },
};