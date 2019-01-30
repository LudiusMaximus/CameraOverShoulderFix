local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)



-- Returns the mount ID of the currently active mount if any.
function cosFix:GetCurrentMount()

  -- To skip the iteration through all mounts trying to find the active one,
  -- we store the last active mount to be checked first.
  -- This variable is also used when C_MountJournal.GetMountInfoByID() cannot
  -- identify the active mount even though isMounted() returns true. This
  -- happens when porting somewhere while being mounted or when in the Worgen
  -- "Running wild" state.
  if (self.db.char.lastActiveMount) then
    -- print("Last active mount: " .. self.db.char.lastActiveMount)
    local _, _, _, active = C_MountJournal.GetMountInfoByID(self.db.char.lastActiveMount)
    if (active) then
      return self.db.char.lastActiveMount
    end
  end

  -- This looks horribly ineffectice, but apparently there is no way of getting the
  -- currently active mount's id directly...
  for k,v in pairs (C_MountJournal.GetMountIDs()) do

    local _, _, _, active = C_MountJournal.GetMountInfoByID(v)

    if (active) then
      -- Store current mount as last active mount.
      self.db.char.lastActiveMount = v
      return v
    end
  end

  return nil
end






-- When the model id cannot be determined, we start a timer to call SetLastModelId() again.
-- Due to several events at the same time, it may happen that several calls happen at the same time.
-- We only want one timer running at a time.
cosFix.lastModelIdTimerId = nil

function cosFix:SetLastModelId()
  -- print("SetLastModelId()")

  local modelFrame = CreateFrame("PlayerModel")
  modelFrame:SetUnit("player")
  local modelId = modelFrame:GetModelFileID()
  -- print(modelId)
  
  if (modelId == nil) then
    if (self.lastModelIdTimerId == nil) or (self.lastModelIdTimerId and self:TimeLeft(self.lastModelIdTimerId) < 0) then
      -- print("Restarting!")
      self.lastModelIdTimerId = self:ScheduleTimer("SetLastModelId", 0.01)
    -- else
      -- print("Timer already running!")
    end
  else
    -- print("SetLastModelId determined", modelId)
    self.lastModelIdTimerId = nil
    self.db.char.lastModelId = modelId
    
    -- TODO: Set the shoulder offset again!
    
  end
end



-- Switch lastModelId of a Worgen without having to care about gender.
function cosFix:SwitchLastWorgenModelId()

  if     (self.db.char.lastModelId == self.modelId["Human"][2]) then
                             return self.modelId["Worgen"][2];   -- Human to Worgen male.
  elseif (self.db.char.lastModelId == self.modelId["Worgen"][2]) then
                             return self.modelId["Human"][2];   -- Worgen to Human male.
  elseif (self.db.char.lastModelId == self.modelId["Human"][3]) then
                             return self.modelId["Worgen"][3];   -- Human to Worgen female.
  elseif (self.db.char.lastModelId == self.modelId["Worgen"][3]) then
                             return self.modelId["Human"][3];   -- Worgen to Human female.
  else
    -- Should only happen right after logging in.
    return self.db.char.lastModelId
  end
