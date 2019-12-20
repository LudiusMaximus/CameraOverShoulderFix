local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)


local _G = _G
local pairs = _G.pairs
local strsplit = _G.strsplit
local tonumber = _G.tonumber

local CosFix_OriginalSetCVar = _G.CosFix_OriginalSetCVar

local C_MountJournal_GetMountInfoByID = _G.C_MountJournal.GetMountInfoByID
local C_MountJournal_GetMountIDs = _G.C_MountJournal.GetMountIDs
local GetShapeshiftFormID = _G.GetShapeshiftFormID
local GetUnitName = _G.GetUnitName
local IsMounted = _G.IsMounted
local UnitBuff = _G.UnitBuff
local UnitClass = _G.UnitClass
local UnitInVehicle = _G.UnitInVehicle
local UnitGUID = _G.UnitGUID
local UnitOnTaxi = _G.UnitOnTaxi
local UnitRace = _G.UnitRace
local UnitSex = _G.UnitSex


local dynamicCamLoaded = IsAddOnLoaded("DynamicCam")
local DynamicCam = _G.DynamicCam

-- Frame to check what player model is active.
if not cosFix.modelFrame then
  cosFix.modelFrame = CreateFrame("PlayerModel")
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

  -- This looks horribly ineffectice, but apparently there is no way of getting the
  -- currently active mount's id directly...
  for k, v in pairs (C_MountJournal_GetMountIDs()) do

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
    -- Attention: May also be nil for unknown player races.
    else
      local _, raceFile = UnitRace("player")
      modelId = self.raceAndGenderToModelId[raceFile][UnitSex("player")]
    end

    -- Try again later to find the correct modelId.
    self:SetLastModelId()

  -- If this is a known normal (no shapeshift) modelId, store it in lastModelId.
  elseif self.modelIdToShoulderOffsetFactor[modelId] ~= nil then
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
    if self.modelIdToShoulderOffsetFactor[modelId] ~= nil then

      self.db.char.lastModelId = modelId

      self.currentModelFactor = self.modelIdToShoulderOffsetFactor[modelId]

      -- Set the shoulder offset again!
      if not dynamicCamLoaded or (not DynamicCam.LibCamera:ZoomInProgress() and not self.easeShoulderOffsetInProgress) then

        local correctedShoulderOffset = self.currentShoulderOffset * self:GetShoulderOffsetZoomFactor(GetCameraZoom()) * self.currentModelFactor
        CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)

      end

    end
  end
end



