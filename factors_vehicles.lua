local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)

-- Map vehicleId to sholder offset factor.
cosFix.vehicleIdToShoulderOffsetFactor = {

  [35129]  = 0.38,  -- Reprogrammed Shredder (Azshara)
  [40854]  = 0.20,  -- River Boat (Thousand Needles)
  
  [113042] = 1.0,   -- Illidan Stormrage (Ravencrest Scenario)
  [113101] = 1.0,   -- Illidan Stormrage (Temple Summit Scenario)
  
  [114281] = 1.0,   -- Flight Master's Mount (Flight Master's Whistle)

};