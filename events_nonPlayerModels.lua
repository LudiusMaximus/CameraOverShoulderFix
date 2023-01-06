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





-- TODO: Should be in another file.
local hardcodedSpellsToModels = {

  [202477] = {
    ["name"] = "Masquerade",
    ["all"] = {
      [2] = 1368718,
      [3] = nil,
    },
  },

}



-- customSpellsToModels


function cosFix:SpellsToModel(spellId)

  -- TODO: If setFactorFrame is open, check if spellId is the current spell.
  -- local f = self.setFactorFrame
  -- if f and f:IsShown() and ... then
    
  -- end


  -- Next priority is given to custom factors.
  if customOffsetFactors[idType][id] then
    return customOffsetFactors[idType][id]["factor"]
  end
  
  -- Next priority is given to hardcoded factors.
  if self.hardcodedOffsetFactors[idType][id] then
    return self.hardcodedOffsetFactors[idType][id]
  end
  
  
  -- Otherwise the id is not yet known.
  if idType == "vehicleId" then
    local vehicleName = cosFix.vehicleIdToName[id] or UnitName("vehicle")
    if not vehicleName then
      self:DebugPrintUnknownModel("Vehicle with ID " .. id .. " not yet known. |cffff9900|Hitem:cosFix:vehicleId:".. id .."|h[Click here to define it!]|h|r")
    else
      self:DebugPrintUnknownModel("Vehicle '" .. vehicleName .. "' (" .. id .. ") not yet known. |cffff9900|Hitem:cosFix:vehicleId:".. id .."|h[Click here to define it!]|h|r")
    end
  elseif idType == "mountId" then
    local creatureName = C_MountJournal_GetMountInfoByID(id)
    self:DebugPrintUnknownModel("Mount '" .. creatureName .. "' (" .. id .. ") not yet known. |cffff9900|Hitem:cosFix:mountId:".. id .. "|h[Click here to define it!]|h|r")
  elseif idType == "modelId" then
    -- Provide id of last spellcast!
    if cosFix.lastSpellId and GetTime() - cosFix.lastSpellTime < 0.2 then
      local spellName = GetSpellInfo(cosFix.lastSpellId)
      self:DebugPrintUnknownModel("Model with ID " .. id .. " (" .. spellName .. " ?) not yet known. |cffff9900|Hitem:cosFix:modelId:" .. id .. ":spellId:" .. cosFix.lastSpellId .. "|h[Click here to define it!]|h|r")
    else
      self:DebugPrintUnknownModel("Model with ID " .. id .. " not yet known. Perform form change again to get the responsible spell.")
    end
  end
  
  return 0

end






-- When we see an unknown model id, we have to know what spell is
-- causing the form change, such that we can trigger the shoulder
-- offset change one frame before UNIT_MODEL_CHANGED.
-- As there is no mapping between spellId and modelId.
cosFix.lastSpellId = nil
cosFix.lastSpellTime = 0





local counterPrimedSpellId = nil
local counterPrimedMode = nil


local frameCounter = 0
local startTime = 0.0
local timesOfFrames = {}

-- These are set to -1 by the primer.
local shoulderOffsetChangedAtFrame = 999
local unitModelChangedAtFrame = 999

-- To calculate the current seconds per frame (elapse).
-- Because the delay may vary depending on that.
local elapseNum = 0
local elapseSum = 0

-- Save the elapse that was used to predict the
-- delay for the shoulder offset change.
-- When it was too early, we want to updated
-- this elapse's delay, and not that of the elapse
-- that might be there when UNIT_MODEL_CHANGED
-- has happened.
local triggeringAvgElapse = 0

-- If the shoulder offset is triggered too late, we have to penalise
-- the avgElapse of every previous frame which was too great.
local avgElapseOfFrames = {}




local function Round(number)
  if (number - (number % 0.1)) - (number - (number % 1)) < 0.5 then
    number = number - (number % 1)
  else
    number = (number - (number % 1)) + 1
  end
  return number
end





