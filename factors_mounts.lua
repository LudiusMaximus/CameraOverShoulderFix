local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName);

-- Map mountId to sholder offset factor.
-- TODO: Here we have to fill in offset factors for each and every mount model in the game...
-- We could maybe make this a "croudsourcing" endeavour. People will see the console message below,
-- if their current mount is not yet in the code, and I could make a youtube video tutorial
-- explaining how to determine the correct factor, which they would then send to us.
cosFix.mountIdToShoulderOffsetFactor = {

  [6]   = 7.5,   -- Brown Horse
  [17]  = 7.6,   -- Felsteed
  [71]  = 4.7,   -- Gray Kodo
  [72]  = 4.7,   -- Brown Kodo
  [76]  = 4.3,   -- Black War Kodo
  [101] = 4.3,   -- Great White Kodo
  [102] = 4.3,   -- Great Gray Kodo
  [103] = 4.3,  -- Great Brown Kodo
  [152] = 6.45,  -- Red Hawkstryder
  [157] = 6.45,  -- Purple Hawkstryder
  [158] = 6.45,  -- Blue Hawkstryder
  [159] = 6.45,  -- Black Hawkstryder
  [203] = 5.8,   -- Cenarion War Hippogryph
  [268] = 2.5,   -- Albino Drake
  [309] = 4.7,   -- White Kodo
  [435] = 7.6,   -- Mountain Horse
  [780] = 5.4,   -- Felsaber

};