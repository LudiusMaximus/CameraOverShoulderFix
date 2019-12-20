local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)

-- Map mountId to sholder offset factor.
cosFix.mountIdToShoulderOffsetFactor = {

  [6]   = 7.74,  -- Brown Horse                  - 2019-12-19
  [17]  = 7.6,   -- Felsteed
  [19]  = 6.0,   -- Dire Wolf
  [71]  = 4.7,   -- Gray Kodo
  [72]  = 4.7,   -- Brown Kodo
  [76]  = 4.3,   -- Black War Kodo
  [101] = 4.3,   -- Great White Kodo
  [102] = 4.3,   -- Great Gray Kodo
  [103] = 4.3,   -- Great Brown Kodo
  [152] = 6.45,  -- Red Hawkstryder
  [157] = 6.45,  -- Purple Hawkstryder
  [158] = 6.45,  -- Blue Hawkstryder
  [159] = 6.45,  -- Black Hawkstryder
  [203] = 5.71,  -- Cenarion War Hippogryph      - 2019-12-19
  [268] = 2.5,   -- Albino Drake
  [309] = 4.7,   -- White Kodo
  [310] = 6.1,   -- Black Wolf
  [435] = 7.6,   -- Mountain Horse
  [547] = 5.7,   -- Hearthsteed
  [651] = 5.6,   -- Warlord's Deathwheel
  [780] = 5.4,   -- Felsaber
  [934] = 5.75,  -- Swift Spectral Hippogryph

};

