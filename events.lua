local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)



-- Use this code to copy stuff from the eventtrace window into clipboard.
-- Thanks a lot to Fizzlemizz:
-- https://www.wowinterface.com/forums/showthread.php?t=56917
local TFrame
SLASH_MYTRACE1 = "/tt"
SlashCmdList["MYTRACE"] = function(msg)
  if not EventTraceFrame then print("ETRACE NOT OPEN") return end
  if not TFrame then
    TFrame = CreateFrame("Button", "FizzleEventList", UIParent)
    TFrame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile="Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 8, insets = {left = 8, right = 8, top = 8, bottom = 8},})
    TFrame:SetBackdropColor(0, 0, 0)
    TFrame:SetPoint("RIGHT", -12)
    TFrame:SetSize(400, 400)
    TFrame.SF = CreateFrame("ScrollFrame", "$parent_DF", TFrame, "UIPanelScrollFrameTemplate")
    TFrame.SF:SetPoint("TOPLEFT", TFrame, 12, -30)
    TFrame.SF:SetPoint("BOTTOMRIGHT", TFrame, -30, 10)
    TFrame.Text = CreateFrame("EditBox", nil, TFrame)
    TFrame.Text:SetMultiLine(true)
    TFrame.Text:SetSize(180, 170)
    TFrame.Text:SetPoint("TOPLEFT", TFrame.SF)
    TFrame.Text:SetPoint("BOTTOMRIGHT", TFrame.SF)
    TFrame.Text:SetMaxLetters(99999)
    TFrame.Text:SetFontObject(GameFontNormal)
    TFrame.Text:SetAutoFocus(false)
    TFrame.Text:SetScript("OnEscapePressed", function(self)self:ClearFocus() end)
    TFrame.SF:SetScrollChild(TFrame.Text)
    TFrame.Close = CreateFrame("Button", nil, TFrame, "UIPanelButtonTemplate")
    TFrame.Close:SetSize(24, 24)
    TFrame.Close:SetPoint("TOPRIGHT", -8, -8)
    TFrame.Close:SetText("X")
    TFrame.Close:SetScript("OnClick", function(self) self:GetParent():Hide() end)
    TFrame.Clear = CreateFrame("Button", nil, TFrame, "UIPanelButtonTemplate")
    TFrame.Clear:SetSize(24, 24)
    TFrame.Clear:SetPoint("RIGHT", TFrame.Close, "LEFT", -1)
    TFrame.Clear:SetText("R")
    TFrame.Clear:SetScript("OnClick", function(self)
      local t = self:GetParent().Text
      local text = ""
      for i=1, #EventTraceFrame.events do
          text = text.."\n"..EventTraceFrame.events[i]
      end
      t:SetText("")
      t:SetText(text)
      t:ClearFocus()
    end)
    TFrame:RegisterForClicks("LeftButtonDown", "LeftButtonUp", "RightButtonUp")
    TFrame:RegisterForDrag("LeftButton")
    TFrame:SetMovable(true)
    TFrame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    TFrame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() ValidateFramePosition(self) end)
  else
    TFrame:SetShown(not TFrame:IsShown())
  end
end





-- This is needed to get the timing of changing the shoulder offset as good as possible
-- for some model changes. The Ace3 ScheduleTimer is too slow for some extreme cases.
-- http://wowwiki.wikia.com/wiki/Wait

local cosFix_waitTable = {}
local cosFix_waitFrame = nil

function cosFix_wait(delay, func, ...)
  if (type(delay) ~= "number" or type(func) ~= "function") then
    return false
  end
  if (cosFix_waitFrame == nil) then
    cosFix_waitFrame = CreateFrame("Frame", "WaitFrame", UIParent)
    cosFix_waitFrame:SetScript("onUpdate",
      function (self, elapse)
        local count = #cosFix_waitTable
        local i = 1
        while (i <= count) do
          local waitRecord = tremove(cosFix_waitTable, i)
          local d = tremove(waitRecord, 1)
          local f = tremove(waitRecord, 1)
          local p = tremove(waitRecord, 1)
          if (d > elapse) then
            tinsert(cosFix_waitTable, i, {d-elapse, f, p})
            i = i + 1
          else
            count = count - 1
            f(unpack(p))
          end
        end
      end
    )
  end
  tinsert(cosFix_waitTable, {delay, func, {...}})
  return true