local function LearnFunction(magicNumberByAvgElapse, avgElapseList, correctDelay)

  for _, avgElapse in pairs(avgElapseList) do

    if magicNumberByAvgElapse[avgElapse] == nil then
      print("Creating new entry for", avgElapse, "(", correctDelay, ") .")
      magicNumberByAvgElapse[avgElapse] = {}
      magicNumberByAvgElapse[avgElapse][1] = correctDelay
      magicNumberByAvgElapse[avgElapse][2] = 0
    else
      print("Checking", avgElapse, "(", magicNumberByAvgElapse[avgElapse][1], ") for outlier:", magicNumberByAvgElapse[avgElapse][2])
      if magicNumberByAvgElapse[avgElapse][2] > 0 then
        magicNumberByAvgElapse[avgElapse][2] = magicNumberByAvgElapse[avgElapse][2] - 1
        print("Probably just an outlier! We give", avgElapse, "(", magicNumberByAvgElapse[avgElapse][1], ")", magicNumberByAvgElapse[avgElapse][2], "more chances!")
      else
        print("Failed too often! Updating delay for", avgElapse, "to", correctDelay)
        magicNumberByAvgElapse[avgElapse][1] = correctDelay
        magicNumberByAvgElapse[avgElapse][2] = 0
      end
    end

  end

end







local function PrimeTimer(spellId, mode)

  print("########### Priming timer for", spellId, mode)

  -- TODO: Try to learn event patterns preceding the outliers.
  -- Mark the events of this frame (and previous?) to store them
  -- as soon as UNIT_MODEL_CHANGED has happened.


  -- Create entry in newFactorTriggers if necessary.
  if not newFactorTriggers[spellId] then
    newFactorTriggers[spellId] = {}
  end
  if not newFactorTriggers[spellId][mode] then
    newFactorTriggers[spellId][mode] = {}
  end


  counterPrimedSpellId = spellId
  counterPrimedMode = mode

  frameCounter = 0
  startTime = GetTime()

  shoulderOffsetChangedAtFrame = -1
  unitModelChangedAtFrame = -1

  timesOfFrames = {}
  elapseNum = 0
  elapseSum = 0
  avgElapseOfFrames = {}

end







-- -- TODO: Try to learn event patterns preceding the outliers.
-- local function EventLogFunction(self, event, ...)
  -- -- Log all events and store them for a certain time.
-- end
-- local eventLogFrame = CreateFrame("Frame")
-- eventLogFrame:RegisterAllEvents()
-- eventLogFrame:SetScript("OnEvent", EventLogFunction)











local currentBuffs = nil
local function UnitAuraFunction(_, _, ...)

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

        -- This is for the setFactorFrame...
        cosFix.lastSpellId = spellId
        cosFix.lastSpellTime = GetTime()

        -- TODO: Make function to check custom and hardcoded.
        if hardcodedSpellsToModels[spellId] then
          PrimeTimer(spellId, "enter")
        end
      end
    end

    -- Which buffs have gone?
    for spellId in pairs(currentBuffs) do
      if not newBuffs[spellId] then

        -- TODO: Make function to check custom and hardcoded.
        if hardcodedSpellsToModels[spellId] then
          PrimeTimer(spellId, "leave")
        end
      end
    end

  end

  currentBuffs = newBuffs
end
local unitAuraFrame = CreateFrame("Frame")
unitAuraFrame:RegisterEvent("UNIT_AURA")
unitAuraFrame:SetScript("OnEvent", UnitAuraFunction)









