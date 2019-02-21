local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)

-- Map vehicleId to sholder offset factor.
cosFix.vehicleIdToShoulderOffsetFactor = {

  [35129]  = 0.38,  -- Reprogrammed Shredder
  [40854]  = 0.20,  -- River Boat

};