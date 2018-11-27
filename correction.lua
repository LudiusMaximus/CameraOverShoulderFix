local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)




-- To skip the iteration through all mounts trying to find the active one,
-- we store the last active mount to be checked first.
-- This variable is also used when C_MountJournal.GetMountInfoByID() cannot
-- identify the active mount even though isMounted() returns true. This
-- happens when porting somewhere while being mounted or when in the Worgen
-- "Running wild" state.
cosFix.lastActiveMount = nil

-- Returns the mount ID of the currently active mount if any.
function cosFix:GetCurrentMount()

  -- First check if the last active mount is still active.
  -- This will save us the effort of iterating through the whole mount journal.
  if (self.lastActiveMount) then
    -- print("Last active mount: " .. self.lastActiveMount)
    local _, _, _, active = C_MountJournal.GetMountInfoByID(self.lastActiveMount)
    if (active) then
      return self.lastActiveMount
    end
  end

  -- This looks horribly ineffectice, but apparently there is no way of getting the
  -- currently active mount's id directly...
  for k,v in pairs (C_MountJournal.GetMountIDs()) do

    local _, _, _, active = C_MountJournal.GetMountInfoByID(v)

    if (active) then
      -- Store current mount as last active mount.
      self.lastActiveMount = v
      return v
    end
  end

  return nil
end






-- When the model id cannot be determined, we start a timer to call SetLastWorgenModelId() again.
-- Due to several events at the same time, it may happen that several calls happen at the same time.
-- We only want one timer running at a time.
cosFix.lastWorgenModelIdTimerId = nil

-- We call this in the end of UNIT_MODEL_CHANGED to be safe against "hiccups",
-- that my leave lastWorgenModelId at the wrong value.
function cosFix:SetLastWorgenModelId()
  -- print("SetLastWorgenModelId()")

  local modelFrame = CreateFrame("PlayerModel")
  modelFrame:SetUnit("player")
  local modelId = modelFrame:GetModelFileID()
  -- print(modelId)
  
  if (modelId == nil) then
    if (self.lastWorgenModelIdTimerId == nil) or (self.lastWorgenModelIdTimerId and self:TimeLeft(self.lastWorgenModelIdTimerId) < 0) then
      -- print("Restarting!")
      self.lastWorgenModelIdTimerId = self:ScheduleTimer("SetLastWorgenModelId", 0.01)
    -- else
      -- print("Timer already running!")
    end
  else
    -- print("SetLastWorgenModelId determined", modelId)
    self.lastWorgenModelIdTimerId = nil
    self.db.char.lastWorgenModelId = modelId
  end
end

-- Switch lastWorgenModelId without having to care about gender.
function cosFix:SwitchLastWorgenModelId()

  if     (self.db.char.lastWorgenModelId == self.modelId["Human"][2]) then
                             return self.modelId["Worgen"][2];   -- Human to Worgen male.
  elseif (self.db.char.lastWorgenModelId == self.modelId["Worgen"][2]) then
                             return self.modelId["Human"][2];   -- Worgen to Human male.
  elseif (self.db.char.lastWorgenModelId == self.modelId["Human"][3]) then
                             return self.modelId["Worgen"][3];   -- Human to Worgen female.
  elseif (self.db.char.lastWorgenModelId == self.modelId["Worgen"][3]) then
                             return self.modelId["Human"][3];   -- Worgen to Human female.
  else
    -- Should only happen right after logging in.
    return self.db.char.lastWorgenModelId
  end
end




-- Flag to remember that you are on a taxi, because the shoulder offset change while
-- leaving a taxi (PLAYER_MOUNT_DISPLAY_CHANGED) needs special treatment...
cosFix.isOnTaxi = false