local function FrameCounterFunction(_, elapse)

  -- This is how we know that the counter is still running.
  if shoulderOffsetChangedAtFrame ~= -1 and unitModelChangedAtFrame ~= -1 then return end

  -- Store the times of all frames. If the shoulder offset change is too late,
  -- we can go back and see what the delay should have been to be exactly
  -- one frame before UNIT_MODEL_CHANGED.
  local timeOfFrame = GetTime() - startTime
  timesOfFrames[frameCounter] = timeOfFrame

  print("+++++++ frame:", frameCounter, "time:", timeOfFrame)


  -- If the shoulder offset change has not happened yet.
  if shoulderOffsetChangedAtFrame == -1 then

    elapseNum = elapseNum + 1
    elapseSum = elapseSum + Round(elapse * 1000)
    local avgElapse = Round(elapseSum/elapseNum)

    avgElapseOfFrames[frameCounter] = avgElapse

    -- Get the delay how long to wait after UNIT_AURA before triggering factor change,
    -- for the current average frame rate.
    local timerTrigger = 0


    local magicNumberByAvgElapse = newFactorTriggers[counterPrimedSpellId][counterPrimedMode]

    if magicNumberByAvgElapse[avgElapse] then

      timerTrigger = magicNumberByAvgElapse[avgElapse][1]
      print("Already got a delay for elapse", avgElapse)

    elseif next(magicNumberByAvgElapse) ~= nil then

      print("No delay for elapse", avgElapse)

      -- Find closest entry in magicNumberByAvgElapse.
      local largestSmaller = -1
      local smallestLarger = -1

      local a = {}
      for k in pairs(magicNumberByAvgElapse) do table.insert(a, k) end
      table.sort(a)
      for i = 1, #a do
        if a[i] < avgElapse then
          largestSmaller = a[i]
        else
          smallestLarger = a[i]
          break
        end
      end

      if smallestLarger ~= -1 and largestSmaller ~= -1 then
        if math.abs(avgElapse - largestSmaller) < math.abs(smallestLarger - avgElapse) then
          timerTrigger = magicNumberByAvgElapse[largestSmaller][1]
          print ("taking:", largestSmaller)
        else
          timerTrigger = magicNumberByAvgElapse[smallestLarger][1]
          print ("taking:", smallestLarger)
        end
      elseif smallestLarger == -1 and largestSmaller ~= -1 then
        timerTrigger = magicNumberByAvgElapse[largestSmaller][1]
        print ("taking:", largestSmaller)
      elseif smallestLarger ~= -1 and largestSmaller == -1 then
        timerTrigger = magicNumberByAvgElapse[smallestLarger][1]
        print ("taking:", smallestLarger)
      end

    end

    print("Will trigger shoulder offset change after ", timerTrigger)


    if timeOfFrame >= timerTrigger then

      print("----------> CHANGING OFFSET NOW, frame:", frameCounter, "time:", timeOfFrame)

      -- Remember when this happened to compare it with the time of UNIT_MODEL_CHANGED.
      -- This is also required to terminate the counter, which stops as soon as
      -- shoulderOffsetChangedAtFrame and unitModelChangedAtFrame are not -1 any more.
      shoulderOffsetChangedAtFrame = frameCounter


      -- Has UNIT_MODEL_CHANGED already happened?
      if unitModelChangedAtFrame ~= -1 then
        print("|cffff0000", shoulderOffsetChangedAtFrame - (unitModelChangedAtFrame - 1), "TOO LATE!|r")
        print("Should have been at", timesOfFrames[unitModelChangedAtFrame - 1])

        local correctDelay = timesOfFrames[unitModelChangedAtFrame - 1]
        -- Penalise all previous avgElapse that were too great.
        -- I.e. we are removing those here, that were ok.
        for k, v in pairs(avgElapseOfFrames) do
          print(k, v)
          if magicNumberByAvgElapse[v] and magicNumberByAvgElapse[v][1] <= correctDelay then
            print("    was OK")
            avgElapseOfFrames[k] = nil
          end
        end

        LearnFunction(magicNumberByAvgElapse, avgElapseOfFrames, correctDelay)

      else
        -- Remember the avgElapse whose delay we took for the trigger.
        -- If it turns out to be too early, we want to correct the
        -- delay of triggeringAvgElapse and not that of whatever an avgElapse might
        -- be when UNIT_MODEL_CHANGED has happened.
        triggeringAvgElapse = avgElapse
      end





      -- Actually apply the new shoulder offset.
      if counterPrimedMode == "leave" then
      
        local _, raceFile = UnitRace("player")
        if cosFix.raceAndGenderToModelId[raceFile] ~= nil then
          local modelId = cosFix.raceAndGenderToModelId[raceFile][UnitSex("player")]
          cosFix.currentModelFactor = cosFix.playerModelOffsetFactors[modelId]
        else
          cosFix:DebugPrint("RaceFile " .. raceFile .. " not in raceAndGenderToModelId...")
        end
      
      elseif counterPrimedMode == "enter" then
      
        -- TODO: Make function to check custom and hardcoded factors.
        local modelId = hardcodedSpellsToModels[counterPrimedSpellId][UnitSex("player")]
        
        cosFix.currentModelFactor = cosFix:ModelToShoulderOffset("model", modelId)
      end
      
      local correctedShoulderOffset = cosFix:GetCurrentShoulderOffset() * cosFix:GetShoulderOffsetZoomFactor(GetCameraZoom()) * cosFix.currentModelFactor
      SetCVar("test_cameraOverShoulder", correctedShoulderOffset)

    end
  end

  frameCounter = frameCounter + 1