end





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

  
  local returnValue = 1
  
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


    local _, _, _, _, _, vehicleId = strsplit("-", vehicleGuid)
    vehicleId = tonumber(vehicleId)
    -- print(vehicleId)

    -- Is the shapeshift form already in the code?
    if (self.vehicleIdToShoulderOffsetFactor[vehicleId]) then
      returnValue = self.vehicleIdToShoulderOffsetFactor[vehicleId]
    else
      local vehicleName = GetUnitName("vehicle", false)
      if (vehicleName == nil) then
        cosFix:DebugPrint("Just entering unknown vehicle with ID " .. vehicleId .. ". Zoom in or out to get message including vehicle name!")
      else
        cosFix:DebugPrint("Vehicle '" .. vehicleName .. "' (" .. vehicleId .. ") not yet known...")
      end

      -- Default for all unknown vehicles...
      returnValue = 0.5
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
        local runningWild = false
        local _, raceFile = UnitRace("player")
        if ((raceFile == "Worgen")) then
          for i = 1,40 do
            local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
            if (spellId == 87840) then
              -- print("Running wild")
              local genderCode = UnitSex("player")
              returnValue = mountedFactor * self.raceAndGenderToShoulderOffsetFactor["WorgenRunningWild"][genderCode]
              runningWild = true
            end
          end
        end
        
        if (not runningWild) then
          -- Should only happen when logging mounted with a character after purging of SavedVariables.
          if (self.db.char.lastActiveMount == nil) then
            returnValue = mountedFactor * 6
            
          -- Use the last active mount.
          else
            -- Is the mount already in the code?
            if (self.mountIdToShoulderOffsetFactor[self.db.char.lastActiveMount]) then
              returnValue = mountedFactor * self.mountIdToShoulderOffsetFactor[self.db.char.lastActiveMount]
            else
              local creatureName = C_MountJournal.GetMountInfoByID(self.db.char.lastActiveMount)
              cosFix:DebugPrint("Mount '" .. creatureName .. "' (" .. self.db.char.lastActiveMount .. ") not yet known...")
              -- Default for all other mounts...
              returnValue = mountedFactor * 6
            end
          end
        end

      -- mountId not nil
      else
        -- Is the mount already in the code?
        if (self.mountIdToShoulderOffsetFactor[mountId]) then
          returnValue = mountedFactor * self.mountIdToShoulderOffsetFactor[mountId]
        else
          local creatureName = C_MountJournal.GetMountInfoByID(mountId)
          cosFix:DebugPrint("Mount '" .. creatureName .. "' (" .. mountId .. ") not yet known...")
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
  -- Shapeshift form 30 is stealth and should be treated like normal.
  elseif ((GetShapeshiftFormID(true) ~= nil) and (GetShapeshiftFormID(true) ~= 30)) then
    -- print("You are shapeshifted.")

    local _, englishClass = UnitClass("player")
    local formId = GetShapeshiftFormID(true)

    if (englishClass == "DRUID") then

      local _, raceFile = UnitRace("player")
      if (self.druidFormIdToShoulderOffsetFactor[raceFile]) then

        local genderCode = UnitSex("player")
        if (self.druidFormIdToShoulderOffsetFactor[raceFile][genderCode]) then


          if (self.druidFormIdToShoulderOffsetFactor[raceFile][genderCode][formId]) then
            returnValue = self.druidFormIdToShoulderOffsetFactor[raceFile][genderCode][formId]
          else
            cosFix:DebugPrint(raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " druid form factor for form id " .. formId .. " not yet known...")
            returnValue = 1
          end
        else
          cosFix:DebugPrint(raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " druid form factors not yet known...")
          returnValue = 1
        end
      else
        cosFix:DebugPrint(raceFile .. " druid form factors not yet known...")
        returnValue = 1
      end
      
    elseif (formId == 16) then
      -- print("...Ghostwolf")
      returnValue = self.shamanGhostwolfToShoulderOffsetFactor[formId]
      
    else
      cosFix:DebugPrint("Shapeshift form '" .. formId .. "' not yet known...")
      
    end


  -- Is the player "normal"?
  else
    -- print("You are normal ...")

    local _, englishClass = UnitClass("player")
    local _, raceFile = UnitRace("player")
    local genderCode = UnitSex("player")
    print(englishClass, raceFile, genderCode)

    -- Check for Demon Hunter Metamorphosis.
    local metamorphosis = false
    if (englishClass == "DEMONHUNTER") then
      for i = 1,40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        -- print(name, spellId)
        if (spellId == 162264) then
          -- print("Demon Hunter Metamorphosis Havoc")
          if (self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Havoc"]) then
            returnValue = self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Havoc"]
          else
            cosFix:DebugPrint(raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " Demonhunter form factor for of 'Havoc' not yet known...")
            returnValue = 1
          end
          
          metamorphosis = true
          break
          
        elseif (spellId == 187827) then
          -- print("Demon Hunter Metamorphosis Vengeance")
          if (self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Vengeance"]) then
            returnValue = self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Vengeance"]
          else
            cosFix:DebugPrint(raceFile .. " " .. ((genderCode == 2) and "male" or "female") .. " Demonhunter form factor for of 'Vengeance' not yet known...")
            returnValue = 1
          end
          
          metamorphosis = true
          break
          
        end
      end
    end
    
    if (not metamorphosis) then
      -- Worgen need special treatment!
      if ((raceFile == "Worgen")) then

        -- Try to determine the current form.
        local modelFrame = CreateFrame("PlayerModel")
        modelFrame:SetUnit("player")
        local modelId = modelFrame:GetModelFileID()

        -- While dismounting, modelId may return nil.
        -- When this occurs we use the last known modelId and
        -- call SetLastModelId(), to be sure to get the
        -- correct Worgen form eventually.
        if (modelId == nil) then
          modelId = self.db.char.lastModelId
          self:SetLastModelId()
        else
          self.db.char.lastModelId = modelId
        end

        if ((modelId == self.modelId["Human"][2]) or (modelId == self.modelId["Human"][3])) then
          -- print("... in Human form")
          returnValue = self.raceAndGenderToShoulderOffsetFactor["Human"][genderCode]
        else
          -- print("... in Worgen form")
          returnValue = self.raceAndGenderToShoulderOffsetFactor["Worgen"][genderCode]
        end

        
        
      -- All other races are less problematic.
      else
      
        -- Try to determine the current form.
        local modelFrame = CreateFrame("PlayerModel")
        modelFrame:SetUnit("player")
        local modelId = modelFrame:GetModelFileID()
        print("modelId", modelId)
      
      
        if (modelId == nil) then
          modelId = self.db.char.lastModelId
          self:SetLastModelId()
        end
        
        

        
        -- TODO: modelId can still be nil if no lastModelId is stored.
      
      
        -- When changing back from ghostwolf into shaman you may still get the ghostwolf model id.
        -- Therefore we check if the model id is in the database and only use it then.
        if (self.modelIdToShoulderOffsetFactor[modelId]) then
          print("Using", modelId)
          self.db.char.lastModelId = modelId
          returnValue = self.modelIdToShoulderOffsetFactor[modelId]
        -- Otherwise we use the previous model id.
        elseif (self.modelIdToShoulderOffsetFactor[self.db.char.lastModelId]) then
          print("Using last", self.db.char.lastModelId)
          returnValue = self.modelIdToShoulderOffsetFactor[self.db.char.lastModelId]
          self:SetLastModelId()
        else 
          cosFix:DebugPrint("Model ID " .. modelId .. " not yet known...")
          returnValue = 1
        end
      
      
      
        -- if (self.raceAndGenderToShoulderOffsetFactor[raceFile]) then
          -- returnValue = self.raceAndGenderToShoulderOffsetFactor[raceFile][genderCode]
        -- else
          -- cosFix:DebugPrint("Race " .. raceFile .. " not yet known...")
          -- returnValue = 1
        -- end
      end
      
    end
  end

  -- print(returnValue)
  return returnValue

end


-- For zoom levels smaller than finishDecrease, we already want a shoulder offset of 0.
-- For zoom levels greater than startDecrease, we want the user set shoulder offset.
-- For zoom levels in between, we want a gradual transition between the two above.
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
