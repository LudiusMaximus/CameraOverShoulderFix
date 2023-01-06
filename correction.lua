local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)


local _G = _G
local pairs = _G.pairs
local strsplit = _G.strsplit
local tonumber = _G.tonumber

local C_MountJournal_GetMountInfoByID = _G.C_MountJournal.GetMountInfoByID
local C_MountJournal_GetMountIDs = _G.C_MountJournal.GetMountIDs
local GetShapeshiftFormID = _G.GetShapeshiftFormID
local IsMounted = _G.IsMounted
local UnitBuff = _G.UnitBuff
local UnitClass = _G.UnitClass
local UnitInVehicle = _G.UnitInVehicle
local UnitGUID = _G.UnitGUID
local UnitName = _G.UnitName
local UnitOnTaxi = _G.UnitOnTaxi
local UnitRace = _G.UnitRace
local UnitSex = _G.UnitSex


local dynamicCamLoaded = IsAddOnLoaded("DynamicCam")
local DynamicCam = _G.DynamicCam

-- Frame to check what player model is active.
if not cosFix.modelFrame then
  cosFix.modelFrame = CreateFrame("PlayerModel")
end





function cosFix:ModelToShoulderOffset(idType, id)

  -- If setFactorFrame is open for id, it overrides everything. 
  local f = self.setFactorFrame
  if f and f:IsShown() and f.idType == idType and f.id == id then
    return f.offsetFactor
  end

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





-- Returns the mount ID of the currently active mount if any.
function cosFix:GetCurrentMount()

  -- To skip the iteration through all mounts trying to find the active one,
  -- we store the last active mount to be checked first.
  -- This variable is also used when C_MountJournal_GetMountInfoByID() cannot
  -- identify the active mount even though isMounted() returns true. This
  -- happens when porting somewhere while being mounted or when in the Worgen
  -- "Running wild" state.
  if self.db.char.lastActiveMount then
    -- print("Last active mount: " .. self.db.char.lastActiveMount)
    local _, _, _, active = C_MountJournal_GetMountInfoByID(self.db.char.lastActiveMount)
    if active then
      return self.db.char.lastActiveMount
    end
  end

  -- This looks horribly ineffective, but apparently there is no way of getting the
  -- currently active mount's id directly...
  for _, v in pairs (C_MountJournal_GetMountIDs()) do

    local _, _, _, active = C_MountJournal_GetMountInfoByID(v)

    if active then
      -- Store current mount as last active mount.
      self.db.char.lastActiveMount = v
      return v
    end
  end

  return nil
end





function cosFix:GetCurrentModelId()
  -- print("GetCurrentModelId()")

  self.modelFrame:SetUnit("player")
  local modelId = self.modelFrame:GetModelFileID()

  if modelId == nil then

    -- If it exists, use the lastModelId.
    if self.db.char.lastModelId ~= nil then
      modelId = self.db.char.lastModelId
    -- Otherwise, if possible use the standard for the player's race and gender.
    else
      local _, raceFile = UnitRace("player")

      -- In case of unknown player races.
      if self.raceAndGenderToModelId[raceFile] ~= nil then
        modelId = self.raceAndGenderToModelId[raceFile][UnitSex("player")]
      else
        self:DebugPrint("RaceFile " .. raceFile .. " not in raceAndGenderToModelId...")
      end
    end

    -- Try again later to find the correct modelId.
    self:SetLastModelId()

  -- If this is a known normal (no shapeshift) modelId, store it in lastModelId.
  elseif self.playerModelOffsetFactors[modelId] ~= nil then
    self.db.char.lastModelId = modelId
  end

  -- print("modelId", modelId)
  return modelId

end


-- When the model id cannot be determined, we start a timer to call SetLastModelId() again.
-- Due to several events at the same time, it may happen that several calls happen at the same time.
-- We only want one timer running at a time.
cosFix.lastModelIdTimerId = nil

function cosFix:SetLastModelId()
  -- print("SetLastModelId()")

  self.modelFrame:SetUnit("player")
  local modelId = self.modelFrame:GetModelFileID()
  -- print(modelId)

  if modelId == nil then
    if (self.lastModelIdTimerId == nil) or (self.lastModelIdTimerId and self:TimeLeft(self.lastModelIdTimerId) < 0) then
      -- print("Restarting!")
      self.lastModelIdTimerId = self:ScheduleTimer("SetLastModelId", 0.01)
    -- else
      -- print("Timer already running!")
    end
  else
    -- print("SetLastModelId determined", modelId)
    self.lastModelIdTimerId = nil


    -- Only store and apply known normal modelIds.
    if self.playerModelOffsetFactors[modelId] ~= nil then

      self.db.char.lastModelId = modelId

      self.currentModelFactor = self.playerModelOffsetFactors[modelId]

      -- Set the shoulder offset again!
      if not dynamicCamLoaded or (not DynamicCam.LibCamera:IsZooming() and not self.easeShoulderOffsetInProgress) then

        local correctedShoulderOffset = self:GetCurrentShoulderOffset() * self:GetShoulderOffsetZoomFactor(GetCameraZoom()) * self.currentModelFactor
        SetCVar("test_cameraOverShoulder", correctedShoulderOffset)

      end

    end
  end