end






-- TODO:   Change into cat/bear
--         Mount up
--         Change into travel form
--         --> Weird jerk

-- TODO:   Change into travel form
--         Mount or use hearthstone
--         --> Weird jerk









-- While dismounting we need to execute a shoulder offset change at the time
-- of the next UNIT_AURA event; but only then. So we use this variable as a flag.
-- We also need this for the perfect timing while changing from Ghostwolf back to Shaman.
cosFix.activateNextUnitAura = false





-- Needed for Druid shapeshift changes.
cosFix.updateShapeshiftFormCounter = 0
cosFix.waitingForUnitSpellcastSentSucceeded = false
cosFix.unitSpellcastSentObserved = false

-- Needed for changing into bear.
cosFix.activateNextHealthFrequent = false

-- Needed for changing into cat.
cosFix.activateNextActionbarUpdateCooldown = false




-- The cooldown of "Two Forms" is shorter than it actually takes to perform the transformation.
-- This flag indicates that a change into Worgen with "Two Forms" is in progress.
cosFix.changingIntoWorgen = false

-- To detect a spontaneous change into Worgen when entering combat, we need
-- to react to every execution of UNIT_MODEL_CHANGED. Every Worgen form change triggers
-- two UNIT_MODEL_CHANGED executions, the first of which has the right timing but
-- can only get modelId == nil. So we assume a form change whenever we get
-- UNIT_MODEL_CHANGED and modelId == nil.
-- However, there are certain situations in which we want to suppress the next executions of
-- UNIT_MODEL_CHANGED to do this. (E.g. when "Two Forms" is used again while the change into
-- Worgen is in progress etc.) This variable can be set to skip a certain number of upcoming
-- UNIT_MODEL_CHANGED executions.
cosFix.skipNextWorgenUnitModelChanged = 0


