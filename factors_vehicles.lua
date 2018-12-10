local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)

-- TODO: Here we have to fill in offset factors for each and every vehicle model in the game...
-- We could maybe make this a "croudsourcing" endeavour. People will see the console message below,
-- if their current vehicle is not yet in the code, and I could make a youtube video tutorial
-- explaining how to determine the correct factor, which they would then send to us.
cosFix.vehicleIdToShoulderOffsetFactor = {

  [35129]  = 0.38,  -- Reprogrammed Shredder
  [40854]  = 0.20,  -- River Boat

};