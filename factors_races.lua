local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)


cosFix.raceAndGenderToShoulderOffsetFactor = {

  -- http://wowwiki.wikia.com/wiki/API_UnitRace
  -- https://wow.gamepedia.com/RaceId
  -- race                         male         female
  ["Orc"]                 = {  [2] = 1.00,  [3] = 1.25  },
  ["MagharOrc"]           = {  [2] = 0.97,  [3] = 1.25  },   -- Female using the same model as Orc
  ["Scourge"]             = {  [2] = 1.20,  [3] = 1.40  },
  ["Tauren"]              = {  [2] = 1.00,  [3] = 1.15  },
  ["HighmountainTauren"]  = {  [2] = 1.00,  [3] = 1.15  },   -- Assumed same as Tauren (not tested).
  ["Troll"]               = {  [2] = 0.98,  [3] = 1.25  },
  ["BloodElf"]            = {  [2] = 1.32,  [3] = 1.38  },
  ["VoidElf"]             = {  [2] = 1.32,  [3] = 1.40  },
  ["Goblin"]              = {  [2] = 1.32,  [3] = 1.32  },
  
  ["Human"]               = {  [2] = 1.25,  [3] = 1.45  },
  ["Dwarf"]               = {  [2] = 1.13,  [3] = 1.42  },
  ["DarkIronDwarf"]       = {  [2] = 1.13,  [3] = 1.42  },   -- Assumed same as Dwarf (not tested).
  ["NightElf"]            = {  [2] = 1.20,  [3] = 1.40  },
  ["Nightborne"]          = {  [2] = 1.20,  [3] = 1.40  },   -- Assumed same as NightElf (not tested).
  ["Gnome"]               = {  [2] = 1.60,  [3] = 1.62  },
  ["Draenei"]             = {  [2] = 0.98,  [3] = 1.28  },
  ["LightforgedDraenei"]  = {  [2] = 0.98,  [3] = 1.28  },   -- Assumed same as Draenei (not tested).
  ["Worgen"]              = {  [2] = 0.94,  [3] = 1.18  },
  ["WorgenRunningWild"]   = {  [2] = 9.40,  [3] = 11.8  },
  
  ["Pandaren"]            = {  [2] = 0.95,  [3] = 1.07  },
};



cosFix.modelIdToShoulderOffsetFactor = {

  [1011653] = cosFix.raceAndGenderToShoulderOffsetFactor["Human"][2],
  [1000764] = cosFix.raceAndGenderToShoulderOffsetFactor["Human"][3],
  [878772]  = cosFix.raceAndGenderToShoulderOffsetFactor["Dwarf"][2],
  [950080]  = cosFix.raceAndGenderToShoulderOffsetFactor["Dwarf"][3],
  [974343]  = cosFix.raceAndGenderToShoulderOffsetFactor["NightElf"][2],
  [921844]  = cosFix.raceAndGenderToShoulderOffsetFactor["NightElf"][3],
  [900914]  = cosFix.raceAndGenderToShoulderOffsetFactor["Gnome"][2],
  [940356]  = cosFix.raceAndGenderToShoulderOffsetFactor["Gnome"][3],
  [1005887] = cosFix.raceAndGenderToShoulderOffsetFactor["Draenei"][2],
  [1022598] = cosFix.raceAndGenderToShoulderOffsetFactor["Draenei"][3],
  [307454]  = cosFix.raceAndGenderToShoulderOffsetFactor["Worgen"][2],
  [307453]  = cosFix.raceAndGenderToShoulderOffsetFactor["Worgen"][3],
  [1734034] = cosFix.raceAndGenderToShoulderOffsetFactor["VoidElf"][2],
  [1733758] = cosFix.raceAndGenderToShoulderOffsetFactor["VoidElf"][3],


  [1968587] = cosFix.raceAndGenderToShoulderOffsetFactor["Orc"][2],
  [949470]  = cosFix.raceAndGenderToShoulderOffsetFactor["Orc"][3],         -- Also used by MagharOrc female
  [917116]  = cosFix.raceAndGenderToShoulderOffsetFactor["MagharOrc"][2],
  [959310]  = cosFix.raceAndGenderToShoulderOffsetFactor["Scourge"][2],
  [997378]  = cosFix.raceAndGenderToShoulderOffsetFactor["Scourge"][3],
  [968705]  = cosFix.raceAndGenderToShoulderOffsetFactor["Tauren"][2],
  [986648]  = cosFix.raceAndGenderToShoulderOffsetFactor["Tauren"][3],
  [1022938] = cosFix.raceAndGenderToShoulderOffsetFactor["Troll"][2],
  [1018060] = cosFix.raceAndGenderToShoulderOffsetFactor["Troll"][3],
  [1100087] = cosFix.raceAndGenderToShoulderOffsetFactor["BloodElf"][2],
  [110258]  = cosFix.raceAndGenderToShoulderOffsetFactor["BloodElf"][3],
  [119376]  = cosFix.raceAndGenderToShoulderOffsetFactor["Goblin"][2],
  [119369]  = cosFix.raceAndGenderToShoulderOffsetFactor["Goblin"][3],

  [535052]  = cosFix.raceAndGenderToShoulderOffsetFactor["Pandaren"][2],
  [589715]  = cosFix.raceAndGenderToShoulderOffsetFactor["Pandaren"][2],



};






cosFix.modelId = {
  ["Human"]              = {  [2] = 1011653,  [3] = 1000764 },
  ["Worgen"]             = {  [2] = 307454,   [3] = 307453  },
};