function cosFix:ShoulderOffsetEventHandler(event, ...)

  print("ShoulderOffsetEventHandler got event:", event, ...)

  -- If both shoulder offset adjustments are disabled, do nothing!
  if (not self.db.profile.modelIndependentShoulderOffset and not self.db.profile.shoulderOffsetZoom) then
    return
  end

  -- Got to stop shoulder offset easing that might already be in process.
  -- E.g. an easing started in ExitSituation() called at the same time as
  -- the execution of PLAYER_MOUNT_DISPLAY_CHANGED.
  -- Otherweise there is a problem, if you change directly from "mounted" to "shapeshifted".
  -- Because ExitSituation() will find the player temporarily in normal form,
  -- calculate the shoulder offset for it and start the shoulder offset ease.
  -- Then comes the UPDATE_SHAPESHIFT_FORM event triggering ShoulderOffsetEventHandler(),
  -- but its new shoulder offset value will be overridden by the ongoing easing.
  if IsAddOnLoaded("DynamicCam") then
    self:AccessStopEasingShoulderOffset()
  end


  local userSetShoulderOffset = cosFix.db.profile.cvars.test_cameraOverShoulder
  if IsAddOnLoaded("DynamicCam") then
    userSetShoulderOffset = cosFix:getUserSetShoulderOffset()
  end

  local shoulderOffsetZoomFactor = self:GetShoulderOffsetZoomFactor(GetCameraZoom())






  -- Needed for Worgen form change and Demon Hunter Metamorphosis.
  if (event == "UNIT_SPELLCAST_SUCCEEDED") then
    local unitName, _, spellId = ...

    -- Only do something if UNIT_SPELLCAST_SUCCEEDED is for "player".
    if (unitName ~= "player") then
      return
    end


    local _, raceFile = UnitRace("player")
    if ((raceFile == "Worgen")) then

      -- We only use this for chaning from Worgen into Human,
      -- because then the UNIT_MODEL_CHANGED comes a little too late.
      if (spellId == 68996) then
        -- print("Worgen form change ('Two Forms')!")

        -- The cooldown of "Two Forms" is shorter than it takes to fully change into Worgen.
        -- If you hit "Two Forms" again before completely transforming you just stay in Human form.
        if (self.changingIntoWorgen) then
          -- print("You are currently changing into worgen")

          self.changingIntoWorgen = false
          -- We need to skip the next two executions of UNIT_MODEL_CHANGED.
          self.skipNextWorgenUnitModelChanged = 2
          return
        end


        -- Derive the Worgen form you are changing into from the last known form.
        local targetWorgenFormAtSpellcast = self:SwitchLastWorgenModelId()
        if ((targetWorgenFormAtSpellcast == self.modelId["Human"][2]) or (targetWorgenFormAtSpellcast == self.modelId["Human"][3])) then
          -- print("Changing into Human.")

          -- WoW sometimes misses that you cannot use "Two Forms" while in combat.
          -- Then we get UNIT_SPELLCAST_SUCCEEDED but the model does not change.
          -- So we have to catch this here ourselves.
          if (InCombatLockdown()) then
            return
          end

          -- While changing from Worgen into Human, the next UNIT_MODEL_CHANGED event
          -- comes a little too late for a smooth shoulder offset change and there
          -- are no events in between. This is why we have to use cosFix_wait here.

          -- Set lastWorgenModelId to Human.
          self.db.char.lastWorgenModelId = targetWorgenFormAtSpellcast

          -- Remember that we are currently chaning into Human in order to suppress
          -- a shoulder offset change by the next UNIT_MODEL_CHANGED.
          self.skipNextWorgenUnitModelChanged = 1

          -- As we are circumventing CorrectShoulderOffset(), we have to check the setting here!
          local factor = 1
          if (self.db.profile.modelIndependentShoulderOffset) then
            local genderCode = UnitSex("player")
            factor = self.raceAndGenderToShoulderOffsetFactor["Human"][genderCode]
          end

          local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * factor
          return cosFix_wait(0.06, CosFix_OriginalSetCVar, "test_cameraOverShoulder", correctedShoulderOffset)

        else
          -- print("Changing into Worgen.")

          -- The shoulder offset change will be performed by UNIT_MODEL_CHANGED.

          -- Remember only that you are currently changing into Worgen
          -- in case "Two Forms" is called again before change is complete.
          self.changingIntoWorgen = true
        end
      end
    end  -- (raceFile == "Worgen")


  -- Needed for Worgen form change.
  elseif (event == "UNIT_MODEL_CHANGED") then

    -- Only do something if UNIT_MODEL_CHANGED is for "player".
    local unitName = ...
    if (unitName ~= "player") then
      return
    end


    local _, raceFile = UnitRace("player")
    if ((raceFile == "Worgen")) then

      -- When logging in, there is also a call of UNIT_MODEL_CHANGED.
      -- But when we are mounted, we do not want this to have any effect
      -- on the shoulder offset.
      if (IsMounted()) then
        return
      end

      -- When changing Worgen form, there are always two UNIT_MODEL_CHANGED calls.
      -- The first has (almost) the right timing to change the camera shoulder offset while
      -- turing into Worgen. For turning into Human, we need our own cosFix_wait timer
      -- started by UNIT_SPELLCAST_SUCCEEDED of "Two Forms".
      -- Thus, when turning into Human, we completely suppress the first
      -- call of UNIT_MODEL_CHANGED. (When using "Two Forms" while chaning into Worgen
      -- we even have to skip the next two calls of UNIT_MODEL_CHANGED.)
      if (self.skipNextWorgenUnitModelChanged > 0) then
        -- print("Suppressing UNIT_MODEL_CHANGED because of skipNextWorgenUnitModelChanged ==", self.skipNextWorgenUnitModelChanged)
        self.skipNextWorgenUnitModelChanged = self.skipNextWorgenUnitModelChanged - 1
        return
      end


      -- Try to determine the current form.
      local modelFrame = CreateFrame("PlayerModel")
      modelFrame:SetUnit("player")
      local modelId = modelFrame:GetModelFileID()

      -- print("UNIT_MODEL_CHANGED thinks you are", modelId, "while lastWorgenModelId is", self.db.char.lastWorgenModelId)

      if (modelId == nil) then
        -- print("Using the opposite of lastWorgenModelId.")
        modelId = self:SwitchLastWorgenModelId()

        -- This will eventually set the right model ID.
        self:SetLastWorgenModelId()
      end

      -- print("Assuming you turn into", modelId)


      if ((modelId == self.modelId["Worgen"][2]) or (modelId == self.modelId["Worgen"][3])) then
        -- print("UNIT_MODEL_CHANGED -> Worgen")

        -- Remember that the change into Worgen is complete.
        self.changingIntoWorgen = false

        -- As we are circumventing CorrectShoulderOffset(), we have to check the setting here!
        local factor = 1
        if (self.db.profile.modelIndependentShoulderOffset) then
          local genderCode = UnitSex("player")
          factor = self.raceAndGenderToShoulderOffsetFactor["Worgen"][genderCode]
        end

        local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * factor
        -- TODO: In fact this is still a little bit too late! But if we want to set it earlier, we would have
        -- to capture every event that will force change from worgen into human... Is it possible?
        return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)

      else
        -- This should never happen except directly after logging in.
        -- print("UNIT_MODEL_CHANGED -> Human")

        -- As we are circumventing CorrectShoulderOffset(), we have to check the setting here!
        local factor = 1
        if (self.db.profile.modelIndependentShoulderOffset) then
          local genderCode = UnitSex("player")
          factor = self.raceAndGenderToShoulderOffsetFactor["Human"][genderCode]
        end

        local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * factor
        return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)
      end

    end  -- (raceFile == "Worgen")

    -- print("... doing nothing!")


  -- To suppress Worgen UNIT_MODEL_CHANGED after loading screen.
  -- After the loading screen (not after logging in though), we get three
  -- UNIT_MODEL_CHANGED events, that would determine the wrong worgen model.
  -- These are suppresed here.
  elseif (event == "LOADING_SCREEN_DISABLED") then
    local _, raceFile = UnitRace("player")
    if ((raceFile == "Worgen")) then
      self.skipNextWorgenUnitModelChanged = 3
    end


  -- Needed for shapeshifting.
  elseif (event == "UPDATE_SHAPESHIFT_FORM") then

    local _, englishClass = UnitClass("player")
    if (englishClass == "SHAMAN") then

      if (GetShapeshiftFormID(true) ~= nil) then
        -- print("You are turning into Ghostwolf (" .. GetShapeshiftFormID(true) .. ").")

        -- -- The UPDATE_SHAPESHIFT_FORM while turning into Ghostwolf comes too early.
        -- -- And also the subsequent UNIT_MODEL_CHANGED is still too early.
        -- -- That is why we have to use the cosFix_wait timer instead.
        local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
        return cosFix_wait(0.01, CosFix_OriginalSetCVar, "test_cameraOverShoulder", correctedShoulderOffset)

      else
        -- print("You are turning into normal Shaman!")

        -- Do not change the shoulder offset here.
        -- Wait until the next UNIT_AURA for perfect timing.
        self.activateNextUnitAura = true

        -- TODO: Very rarely there are *two* UPDATE_SHAPESHIFT_FORM events while turning back into normal.
        -- If this happens, the second event is probably the one that should start a timer to update
        -- the shoulder offset, because then the next UNIT_AURA is too early. To fix this for good we
        -- would need a possibility to start timers like cosFix_wait and stop currently queued timers
        -- that have not been executed yet (cosFix_waitTable = {};).
        -- Then UPDATE_SHAPESHIFT_FORM could always stop the currently queued
        -- timers and start a new one.
        return
      end


    elseif (englishClass == "DRUID") then

      local _, raceFile = UnitRace("player")
      if ((raceFile == "Worgen")) then
        self.skipNextWorgenUnitModelChanged = 1
      end


      local formId = GetShapeshiftFormID(true)
      if (formId ~= nil) then
        print("You are turning into something (" .. formId .. ").")

        -- Worgen druids automatically turn into Worgen form when turning into a druid form.
        self.db.char.lastWorgenModelId = self.modelId["Worgen"][UnitSex("player")]

        -- When turning into shapeshift, two UPDATE_SHAPESHIFT_FORM
        -- are executed, the first of which still gets formId == nil (if normal) or the previous formId (if shapeshifted).
        -- For the former we set updateShapeshiftFormCounter back to 0.
        -- For the latter we have to stop the timer.
        self.updateShapeshiftFormCounter = 0
        cosFix_waitTable = {}

        -- Remember the current formId, because we have to use different timings
        -- when turning back into normal depending on the current shapeshift form.
        self.db.char.lastformId = formId

        -- This is needed to register when we are changing from one druid form
        -- into travel form. Because then we have to
        self.waitingForUnitSpellcastSentSucceeded = false
        self.unitSpellcastSentObserved = false


        if (formId == 1) then
          -- print("cat")
          self.activateNextUnitAura = false
          self.activateNextHealthFrequent = false
          self.activateNextActionbarUpdateCooldown = true
          return

        elseif (formId == 5) then
          -- print("bear")
          self.activateNextUnitAura = false
          self.activateNextHealthFrequent = true
          self.activateNextActionbarUpdateCooldown = false
          return

        else
          -- print("travel or tree of light...")
          self.activateNextUnitAura = false
          self.activateNextHealthFrequent = false
          self.activateNextActionbarUpdateCooldown = false
          local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
          return cosFix_wait(0.018, CosFix_OriginalSetCVar, "test_cameraOverShoulder", correctedShoulderOffset)

        end

      else
        print("You are turning into normal Druid!")


        if ((self.db.char.lastformId == 3) or (self.db.char.lastformId == 27) or (self.db.char.lastformId == 29)) then

          -- When turning from travel form into normal druid, there is always a first
          -- UPDATE_SHAPESHIFT_FORM where still the shapeshifted form is detected.
          -- This will start a timer, which we have to revoke here.
          cosFix_waitTable = {}

          self.db.char.lastformId = nil
        end


        -- When turning from a non-travel form back into normal, we have to use the next
        -- UPDATE_SHAPESHIFT_FORM events, because for some reason the shoulder offset change
        -- occurs sometimes sooner, sometimes later after the first UPDATE_SHAPESHIFT_FORM.
        if (self.db.char.lastformId ~= nil) then
          self.db.char.lastformId = nil
          self.updateShapeshiftFormCounter = 1
          print("Setting counter to", self.updateShapeshiftFormCounter)

          self.waitingForUnitSpellcastSentSucceeded = true
        else
          if (self.updateShapeshiftFormCounter == 0) then

            if (self.unitSpellcastSentObserved == false) then
              print("Reached updateShapeshiftFormCounter ==", self.updateShapeshiftFormCounter)
              local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
              return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)
            else
              print("Doing nothing because you are changing from a non-travel form into travel form.")
              self.unitSpellcastSentObserved = false
              return
            end

          else
            self.updateShapeshiftFormCounter = self.updateShapeshiftFormCounter - 1
            print("Decreasing updateShapeshiftFormCounter to", self.updateShapeshiftFormCounter)
            return
          end
        end

      end
    end -- (englishClass == "DRUID")

    -- print("... doing nothing!")






  -- Needed for changing into bear.
  elseif (event == "UNIT_HEALTH_FREQUENT") then
    if (self.activateNextHealthFrequent == true) then
      self.activateNextUnitAura = false
      self.activateNextHealthFrequent = false
      self.activateNextActionbarUpdateCooldown = false

      local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
      return cosFix_wait(0.05, CosFix_OriginalSetCVar, "test_cameraOverShoulder", correctedShoulderOffset)
    end


  -- Needed for changing into cat.
  elseif (event == "ACTIONBAR_UPDATE_COOLDOWN") then
    if (self.activateNextActionbarUpdateCooldown == true) then
      self.activateNextUnitAura = false
      self.activateNextHealthFrequent = false
      self.activateNextActionbarUpdateCooldown = false

      local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
      return cosFix_wait(0.05, CosFix_OriginalSetCVar, "test_cameraOverShoulder", correctedShoulderOffset)
    end


  -- Needed for Druid shapeshift changes.
  elseif (event == "UNIT_SPELLCAST_SENT") then
    local unitName, _, _, spellId = ...

    -- Only do something if UNIT_SPELLCAST_SENT is for "player".
    if (unitName ~= "player") then
      return
    end

    -- Trying to determine if we are currently changing from
    -- one druid shapeshift form into travel form.
    if ((self.waitingForUnitSpellcastSentSucceeded == true) and (spellId == 783)) then
      self.waitingForUnitSpellcastSentSucceeded = false
      self.unitSpellcastSentObserved = true
    end








  -- Needed for mounting and entering taxis.
  elseif (event == "PLAYER_MOUNT_DISPLAY_CHANGED") then
    if (IsMounted() == false) then

      -- print("PLAYER_MOUNT_DISPLAY_CHANGED: IsMounted() == false")

      local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)

      -- Sometimes there is no SPELL_UPDATE_USABLE after leaving a taxi.
      -- We can then set the value unmounted immedeately.
      if (self.db.char.isOnTaxi) then
        self.db.char.isOnTaxi = false
        return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)
      end
      -- The same goes for being dismounted automatically while entering indoors.
      if (IsIndoors()) then
        return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)
      end
      -- The same goes for being diesmounted in certain outdoor areas
      -- (e.g. certain quest givers like Great-father Winter).
      -- This can be checked by trying if the last active mount is usable.
      -- Interestingly this does not work for entering indoors, so we still need the check above.
      local _, _, _, _, lastActiveMountUsable = C_MountJournal.GetMountInfoByID(self.db.char.lastActiveMount)
      if (not lastActiveMountUsable) then
        return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)
      end


      -- Change the shoulder offset once here and then again with the next SPELL_UPDATE_USABLE.
      self.activateNextUnitAura = true

      -- When shoulder offset is greater than 0, we need to set it to 10 times its actual value
      -- for the time between this PLAYER_MOUNT_DISPLAY_CHANGED and the next SPELL_UPDATE_USABLE.
      -- But only if modelIndependentShoulderOffset is enabled.
      if (self.db.profile.modelIndependentShoulderOffset and (correctedShoulderOffset > 0)) then
        correctedShoulderOffset = correctedShoulderOffset * 10
      end

      return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)
    else
      -- print("PLAYER_MOUNT_DISPLAY_CHANGED: IsMounted() == true")
      local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
      return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)
    end


  -- Needed to determine the right time to change shoulder offset when dismounting,
  -- changing from Shaman Ghostwolf into normal, from shapeshifted Druid into normal,
  -- and for Demon Hunter Metamorphosis.
  elseif (event == "UNIT_AURA") then

    -- Only do something if UNIT_AURA is for "player".
    local unitName = ...
    if (unitName ~= "player") then
      return
    end

    -- This is flag is set while dismounting and while changing from Ghostwolf into Shaman.
    if (self.activateNextUnitAura == true) then
      self.activateNextUnitAura = false
      self.activateNextHealthFrequent = false
      self.activateNextActionbarUpdateCooldown = false

      -- print("UNIT_AURA executing!")
      local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
      return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)
    end



    -- We are also using UNIT_AURA to get the right timing for Demon Hunter Metamorphosis.
    -- Demon hunter always has to check for Metamorphosis.
    -- TODO: Mounting and dismounting while in Metamorphosis would have to be taken care of specifically.
    local _, englishClass = UnitClass("player")
    if (englishClass == "DEMONHUNTER") then

      -- Turning into Metamorphosis.
      for i = 1,40 do
        local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
        -- print(name, spellId)
        if (spellId == 162264) then
          -- print("UNIT_AURA for METAMORPHOSIS HAVOC")
          local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
          return cosFix_wait(0.69, CosFix_OriginalSetCVar, "test_cameraOverShoulder", correctedShoulderOffset)
        elseif (spellId == 187827) then
          -- print("UNIT_AURA for METAMORPHOSIS VENGEANCE")
          local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
          return cosFix_wait(0.966, CosFix_OriginalSetCVar, "test_cameraOverShoulder", correctedShoulderOffset)
        end
      end

      -- Turning into normal Demon Hunter.
      local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
      -- print("UNIT_AURA for DEMON HUNTER back to normal")
      return cosFix_wait(0.082, CosFix_OriginalSetCVar, "test_cameraOverShoulder", correctedShoulderOffset)

    end  -- (englishClass == "DEMONHUNTER")


    -- print("... doing nothing!")


  -- Needed for vehicles.
  elseif (event == "UNIT_ENTERING_VEHICLE") then
    local unitName, _, _, _, vehicleGuid = ...
    -- print(unitName)
    -- print(vehicleGuid)

    -- Only do something if UNIT_ENTERING_VEHICLE is for "player".
    if (unitName ~= "player") then
      return
    end

    local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset, vehicleGuid)
    return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)

  -- Needed for vehicles.
  elseif (event == "UNIT_EXITING_VEHICLE") then
    local unitName = ...

    -- Only do something if UNIT_EXITING_VEHICLE is for "player".
    if (unitName ~= "player") then
      return
    end

    local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
    return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)



  -- Needed for being teleported into a dungeon while mounted,
  -- because when entering you get automatically dismounted
  -- without PLAYER_MOUNT_DISPLAY_CHANGED being executed.
  elseif (event == "PLAYER_ENTERING_WORLD") then
    local correctedShoulderOffset = userSetShoulderOffset * shoulderOffsetZoomFactor * self:CorrectShoulderOffset(userSetShoulderOffset)
    return CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)
  end

