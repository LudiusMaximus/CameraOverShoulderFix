local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)




-- This is how it works:

-- Whenever we see UNIT_MODEL_CHANGED, we try to set factor corresponding
-- to the current model id. But this is often too late, because the factor
-- must be updated one frame before UNIT_MODEL_CHANGED.

-- This is why we are also listening to UNIT_AURA and check which buff
-- has been added or removed.
-- If a buff is in our newFactorTriggers table we prime the trigger to go off after
-- the given delay and set the shoulde offset of the given modelId. This delay
-- may be different depending on the current framerate, which is why we are
-- storing a value for every possible average time elapsed (frameElapse)
-- between all frames from UNIT_AURA to the factor change.
-- When we do not have the entry for the current frameElapse, we search up and down for the closest frameElapse.

-- newFactorTriggers[spellId]["enter","leave"][frameElapse][1] = delay how long to wait after UNIT_AURA before triggering factor change
-- newFactorTriggers[spellId]["enter","leave"][frameElapse][2] = rewards score how often the current delay has been successfull
-- newFactorTriggers[spellId]["modelId"][2,3] = modelId to use when entering (2 = male, 3 = female)

-- When UNIT_MODEL_CHANGED comes, we check if this is exactly one frame after our factor change.
-- If so, we increase the reward score by 1 (max is 3); and if necessary create a new frameElapse entry.
-- If not, we decrease the reward score by 1.
--   If the reward score is zero or if we have not had the fitting frameElapse entry,
--   we set a new delay which would have made the correct prediction.
-- Thus, we should be able to "learn" the best delays for all frame rates.









-- When we see an unknown model id, we have to know what spell is
-- causing the form change, such that we can trigger the shoulder
-- offset change one frame before UNIT_MODEL_CHANGED.
-- As there is no mapping between spellId and modelId 
cosFix.lastSpellId = nil
cosFix.lastSpellTime = 0






local hardcodedSpellsToModels = {

  [202477] = {   -- Masquerade
    [2] = 1368718,  -- male

  },

}







local function EnterModelChange(spellId)

  -- print(GetTime(), "EnterModelChange", spellId)
  
  -- TODO: Trigger shoulder offset change one frame before UNIT_MODEL_CHANGED!
  -- cosFix:SetDelayedShoulderOffset(0, cosFix.setFactorFrame.offsetFactor)

end


local function LeaveModelChange(spellId)

  -- print(GetTime(), "LeaveModelChange", spellId)
  
  -- TODO: Trigger shoulder offset change one frame before UNIT_MODEL_CHANGED!
  -- cosFix:SetDelayedShoulderOffset(0, cosFix.setFactorFrame.offsetFactor)

end




local currentBuffs = nil
local unitAuraFrame = CreateFrame("Frame")
unitAuraFrame:RegisterEvent("UNIT_AURA")
unitAuraFrame:SetScript("OnEvent", function(self, event, ...)
  
  local unitName = ...
  if unitName ~= "player" then
    return
  end

  
  local newBuffs = {}

  for i = 1, 40 do
    local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
    if spellId then
      newBuffs[spellId] = true
      -- print(i, name, spellId)
    end
  end
  
  
  if currentBuffs then
  
    -- Which buffs have come?
    for spellId in pairs(newBuffs) do
      if not currentBuffs[spellId] then
      
        cosFix.lastSpellId = spellId
        cosFix.lastSpellTime = GetTime()
      
        if hardcodedSpellsToModels[spellId] then
          EnterModelChange(spellId)
        end
      end
    end
  
    -- Which buffs have gone?
    for spellId in pairs(currentBuffs) do
      if not newBuffs[spellId] then
        if hardcodedSpellsToModels[spellId] then
          LeaveModelChange(spellId)
        end
      end
    end
    
  end
  
  currentBuffs = newBuffs
  
end)










local unitModelChangedFrame = CreateFrame("Frame")
unitModelChangedFrame:RegisterEvent("UNIT_MODEL_CHANGED")
unitModelChangedFrame:SetScript("OnEvent", function(self, event, ...)
  
  local unitName = ...
  if unitName ~= "player" then
    return
  end

  
  local modelFrame = CreateFrame("PlayerModel")
  modelFrame:SetUnit("player")
  local modelId = modelFrame:GetModelFileID()
  
  
  -- print(GetTime(), "UNIT_MODEL_CHANGED", modelId)
  

  cosFix:SetDelayedShoulderOffset()

end)