local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)


cosFix.druidFormIdToShoulderOffsetFactor = {
  ["Tauren"] = {
    [2] = {   -- male
      [1]   = 0.862,   -- Cat
      [2]   = 0.78,    -- Tree of Life
      [3]   = 0.888,   -- Travel
      [4]   = 0.71,    -- Aquatic
      [5]   = 0.83,    -- Bear
      [27]  = 0.532,   -- Swift Flight
      [29]  = 0.545,   -- Flight
      [31]  = 0.933,   -- Moonkin
    },
    [3] = {   -- female
      [1]   = 0.788,   -- Cat
      [2]   = 0.715,   -- Tree of Life
      [3]   = 0.815,   -- Travel
      [4]   = 0.651,   -- Aquatic
      [5]   = 0.76,    -- Bear
      [27]  = 0.49,    -- Swift Flight
      [29]  = 0.502,   -- Flight     -- TODO
      [31]  = 0.853,   -- Moonkin
    },
  },
  ["Worgen"] = {
    -- Actually the same for male and female...
    [2] = {   -- male
      [1]   = 0.689,   -- Cat
      [2]   = 0.63,    -- Tree of Life
      [3]   = 0.663,    -- Travel
      [4]   = 0.515,   -- Aquatic
      [5]   = 0.68,    -- Bear
      [27]  = 0.38,    -- Swift Flight
      [29]  = 0.38,    -- Flight     -- TODO
      [31]  = 0.72,    -- Moonkin
    },
    [3] = {   -- female
      [1]   = 0.685,   -- Cat
      [2]   = 0.63,    -- Tree of Life
      [3]   = 0.66,    -- Travel
      [4]   = 0.515,   -- Aquatic
      [5]   = 0.68,    -- Bear
      [27]  = 0.38,    -- Swift Flight
      [29]  = 0.38,    -- Flight     -- TODO
      [31]  = 0.72,    -- Moonkin
    },
  }
};


cosFix.demonhunterFormToShoulderOffsetFactor = {
  ["BloodElf"] = {
    [2] = {   -- male
      ["Havoc"]     = 0.52,
      ["Vengeance"] = 0.74,
    },
    [3] = {   -- female
      ["Havoc"]     = 0.57,
      ["Vengeance"] = 0.87,
    },
  },
  ["NightElf"] = {
    [2] = {   -- male
      ["Havoc"]     = 0.52,
      ["Vengeance"] = 0.74,
    },
    [3] = {   -- female
      ["Havoc"]     = 0.61,
      ["Vengeance"] = 0.91,
    },
  },
}


cosFix.shamanGhostwolfToShoulderOffsetFactor = {
  [16]  = 0.758,  -- Ghostwolf
};