end


function cosFix:RegisterEvents()


  -- Needed for Worgen form change.
  self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", "ShoulderOffsetEventHandler")

  -- Needed for Worgen form change.
  self:RegisterEvent("UNIT_MODEL_CHANGED", "ShoulderOffsetEventHandler")

  -- To suppress Worgen UNIT_MODEL_CHANGED after loading screen.
  self:RegisterEvent("LOADING_SCREEN_DISABLED", "ShoulderOffsetEventHandler")



  -- Needed for shapeshifting.
  self:RegisterEvent("UPDATE_SHAPESHIFT_FORM", "ShoulderOffsetEventHandler")



  -- Needed for changing into bear.
  self:RegisterEvent("UNIT_HEALTH_FREQUENT", "ShoulderOffsetEventHandler")

  -- Needed for changing into cat.
  self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", "ShoulderOffsetEventHandler")

  -- Needed to know if you change from a non-travel form into travel form.
  self:RegisterEvent("UNIT_SPELLCAST_SENT", "ShoulderOffsetEventHandler")




  -- Needed for mounting and entering taxis.
  self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", "ShoulderOffsetEventHandler")

  -- Needed to determine the right time to change shoulder offset when dismounting,
  -- changing from Shaman Ghostwolf into normal and for Demon Hunter Metamorphosis.
  self:RegisterEvent("UNIT_AURA", "ShoulderOffsetEventHandler")

  -- Needed for vehicles.
  self:RegisterEvent("UNIT_ENTERING_VEHICLE", "ShoulderOffsetEventHandler")
  self:RegisterEvent("UNIT_EXITING_VEHICLE", "ShoulderOffsetEventHandler")

  -- Needed for being teleported into a dungeon while mounted,
  -- because when entering you get automatically dismounted
  -- without PLAYER_MOUNT_DISPLAY_CHANGED being executed.
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "ShoulderOffsetEventHandler")

end