-- Switch lastModelId of a Worgen without having to care about gender.
function cosFix:GetOppositeLastWorgenModelId()

  -- No lastModelId.
  if self.db.char.lastModelId == nil then
    return self.modelIdToShoulderOffsetFactor[self.raceAndGenderToModelId["Worgen"][UnitSex("player")]]

  elseif self.modelIdToShoulderOffsetFactor[self.db.char.lastModelId] == nil then
    self:DebugPrint("SHOULD NEVER HAPPEN!")
    return self.modelIdToShoulderOffsetFactor[self.raceAndGenderToModelId["Worgen"][UnitSex("player")]]

  -- Normal case.
  elseif self.db.char.lastModelId == self.raceAndGenderToModelId["Human"][UnitSex("player")] then
    return self.raceAndGenderToModelId["Worgen"][UnitSex("player")]
  elseif self.db.char.lastModelId == self.raceAndGenderToModelId["Worgen"][UnitSex("player")] then
    return self.raceAndGenderToModelId["Human"][UnitSex("player")]

  -- Valid last lastModelId but neither Worgen nor Human.
  else
    return self.modelIdToShoulderOffsetFactor[self.raceAndGenderToModelId["Worgen"][UnitSex("player")]]
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


  -- self.modelFrame:SetUnit("player")
  -- local modelId = self.modelFrame:GetModelFileID()
  -- print("Current modelId", modelId)


  -- If the "Correct Shoulder Offset" function is deactivated, we do not correct the offset.
  if not self.db.profile.modelIndependentShoulderOffset then
    return 1
  end


  local returnValue = 1

  -- Is the player entering a vehicle or already in a vehicle?
  if enteringVehicleGuid or UnitInVehicle("player") then
    -- print("You are entering or on a vehicle.")

    local vehicleGuid = ""
    if enteringVehicleGuid then
      vehicleGuid = enteringVehicleGuid
      -- print("Entering vehicle.")
    else
      vehicleGuid = UnitGUID("vehicle")
      -- print("Already in vehicle.")
    end

    -- TODO: Could also be "Player-...." if you mount a player in druid travel form.
    -- TODO: Or what if you mount another player's "double-seater" mount?


    local _, _, _, _, _, vehicleId = strsplit("-", vehicleGuid)
    vehicleId = tonumber(vehicleId)
    -- print(vehicleId)

    -- Is the vehicle form already in the code?
    if self.vehicleIdToShoulderOffsetFactor[vehicleId] then
      returnValue = self.vehicleIdToShoulderOffsetFactor[vehicleId]
    else
      local vehicleName = GetUnitName("vehicle", false)
      if vehicleName == nil then
        self:DebugPrint("Just entering unknown vehicle with ID " .. vehicleId .. ". Zoom in or out to get message including vehicle name!")
      else
        self:DebugPrint("Vehicle '" .. vehicleName .. "' (" .. vehicleId .. ") not yet known...")
      end

      -- Default for all unknown vehicles...
      returnValue = 0.5
    end


  -- Is the player mounted?
  elseif IsMounted() then
    -- print("You are mounted.")

    -- No idea why this is necessary when mounted; seems to be a persistent bug on Blizzard's side!
    local mountedFactor = 1
    if cosFix.currentShoulderOffset < 0 then
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
            if (modelId == nil) or (self.modelIdToShoulderOffsetFactor[modelId] == nil) then
              returnValue = mountedFactor * self.modelIdToShoulderOffsetFactor[self.raceAndGenderToModelId["Worgen"][UnitSex("player")]] * 10
            else
              -- This would also work for "Running wild" with any other model in modelIdToShoulderOffsetFactor.
              returnValue = mountedFactor * self.modelIdToShoulderOffsetFactor[modelId] * 10
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
            -- Is the mount already in the code?
            if self.mountIdToShoulderOffsetFactor[self.db.char.lastActiveMount] then
              returnValue = mountedFactor * self.mountIdToShoulderOffsetFactor[self.db.char.lastActiveMount]
            else
              local creatureName = C_MountJournal_GetMountInfoByID(self.db.char.lastActiveMount)
              self:DebugPrint("Mount '" .. creatureName .. "' (" .. self.db.char.lastActiveMount .. ") not yet known...")
              -- Default for all other mounts...
              returnValue = mountedFactor * 6
            end
          end
        end

      -- mountId not nil
      else
        -- Is the mount already in the code?
        if self.mountIdToShoulderOffsetFactor[mountId] then
          returnValue = mountedFactor * self.mountIdToShoulderOffsetFactor[mountId]
        else
          local creatureName = C_MountJournal_GetMountInfoByID(mountId)
          self:DebugPrint("Mount '" .. creatureName .. "' (" .. mountId .. ") not yet known...")
          -- Default for all other mounts...
          returnValue = mountedFactor * 6
        end
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
            self:DebugPrint(raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " Demonhunter form factor for of 'Havoc' not yet known...")
            returnValue = 1
          end

          metamorphosis = true
          break

        elseif spellId == 187827 then
          -- print("Demon Hunter Metamorphosis Vengeance")
          if self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Vengeance"] then
            returnValue = self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Vengeance"]
          else
            self:DebugPrint(raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " Demonhunter form factor for of 'Vengeance' not yet known...")
            returnValue = 1
          end

          metamorphosis = true
          break

        end
      end
    end

    if not metamorphosis then

      local modelId = self:GetCurrentModelId()


      if modelId == nil then
        -- We did all we can in GetCurrentModelId()...
        returnValue = -1

      -- This may happen for unknwon race models or shapeshift forms.
      elseif self.modelIdToShoulderOffsetFactor[modelId] == nil then

        -- Check in a list of "known unknowns" (e.g. shapeshift forms) to suppress the debug output in case.
        if self.knownUnknownModelId[modelId] == nil then
          self:DebugPrint("Model ID " .. modelId .. " not in modelIdToShoulderOffsetFactor...")
        end

        -- If it exists, use the last known normal model.
        if self.db.char.lastModelId then

          if self.modelIdToShoulderOffsetFactor[self.db.char.lastModelId] == nil then
            self:DebugPrint("SHOULD NEVER HAPPEN!")
            returnValue = -1
          else
            returnValue = self.modelIdToShoulderOffsetFactor[self.db.char.lastModelId]
          end

        else
          -- Otherwise do nothing!
          returnValue = -1
        end

      else
        -- print("Using", modelId)
        returnValue = self.modelIdToShoulderOffsetFactor[modelId]
      end

    end
  end

  -- print("returnValue", returnValue)
  return returnValue

end


-- For zoom levels smaller than finishDecrease, we already want a shoulder offset of 0.
-- For zoom levels greater than startDecrease, we want the user set shoulder offset.
-- For zoom levels in between, we want a gradual transition between the two above.
function cosFix:GetShoulderOffsetZoomFactor(zoomLevel)

  -- print("GetShoulderOffsetZoomFactor(" .. zoomLevel .. ")")

  if not self.db.profile.shoulderOffsetZoom then
    return 1
  end

  local startDecrease = 8
  local finishDecrease = 2

  if zoomLevel < finishDecrease then
    return 0
  elseif zoomLevel < startDecrease then
    return (zoomLevel-finishDecrease) / (startDecrease-finishDecrease)
  else
    return 1
  end
end