end
local frameCounterFrame = CreateFrame("Frame")
frameCounterFrame:SetScript("onUpdate", FrameCounterFunction)







local function UnitModelChangedFunction(_, _, ...)
  local unitName = ...
  if unitName ~= "player" then
    return
  end

  if shoulderOffsetChangedAtFrame == -1 or unitModelChangedAtFrame == -1 then

    -- Check that you have actually changed into the expected model,
    -- and not into another interfering one.
    cosFix.modelFrame:SetUnit("player")
    if hardcodedSpellsToModels[counterPrimedSpellId][UnitSex("player")] ~= cosFix.modelFrame:GetModelFileID() then
      print(cosFix.modelFrame:GetModelFileID(), "is not the model we were waiting for", hardcodedSpellsToModels[counterPrimedSpellId][UnitSex("player")])
      return
    end
    
    
    print("----------> UNIT_MODEL_CHANGED, frame:", frameCounter, "time:", GetTime() - startTime)
    
    
    unitModelChangedAtFrame = frameCounter

    -- TODO: Try to learn event patterns preceding the outliers.
    -- Store the marked events of UNIT_AURA frame (and before?) as belonging
    -- to unitModelChangedAtFrame-1 (or rather timesOfFrames[unitModelChangedAtFrame-1]?)
    -- in a database. This database could then be the training data for some learing algorithm.



    -- If the shoulder offset change has already happened,
    -- we check whether it really was 1 frame before UNIT_MODEL_CHANGED.
    if shoulderOffsetChangedAtFrame ~= -1 then

      local magicNumberByAvgElapse = newFactorTriggers[counterPrimedSpellId][counterPrimedMode]

      if shoulderOffsetChangedAtFrame == unitModelChangedAtFrame - 1 then
        print("|cff00ff00PERFECT!|r")

        -- If necessary create a new entry.
        if magicNumberByAvgElapse[triggeringAvgElapse] == nil then
          print("Creating a new entry for elapse", triggeringAvgElapse)
          magicNumberByAvgElapse[triggeringAvgElapse] = {}
          magicNumberByAvgElapse[triggeringAvgElapse][1] = timesOfFrames[shoulderOffsetChangedAtFrame]
          magicNumberByAvgElapse[triggeringAvgElapse][2] = 0

        -- Otherwise reward this delay for being correct (max is 3).
        elseif magicNumberByAvgElapse[triggeringAvgElapse][2] < 3 then
          magicNumberByAvgElapse[triggeringAvgElapse][2] = magicNumberByAvgElapse[triggeringAvgElapse][2] + 1
        end

      else
        print("|cffff0000", unitModelChangedAtFrame - 1 - shoulderOffsetChangedAtFrame, "TOO EARLY!|r")
        print("Should have been at", timesOfFrames[unitModelChangedAtFrame - 1])

        -- Make the new delay as small as possible, such that it would still have triggered the
        -- shoulder offset change at the right frame.
        LearnFunction(magicNumberByAvgElapse, {triggeringAvgElapse}, timesOfFrames[unitModelChangedAtFrame - 2] + 0.001)
      end
    end

  end
end
local unitModelChangedFrame = CreateFrame("Frame")
unitModelChangedFrame:RegisterEvent("UNIT_MODEL_CHANGED")

-- TODO: Reenable to continue:
-- unitModelChangedFrame:SetScript("OnEvent", UnitModelChangedFunction)