-- WoW interprets the test_cameraOverShoulder variable differently depending on the current player model.
-- If we want the camera to always have the same shoulder offset relative to the player's center,
-- we need to adjust the test_cameraOverShoulder value depending on the current player model.
-- Arguments:
--   offset                   The original shoulder offset value that should be adjusted.
--                            Is only required to determine the mountedFactor or to stop the function if not needed.
--   enteringVehicleGuid      (optional) When CorrectShoulderOffset is called while entering a vehicle
--                            we pass the vehicle's GUID to determine the test_cameraOverShoulder adjustment.
--                            This is necessary because while entering the vehicle, UnitInVehicle("player") will
--                            still return 'false' while the camera is already regarding the vehicle's model.
function cosFix:CorrectShoulderOffset(offset, enteringVehicleGuid)

  -- print("CorrectShoulderOffset", offset)

  -- If the "Correct Shoulder Offset" function is deactivated, we do not correct the offset.
  if (not self.db.profile.modelIndependentShoulderOffset) then
    return 1
  end

  -- If no offset is set, there is no need to correct it.
  if (offset == 0) then
    return 1
  end

  -- Is the player entering a vehicle or already in a vehicle?
  if (enteringVehicleGuid or UnitInVehicle("player")) then
    -- print("You are entering or on a vehicle.")

    local vehicleGuid = ""
    if (enteringVehicleGuid) then
      vehicleGuid = enteringVehicleGuid
      -- print("Entering vehicle.")
    else
      vehicleGuid = UnitGUID("vehicle")
      -- print("Already in vehicle.")
    end

    -- TODO: Could also be "Player-...." if you mount a player in druid travel form.
    -- TODO: Or what if you mount another player's "double-seater" mount?
    -- print(vehicleGuid)


    local _, _, _, _, _, vehicleId = strsplit("-", vehicleGuid)
    vehicleId = tonumber(vehicleId)
    -- print(vehicleId)

    -- Is the shapeshift form already in the code?
    if (self.vehicleIdToShoulderOffsetFactor[vehicleId]) then
      return self.vehicleIdToShoulderOffsetFactor[vehicleId]
    else
      local vehicleName = GetUnitName("vehicle", false)
      if (vehicleName == nil) then
        cosFix:DebugPrint("... TODO: Just entering unknown vehicle with ID " .. vehicleId .. ". Zoom in or out to get message including vehicle name!")
      else
        cosFix:DebugPrint("... TODO: Vehicle '" .. vehicleName .. "' (" .. vehicleId .. ") not yet known...")
      end

      -- Default for all unknown vehicles...
      return 0.5
    end


  -- Is the player mounted?
  elseif (IsMounted()) then
    -- print("You are mounted.")

    -- No idea why this is necessary when mounted; seems to be a persistent bug on Blizzard's side!
    local mountedFactor = 1
    if (offset < 0) then
      mountedFactor = mountedFactor / 10
    end

    -- Is the player really mounted and not on a "taxi"?
    if (not UnitOnTaxi("player")) then

      local mountId = self:GetCurrentMount()

      -- Right after logging in while on a mount it happens that "IsMounted()" returns true,
      -- but C_MountJournal.GetMountInfoByID() is not yet able to determine that the mount is active.
      -- Furthermore, when in Worgen "Running wild" state, you get isMounted() without a mount.
      if (mountId == nil) then
        -- print("Mounted but no mount")

        -- Check for Worgen "Running Wild" state.
        local _, raceFile = UnitRace("player")
        if ((raceFile == "Worgen")) then
          for i = 1,40 do
            local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
            if (spellId == 87840) then
              -- print("Running wild")
              local genderCode = UnitSex("player")
              return mountedFactor * self.raceAndGenderToShoulderOffsetFactor["WorgenRunningWild"][genderCode]
            end
          end
        end


        -- Happens when mounted while logging in.
        if (self.lastActiveMount == nil) then
          -- TODO: If you want to make it better, remember the last mount for each character
          -- in the add-on database...
          return mountedFactor * 6
        -- Use the last active mount.
        else
          -- Is the mount already in the code?
          if (self.mountIdToShoulderOffsetFactor[self.lastActiveMount]) then
            return mountedFactor * self.mountIdToShoulderOffsetFactor[self.lastActiveMount]
          else
            local creatureName = C_MountJournal.GetMountInfoByID(self.lastActiveMount)
            cosFix:DebugPrint("... TODO: Mount '" .. creatureName .. "' (" .. self.lastActiveMount .. ") not yet known...")
            -- Default for all other mounts...
            return mountedFactor * 6
          end
        end

      -- mountId not nil
      else
        -- Is the mount already in the code?
        if (self.mountIdToShoulderOffsetFactor[mountId]) then
          return mountedFactor * self.mountIdToShoulderOffsetFactor[mountId]
        else
          local creatureName = C_MountJournal.GetMountInfoByID(mountId)
          cosFix:DebugPrint("... TODO: Mount '" .. creatureName .. "' (" .. mountId .. ") not yet known...")
          -- Default for all other mounts...
          return mountedFactor * 6
        end
      end

    else
      -- print("You are on a taxi!")

      -- Remember that you are on a taxi, because the shoulder offset change while
      -- leaving a taxi (PLAYER_MOUNT_DISPLAY_CHANGED) needs special treatment...
      cosFix.isOnTaxi = true

      -- Works all right for Wind Riders.
      -- TODO: This should probably also be done individually for all taxi models in the game.
      return mountedFactor * 2.5
    end



  -- Is the player shapeshifted?
  elseif (GetShapeshiftFormID(true) ~= nil) then
    -- print("You are shapeshifted.")

    local _, englishClass = UnitClass("player")
    local formId = GetShapeshiftFormID(true)

    if (englishClass == "DRUID") then

      local _, raceFile = UnitRace("player")
      if (self.druidFormIdToShoulderOffsetFactor[raceFile]) then

        local genderCode = UnitSex("player")
        if (self.druidFormIdToShoulderOffsetFactor[raceFile][genderCode]) then


          if (self.druidFormIdToShoulderOffsetFactor[raceFile][genderCode][formId]) then
            return self.druidFormIdToShoulderOffsetFactor[raceFile][genderCode][formId]
          else
            cosFix:DebugPrint("... TODO: " .. raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " druid form factor for form id " .. formId .. " not yet known...")
            return 1
          end
        else
          cosFix:DebugPrint("... TODO: " .. raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " druid form factors not yet known...")
          return 1
        end
      else
        cosFix:DebugPrint("... TODO: " .. raceFile .. " druid form factors not yet known...")
        return 1
      end
    else
      return self.shamanGhostwolfToShoulderOffsetFactor[formId]
    end


  -- Is the player "normal"?
  else
    -- print("You are normal ...")

    local _, englishClass = UnitClass("player")
    local _, raceFile = UnitRace("player")
    local genderCode = UnitSex("player")
    -- print(englishClass, raceFile, genderCode)

    -- Check for Demon Hunter Metamorphosis.
    if (englishClass == "DEMONHUNTER") then
        for i = 1,40 do
            local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
            -- print(name, spellId)
            if (spellId == 162264) then
                -- print("Demon Hunter Metamorphosis Havoc")
                if (self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Havoc"]) then
                    return self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Havoc"]
                else
                    cosFix:DebugPrint("... TODO: " .. raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " Demonhunter form factor for form 'Havoc' not yet known...")
                    return 1
                end
            elseif (spellId == 187827) then
                -- print("Demon Hunter Metamorphosis Vengeance")
                if (self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Vengeance"]) then
                    return self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Vengeance"]
                else
                    cosFix:DebugPrint("... TODO: " .. raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " Demonhunter form factor for form 'Vengeance' not yet known...")
                    return 1
                end
            end
        end
    end

    -- Worgen need special treatment!
    if ((raceFile == "Worgen")) then

      -- Try to determine the current form.
      local modelFrame = CreateFrame("PlayerModel")
      modelFrame:SetUnit("player")
      local modelId = modelFrame:GetModelFileID()

      -- While dismounting, modelId may return nil.
      -- When this occurs we use the last known modelId and
      -- call SetLastWorgenModelId(), to be sure to get the
      -- correct Worgen form eventually.
      if (modelId == nil) then
        modelId = self.db.char.lastWorgenModelId
        self:SetLastWorgenModelId()
      else
        self.db.char.lastWorgenModelId = modelId
      end
      -- print(modelId)

      if ((modelId == self.modelId["Human"][2]) or (modelId == self.modelId["Human"][3])) then
        -- print("... in Human form")
        return self.raceAndGenderToShoulderOffsetFactor["Human"][genderCode]
      else
        -- print("... in Worgen form")
        return self.raceAndGenderToShoulderOffsetFactor["Worgen"][genderCode]
      end

    -- All other races are less problematic.
    else
      if (self.raceAndGenderToShoulderOffsetFactor[raceFile]) then
        return self.raceAndGenderToShoulderOffsetFactor[raceFile][genderCode]
      else
        cosFix:DebugPrint("... TODO: Race " .. raceFile .. " not yet known...")
        return 1.0
      end
    end

  end


end


-- At zoom levels smaller than finishDecrease, we already want a shoulder offset of 0.
-- At zoom levels greater than startDecrease, we want the user set shoulder offset.
-- In zoom levels between we want a gradual transition.
function cosFix:GetShoulderOffsetZoomFactor(zoomLevel)

    -- print("GetShoulderOffsetZoomFactor(" .. zoomLevel .. ")")

    if (not self.db.profile.shoulderOffsetZoom) then
      return 1
    end

    local startDecrease = 8
    local finishDecrease = 2

    if (zoomLevel < finishDecrease) then
        return 0
    elseif (zoomLevel < startDecrease) then
        return (zoomLevel-finishDecrease) / (startDecrease-finishDecrease)
    else
        return 1
    end
end