end



-- Switch lastModelId of a Worgen without having to care about gender.
function cosFix:GetOppositeLastWorgenModelId()

  -- No lastModelId.
  if self.db.char.lastModelId == nil then
    return self.playerModelOffsetFactors[self.raceAndGenderToModelId["Worgen"][UnitSex("player")]]

  elseif self.playerModelOffsetFactors[self.db.char.lastModelId] == nil then
    self:DebugPrint("SHOULD NEVER HAPPEN!")
    return self.playerModelOffsetFactors[self.raceAndGenderToModelId["Worgen"][UnitSex("player")]]

  -- Normal case.
  elseif self.db.char.lastModelId == self.raceAndGenderToModelId["Human"][UnitSex("player")] then
    return self.raceAndGenderToModelId["Worgen"][UnitSex("player")]
  elseif self.db.char.lastModelId == self.raceAndGenderToModelId["Worgen"][UnitSex("player")] then
    return self.raceAndGenderToModelId["Human"][UnitSex("player")]

  -- Valid last lastModelId but neither Worgen nor Human.
  else
    return self.playerModelOffsetFactors[self.raceAndGenderToModelId["Worgen"][UnitSex("player")]]
  end

end





-- WoW interprets the test_cameraOverShoulder variable differently depending on the current player model.
-- If we want the camera to always have the same shoulder offset relative to the player's center,
-- we need to adjust the test_cameraOverShoulder value depending on the current player model.
-- Arguments:
--   enteringVehicleGuid      (optional) When CorrectShoulderOffset is called while entering a vehicle
--                            we pass the vehicle's GUID to determine the test_cameraOverShoulder adjustment.
--                            This is necessary because while entering the vehicle, UnitInVehicle("player") will
--                            still return 'false' while the camera is already regarding the vehicle's model.
function cosFix:CorrectShoulderOffset(enteringVehicleGuid)

  -- print("CorrectShoulderOffset")

  self.modelFrame:SetUnit("player")
  local modelId = self.modelFrame:GetModelFileID()
  -- print("Current modelId", modelId)


  local returnValue = 1

  -- Is the player entering a vehicle or already in a vehicle?
  if enteringVehicleGuid or UnitInVehicle("player") then
    -- print("You are entering or on a vehicle.")

    local vehicleGuid = ""
    if enteringVehicleGuid then
      vehicleGuid = enteringVehicleGuid
      -- print("Entering vehicle.", enteringVehicleGuid)
    else
      vehicleGuid = UnitGUID("vehicle")
      -- print("Already in vehicle.", vehicleGuid)
    end

    -- TODO: Could also be "Player-...." if you mount a player in druid travel form.
    -- TODO: Or what if you mount another player's "double-seater" mount?

    local _, _, _, _, _, vehicleId = strsplit("-", vehicleGuid)
    vehicleId = tonumber(vehicleId)
    returnValue = self:ModelToShoulderOffset("vehicleId", vehicleId)


  -- Is the player mounted?
  elseif IsMounted() then
    -- print("You are mounted.")

    -- No idea why this is necessary when mounted; seems to be a persistent bug on Blizzard's side!
    local mountedFactor = 1
    if cosFix:GetCurrentShoulderOffset() < 0 then
      mountedFactor = mountedFactor / 10
    end

    -- Is the player really mounted and not on a "taxi"?
    if not UnitOnTaxi("player") then

      local mountId = self:GetCurrentMount()
      -- print(mountId)

      -- Right after logging in while on a mount it happens that "IsMounted()" returns true,
      -- but C_MountJournal_GetMountInfoByID() is not yet able to determine that the mount is active.
      -- Furthermore, when in Worgen "Running wild" state, you get isMounted() without a mount.
      if mountId == nil then
        -- print("Mounted but no mount")

        -- Check for special buffs.
        local specialBuffActive = false

        for i = 1, 40 do
          local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
          -- print (name, spellId)

          if spellId == 87840 then
            -- print("Running wild")

            -- This is actually only needed for the unlikely case that at any point
            -- "Running wild" would be used by a non-Worgen model.
            local modelId = self:GetCurrentModelId()

            -- If an unknown modelId is returned, assume that we are Worgen (more likely than any other model).
            if (modelId == nil) or (self.playerModelOffsetFactors[modelId] == nil) then
              returnValue = mountedFactor * self.playerModelOffsetFactors[self.raceAndGenderToModelId["Worgen"][UnitSex("player")]] * 10
            else
              -- This would also work for "Running wild" with any other model in playerModelOffsetFactors.
              returnValue = mountedFactor * self.playerModelOffsetFactors[modelId] * 10
            end

            specialBuffActive = true
            break

          elseif spellId == 40212 then
            -- print("Dragonmaw Nether Drake")
            returnValue = mountedFactor * 2.5
            specialBuffActive = true
            break
          end
        end


        if not specialBuffActive then
          -- Should only happen when logging in mounted with a character after purging of SavedVariables.
          if self.db.char.lastActiveMount == nil then
            returnValue = mountedFactor * 6

          -- Use the last active mount.
          else
            mountId = self.db.char.lastActiveMount
            returnValue = self:ModelToShoulderOffset("mountId", mountId)
            
          end
        end

      -- mountId not nil
      else

        returnValue = self:ModelToShoulderOffset("mountId", mountId)
        
        -- -- Did not find a way to convert normal mount offset into mounted-dracthyr offest.
        -- local modelId = self:GetCurrentModelId()
        -- if modelId == 4207724 then
          -- print("You are in dracthyr form")
          -- returnValue = returnValue
        -- end
        
      end

    else
      -- print("You are on a taxi!")

      -- Flag to remember that you are on a taxi, because the shoulder offset change while
      -- leaving a taxi (PLAYER_MOUNT_DISPLAY_CHANGED) needs special treatment...
      self.db.char.isOnTaxi = true

      -- Works all right for Wind Riders.
      -- TODO: This should probably also be done individually for all taxi models in the game.
      returnValue = mountedFactor * 2.5
    end



  -- Is the player shapeshifted?
  -- Shapeshift form (id 30) is stealth and should be treated like normal.
  elseif (GetShapeshiftFormID(true) ~= nil) and (GetShapeshiftFormID(true) ~= 30) then
    -- print("You are shapeshifted.")

    local _, englishClass = UnitClass("player")
    local formId = GetShapeshiftFormID(true)

    if englishClass == "DRUID" then

      local _, raceFile = UnitRace("player")
      if self.druidFormIdToShoulderOffsetFactor[raceFile] then

        local genderCode = UnitSex("player")
        if self.druidFormIdToShoulderOffsetFactor[raceFile][genderCode] then


          if self.druidFormIdToShoulderOffsetFactor[raceFile][genderCode][formId] then
            returnValue = self.druidFormIdToShoulderOffsetFactor[raceFile][genderCode][formId]
          else
            self:DebugPrint(raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " druid form factor for form id " .. formId .. " not yet known...")
            returnValue = 1
          end
        else
          self:DebugPrint(raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " druid form factors not yet known...")
          returnValue = 1
        end
      else
        self:DebugPrint(raceFile .. " druid form factors not yet known...")
        returnValue = 1
      end

    elseif formId == 16 then
      -- print("...Ghostwolf")
      returnValue = self.shamanGhostwolfToShoulderOffsetFactor[formId]

    else
      self:DebugPrint("Shapeshift form '" .. formId .. "' not yet known...")

    end


  -- Is the player "normal"?
  else
    -- print("You are normal ...")

    local _, englishClass = UnitClass("player")
    local _, raceFile = UnitRace("player")
    local genderCode = UnitSex("player")
    -- print(englishClass, raceFile, genderCode)

    -- Check for Demon Hunter Metamorphosis.
    local metamorphosis = false
    if englishClass == "DEMONHUNTER" then
      for i = 1, 40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        -- print(name, spellId)
        if spellId == 162264 then
          -- print("Demon Hunter Metamorphosis Havoc")
          if self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Havoc"] then
            returnValue = self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Havoc"]
          else
            self:DebugPrint(raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " Demonhunter form factor for 'Havoc' not yet known...")
            returnValue = 1
          end

          metamorphosis = true
          break

        elseif spellId == 187827 then
          -- print("Demon Hunter Metamorphosis Vengeance")
          if self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Vengeance"] then
            returnValue = self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Vengeance"]
          else
            self:DebugPrint(raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " Demonhunter form factor for 'Vengeance' not yet known...")
            returnValue = 1
          end

          metamorphosis = true
          break

        end
      end
    end

    if not metamorphosis then
    
      -- print("No Metamorphosis ...")

      local modelId = self:GetCurrentModelId()


      if modelId == nil then
        -- We did all we can in GetCurrentModelId()...
        returnValue = -1

      -- If we have a hardcoded player model offset, use it!      
      elseif self.playerModelOffsetFactors[modelId] then
         -- print("Hardcoded player id")
        returnValue = self.playerModelOffsetFactors[modelId]
      
      else
        returnValue = self:ModelToShoulderOffset("modelId", modelId)
      end

    end
  end

  -- print("returnValue", returnValue)
  return returnValue

end

