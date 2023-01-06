local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)


local _G = _G
local type = _G.type
local tremove = _G.tremove
local tinsert = _G.tinsert
local unpack = _G.unpack

local C_MountJournal_GetMountInfoByID = _G.C_MountJournal.GetMountInfoByID
local GetShapeshiftFormID = _G.GetShapeshiftFormID
local InCombatLockdown = _G.InCombatLockdown
local IsIndoors = _G.IsIndoors
local IsMounted = _G.IsMounted
local UnitBuff = _G.UnitBuff
local UnitClass = _G.UnitClass
local UnitRace = _G.UnitRace
local UnitSex = _G.UnitSex


local dynamicCamLoaded = IsAddOnLoaded("DynamicCam")
local DynamicCam = _G.DynamicCam

-- Use this code to copy stuff from the eventtrace window into clipboard.
-- Thanks a lot to Fizzlemizz:
-- https://www.wowinterface.com/forums/showthread.php?t=56917

local TFrame
SLASH_MYTRACE1 = "/tt"
SlashCmdList["MYTRACE"] = function(msg)
  if not TFrame then
    TFrame = CreateFrame("Button", "FizzleEventList", UIParent, BackdropTemplateMixin and "BackdropTemplate")
    TFrame:SetBackdrop({bgFile = "Interface/Tooltips/UI-Tooltip-Background", edgeFile="Interface/Tooltips/UI-Tooltip-Border", tile = true, tileSize = 8, insets = {left = 8, right = 8, top = 8, bottom = 8},})
    TFrame:SetBackdropColor(0, 0, 0)
    TFrame:SetPoint("CENTER", 0)
    TFrame:SetSize(400, 400)

    TFrame.SF = CreateFrame("ScrollFrame", "$parent_DF", TFrame, "UIPanelScrollFrameTemplate")
    TFrame.SF:SetPoint("TOPLEFT", TFrame, 12, -30)
    TFrame.SF:SetPoint("BOTTOMRIGHT", TFrame, -30, 10)

    TFrame.Text = CreateFrame("EditBox", nil, TFrame)
    TFrame.Text:SetMultiLine(true)
    TFrame.Text:SetSize(180, 170)
    TFrame.Text:SetPoint("TOPLEFT", TFrame.SF)
    TFrame.Text:SetPoint("BOTTOMRIGHT", TFrame.SF)
    TFrame.Text:SetMaxLetters(999999)
    TFrame.Text:SetFontObject(GameFontNormal)
    TFrame.Text:SetAutoFocus(false)
    TFrame.Text:SetScript("OnEscapePressed", function(self)self:ClearFocus() end)
    TFrame.SF:SetScrollChild(TFrame.Text)

    TFrame.Close = CreateFrame("Button", nil, TFrame, "UIPanelButtonTemplate")
    TFrame.Close:SetSize(24, 24)
    TFrame.Close:SetPoint("TOPRIGHT", -8, -8)
    TFrame.Close:SetText("X")
    TFrame.Close:SetScript("OnClick", function(self) self:GetParent():Hide() end)

    TFrame.CopyET = CreateFrame("Button", nil, TFrame, "UIPanelButtonTemplate")
    TFrame.CopyET:SetSize(24, 24)
    TFrame.CopyET:SetPoint("RIGHT", TFrame.Close, "LEFT", -1)
    TFrame.CopyET:SetText("E")
    TFrame.CopyET:SetScript("OnClick", function(self)
      if not EventTraceFrame then print("ETRACE NOT OPEN") return end
      local t = self:GetParent().Text
      local text = ""
      for i=1, #EventTraceFrame.events do
          if EventTraceFrame.events[i] then
            text = text .. "\n" .. EventTraceFrame.events[i]
          else
            text = text .. "\n----> Could not read event! <----"
          end
      end
      t:SetText("")
      t:SetText(text)
      t:ClearFocus()
    end)

    TFrame.CopyCF = CreateFrame("Button", nil, TFrame, "UIPanelButtonTemplate")
    TFrame.CopyCF:SetSize(24, 24)
    TFrame.CopyCF:SetPoint("RIGHT", TFrame.CopyET, "LEFT", -1)
    TFrame.CopyCF:SetText("C")
    TFrame.CopyCF:SetScript("OnClick", function(self)
      local t = self:GetParent().Text
      local text = ""
      for i=1, _G['ChatFrame1']:GetNumMessages() do
          if _G['ChatFrame1']:GetMessageInfo(i) then
            text = text .. "\n" .. _G['ChatFrame1']:GetMessageInfo(i)
          else
            text = text .. "\n----> Could not read event! <----"
          end
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
-- for some model change events. The Ace3 ScheduleTimer is too slow for some extreme cases.
-- http://wowwiki.wikia.com/wiki/Wait

local cosFix_waitTable = {}
local cosFix_waitFrame = nil

function cosFix_wait(delay, func, ...)
  if (type(delay) ~= "number") or (type(func) ~= "function") then
    return false
  end
  if cosFix_waitFrame == nil then
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





-- While dismounting we need to execute a shoulder offset change at the time
-- of the next UNIT_AURA event; but only then. So we use this variable as a flag.
-- We also need this for the perfect timing while changing from Ghostwolf back to Shaman.
cosFix.activateNextUnitAura = false


-- Sometimes when dismounting automatically (e.g. because of mining or herbgathering)
-- the PLAYER_MOUNT_DISPLAY_CHANGED event comes after the UNIT_AURA, so we cannot
-- do our standard procedure. To recognise these cases, we wait for UNIT_AURA
-- after each UNIT_SPELLCAST_SENT. If we see it before PLAYER_MOUNT_DISPLAY_CHANGED,
-- we know that this special case has occured.
cosFix.waitingForUnitAura = false
cosFix.unitAuraBeforeMountDisplayChanged = false


-- Needed for Druid shapeshift changes.
cosFix.updateShapeshiftFormCounter = 0

-- Needed to register when we are changing from another druid form into travel form.
-- Because this always triggers an event that looks like your are changing into
-- normal druid, while you must not change the shoulder offset at this point.
cosFix.waitingForUnitSpellcastSentSucceeded = false
cosFix.changingIntoTravelForm = false

-- Needed for changing into bear form.
cosFix.activateNextHealthFrequent = false



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



-- For Demon Hunter Metamorphosis.
cosFix.timeOfLastSpellsChanged = 0


-- 0 normal, 1 havoc, 2 vengeance
local function GetDemonHunterForm()

  local returnValue = 0

  for i = 1,40 do
    local name, _, _, _, _, _, _, _, _, spellId = UnitBuff("player", i)
    -- print(name, spellId)
    if spellId == 162264 then
      returnValue = 1
      break
    elseif spellId == 187827 then
      returnValue = 2
      break
    end
  end

  return returnValue
end


-- This function is needed to set a delayed update in the future,
-- for which we do yet not know the currentShoulderOffset value.
function cosFix:SetShoulderOffset()
  SetCVar("test_cameraOverShoulder", self:GetCurrentShoulderOffset() * self:GetShoulderOffsetZoomFactor(GetCameraZoom()) * self.currentModelFactor)
end


-- Determine and set a the shoulder offset with or without a delay.
-- The last argument (modelFactor) is optional and can be set
-- if a specific modelFactor should be enforced.
function cosFix:SetDelayedShoulderOffset(delay, modelFactor)
  -- print("SetDelayedShoulderOffset", delay, modelFactor)

  if not delay then delay = 0 end

  if not modelFactor then
    modelFactor = self:CorrectShoulderOffset()
    -- If CorrectShoulderOffset cannot find a valid offset, it returns -1.
    -- In this case we do not change the shoulder offset at all
    -- instead of just using a global default value, hoping to avoid camera jerks.
    if modelFactor == -1 then
      return
    end
  end


  -- Do something immedeately!
  if delay == 0 then

    self.currentModelFactor = modelFactor
    return self:SetShoulderOffset()

  -- Wait for delay until doing something.
  -- This will also work while easing is in progress because the easing functions take into account
  -- currentModelFactor and are not disturbed by an additional setting of test_cameraOverShoulder.
  else

    return cosFix_wait(
        delay,
        function()
          self.currentModelFactor = modelFactor
          self:SetShoulderOffset()
        end
      )

  end

end






function cosFix:ShoulderOffsetEventHandler(event, ...)

  -- print("##########################")
  -- print("ShoulderOffsetEventHandler got event:", event, ...)


  -- Needed for Worgen form change..
  if event == "UNIT_SPELLCAST_SUCCEEDED" then
    local unitName, _, spellId = ...

    -- Only do something if UNIT_SPELLCAST_SUCCEEDED is for "player".
    if unitName ~= "player" then
      return
    end


    local _, raceFile = UnitRace("player")
    if raceFile == "Worgen" then

      -- We only use this for chaning from Worgen into Human,
      -- because then the UNIT_MODEL_CHANGED comes a little too late.
      if spellId == 68996 then
        -- print("Worgen form change ('Two Forms')!")

        -- The cooldown of "Two Forms" is shorter than it takes to fully change into Worgen.
        -- If you hit "Two Forms" again before completely transforming you just stay in Human form.
        if self.changingIntoWorgen then
          -- print("You are currently changing into worgen")

          self.changingIntoWorgen = false
          -- We need to skip the next two executions of UNIT_MODEL_CHANGED.
          self.skipNextWorgenUnitModelChanged = 2
          return
        end


        -- Derive the Worgen form you are changing into from the last known form.
        local modelId = self:GetOppositeLastWorgenModelId()
        if modelId == self.raceAndGenderToModelId["Human"][UnitSex("player")] then
          -- print("Changing into Human.")

          -- WoW sometimes misses that you cannot use "Two Forms" while in combat.
          -- Then we get UNIT_SPELLCAST_SUCCEEDED but the model does not change.
          -- So we have to catch this here ourselves.
          if InCombatLockdown() then
            return
          end

          -- While changing from Worgen into Human, the next UNIT_MODEL_CHANGED event
          -- comes a little too late for a smooth shoulder offset change and there
          -- are no events in between. This is why we have to use cosFix_wait here.

          -- Set lastModelId to Human.
          self.db.char.lastModelId = modelId

          -- Remember that we are currently chaning into Human in order to suppress
          -- a shoulder offset change by the next UNIT_MODEL_CHANGED.
          self.skipNextWorgenUnitModelChanged = 1

          -- As we are circumventing CorrectShoulderOffset(), we have to check the setting here!
          local modelFactor = self.playerModelOffsetFactors[modelId]

          -- Call with pre-determined modelFactor to avoid recalculation.
          return self:SetDelayedShoulderOffset(0.06, modelFactor)

        else
          -- print("Changing into Worgen.")

          -- The shoulder offset change will be performed by UNIT_MODEL_CHANGED.
          self.skipNextWorgenUnitModelChanged = 0

          -- Remember only that you are currently changing into Worgen
          -- in case "Two Forms" is called again before change is complete.
          self.changingIntoWorgen = true
        end
      end
    end  -- (raceFile == "Worgen")


    -- Attempt to get it better. But did not work!
    -- local _, englishClass = UnitClass("player")
    -- if englishClass == "DEMONHUNTER" then

      -- if spellId == 198013 then
        -- print("UNIT_SPELLCAST_SUCCEEDED for METAMORPHOSIS HAVOC")
        -- self.lastSpellCastSentTime = GetTime()

        -- local _, raceFile = UnitRace("player")
        -- local genderCode = UnitSex("player")
        -- local factor = self.demonhunterFormToShoulderOffsetFactor[raceFile][genderCode]["Havoc"]

        -- return self:SetDelayedShoulderOffset(0.64, factor)

      -- end
    -- end  -- (englishClass == "DEMONHUNTER")




  -- Needed for Worgen form change.
  elseif event == "UNIT_MODEL_CHANGED" then

    -- Only do something if UNIT_MODEL_CHANGED is for "player".
    local unitName = ...
    if unitName ~= "player" then
      return
    end


    local _, raceFile = UnitRace("player")
    -- print(raceFile)
    if raceFile == "Worgen" then

      -- When logging in, there is also a call of UNIT_MODEL_CHANGED.
      -- But when we are mounted, we do not want this to have any effect
      -- on the shoulder offset.
      if IsMounted() then
        return
      end

      -- When changing Worgen form, there are always two UNIT_MODEL_CHANGED calls.
      -- The first has (almost) the right timing to change the camera shoulder offset while
      -- turing into Worgen. For changing into Human, we need our own cosFix_wait timer
      -- started by UNIT_SPELLCAST_SUCCEEDED of "Two Forms".
      -- Thus, when changing into Human, we completely suppress the first
      -- call of UNIT_MODEL_CHANGED. (When using "Two Forms" while chaning into Worgen
      -- we even have to skip the next two calls of UNIT_MODEL_CHANGED.)
      if self.skipNextWorgenUnitModelChanged > 0 then
        -- print("Suppressing UNIT_MODEL_CHANGED because of skipNextWorgenUnitModelChanged ==", self.skipNextWorgenUnitModelChanged)
        self.skipNextWorgenUnitModelChanged = self.skipNextWorgenUnitModelChanged - 1
        return
      end


      -- Try to determine the current form.
      self.modelFrame:SetUnit("player")
      local modelId = self.modelFrame:GetModelFileID()

      -- print("UNIT_MODEL_CHANGED thinks you are", modelId, "while lastModelId is", self.db.char.lastModelId)

      if (modelId == nil) or (self.playerModelOffsetFactors[modelId] == nil) then
        -- print("Using the opposite of lastModelId.")
        modelId = self:GetOppositeLastWorgenModelId()
        -- This will eventually set the right model ID.
        self:SetLastModelId()
      end
      -- print("Assuming you change into", modelId)


      if modelId == self.raceAndGenderToModelId["Worgen"][UnitSex("player")] then
        -- print("UNIT_MODEL_CHANGED -> Worgen")

        -- Remember that the change into Worgen is complete.
        self.changingIntoWorgen = false

        -- Set lastModelId to Worgen.
        self.db.char.lastModelId = modelId

        -- As we are circumventing CorrectShoulderOffset(), we have to check the setting here!
        local modelFactor = self.playerModelOffsetFactors[modelId]

        -- Call with pre-determined modelFactor to avoid recalculation.
        -- TODO: In fact this is still a little bit too late! But if we want to set it earlier, we would have
        -- to capture every event that forces a change from worgen into human... Is it possible?
        return self:SetDelayedShoulderOffset(0, modelFactor)

      else
        -- This should never happen except directly after logging in.
        -- print("UNIT_MODEL_CHANGED -> Human")

        -- As we are circumventing CorrectShoulderOffset(), we have to check the setting here!
        local modelFactor = self.playerModelOffsetFactors[modelId]

        -- Call with pre-determined modelFactor to avoid recalculation.
        return self:SetDelayedShoulderOffset(0, modelFactor)

      end
    -- (raceFile == "Worgen")
    
    elseif  raceFile == "Dracthyr" then
      
      if IsMounted() then
        return
      end
      
      -- Try to determine the current form.
      self.modelFrame:SetUnit("player")
      local modelId = self.modelFrame:GetModelFileID()

      -- print(modelId)

      -- As we are circumventing CorrectShoulderOffset(), we have to check the setting here!
      local modelFactor = self.playerModelOffsetFactors[modelId]

      -- Call with pre-determined modelFactor to avoid recalculation.
      return self:SetDelayedShoulderOffset(0, modelFactor)


    end

    -- print("... doing nothing!")


  -- To suppress Worgen UNIT_MODEL_CHANGED after loading screen.
  -- After the loading screen (not after logging in though), we get three
  -- UNIT_MODEL_CHANGED events, that would determine the wrong Worgen model.
  -- These are suppresed here.
  elseif event == "LOADING_SCREEN_DISABLED" then
    local _, raceFile = UnitRace("player")
    if raceFile == "Worgen" then
      self.skipNextWorgenUnitModelChanged = 3
    end


  -- Needed for shapeshifting.
  elseif event == "UPDATE_SHAPESHIFT_FORM" then

    local _, englishClass = UnitClass("player")
    if englishClass == "SHAMAN" then

      if GetShapeshiftFormID(true) ~= nil then
        -- print("You are changing into Ghostwolf (" .. GetShapeshiftFormID(true) .. ").")

        -- The UPDATE_SHAPESHIFT_FORM while changing into Ghostwolf comes too early.
        -- And also the subsequent UNIT_MODEL_CHANGED is still too early.
        -- That is why we have to use  a delay instead.
        return self:SetDelayedShoulderOffset(0.01)

      else
        -- print("You are changing into normal Shaman!")
        -- TODO: https://github.com/LudiusMaximus/CameraOverShoulderFix/issues/8

        -- Do not change the shoulder offset here.
        -- Wait until the next UNIT_AURA for perfect timing.
        self.activateNextUnitAura = true

        return

      end


    elseif englishClass == "DRUID" then

      local _, raceFile = UnitRace("player")
      if raceFile == "Worgen" then
        self.skipNextWorgenUnitModelChanged = 1
      end


      local formId = GetShapeshiftFormID(true)
      if formId ~= nil then
        -- print("You are changing into a shapeshift form.", formId)

        -- Worgen druids automatically change into Worgen form, when changing into a druid shapeshift form.
        if raceFile == "Worgen" then
          self.db.char.lastModelId = self.raceAndGenderToModelId["Worgen"][UnitSex("player")]
        end

        -- When changing into shapeshift, two UPDATE_SHAPESHIFT_FORM
        -- are executed, the first of which still gets formId == nil (if normal) or the previous formId (if shapeshifted).
        -- For the former we set updateShapeshiftFormCounter back to 0.
        -- For the latter we have to stop the timer.
        self.updateShapeshiftFormCounter = 0
        cosFix_waitTable = {}

        -- Remember the current formId, because we have to use different timings
        -- when changing back into normal depending on the current shapeshift form.
        self.db.char.lastformId = formId


        -- Just to be on the safe side, I guess...
        self.waitingForUnitSpellcastSentSucceeded = false
        self.changingIntoTravelForm = false


        if formId == 1 then
          -- print("cat")
          self.activateNextUnitAura = false
          self.activateNextHealthFrequent = false

          -- Sometimes you need this, sometimes the below... WTF
          return self:SetDelayedShoulderOffset(0.06)
          -- return self:SetDelayedShoulderOffset()

        elseif formId == 5 then
          -- print("bear")
          self.activateNextUnitAura = false
          self.activateNextHealthFrequent = true
          return

        else
          -- print("travel or tree of light...")
          self.activateNextUnitAura = false
          self.activateNextHealthFrequent = false

          -- Sometimes you need this, sometimes the below... WTF
          return self:SetDelayedShoulderOffset(0.018)
          -- return self:SetDelayedShoulderOffset()

        end

      else
        -- print("You are changing into normal Druid!")

        -- When changing from aquatic/travel form or Tree of Life into normal druid,
        -- there is always a first UPDATE_SHAPESHIFT_FORM in which the old shapeshifted form is still detected.
        -- This will start a timer, which we have to revoke here.
        if (self.db.char.lastformId == 2) or (self.db.char.lastformId == 3) or (self.db.char.lastformId == 4) or (self.db.char.lastformId == 27) or (self.db.char.lastformId == 29) then
          cosFix_waitTable = {}
          self.db.char.lastformId = nil
        end


        -- When changing from a non-travel form back into normal, we have to use the next
        -- UPDATE_SHAPESHIFT_FORM events, because for some reason the shoulder offset change
        -- occurs sometimes sooner, sometimes later after the first UPDATE_SHAPESHIFT_FORM.
        if self.db.char.lastformId ~= nil then
          self.db.char.lastformId = nil

          self.updateShapeshiftFormCounter = 1
          -- print("Setting counter to", self.updateShapeshiftFormCounter)

          -- Wait for the travel form spellcast to set changingIntoTravelForm in case.
          self.waitingForUnitSpellcastSentSucceeded = true
        else
          if self.updateShapeshiftFormCounter == 0 then

            if self.changingIntoTravelForm == true then
              -- print("Doing nothing because you are changing from a non-travel form into travel form.")
              self.changingIntoTravelForm = false
              return

            else
              -- print("Reached updateShapeshiftFormCounter ==", self.updateShapeshiftFormCounter)

              -- We have not observed the travelform spellcast, so we do not need to wait for it any longer.
              self.waitingForUnitSpellcastSentSucceeded = false

              return self:SetDelayedShoulderOffset()

            end

          else
            self.updateShapeshiftFormCounter = self.updateShapeshiftFormCounter - 1
            -- print("Decreasing updateShapeshiftFormCounter to", self.updateShapeshiftFormCounter)
            return
          end
        end

      end
    end -- (englishClass == "DRUID")

    -- print("... doing nothing!")



  -- Needed for changing into bear.
  elseif event == "UNIT_HEALTH" then
    if self.activateNextHealthFrequent == true then

      -- print("Executing UNIT_HEALTH")
      self.activateNextUnitAura = false
      self.activateNextHealthFrequent = false

      return self:SetDelayedShoulderOffset(0.05)
    end


  -- Needed for Druid shapeshift changes
  -- and special dismounting cases.
  -- TODO: Why are you not using UNIT_SPELLCAST_SUCCEEDED?
  elseif event == "UNIT_SPELLCAST_SENT" then

    local unitName, _, _, spellId = ...

    -- Only do something if UNIT_SPELLCAST_SENT is for "player".
    if unitName ~= "player" then
      return
    end

    -- Trying to determine if we are currently changing from
    -- one druid shapeshift form into travel form.
    if (self.waitingForUnitSpellcastSentSucceeded == true) and (spellId == 783) then
      self.waitingForUnitSpellcastSentSucceeded = false
      self.changingIntoTravelForm = true
    end

    -- Sometimes when dismounting automatically (e.g. because of mining or herbgathering)
    -- the PLAYER_MOUNT_DISPLAY_CHANGED event comes after the UNIT_AURA, so we cannot
    -- do our standard procedure. To recognise these cases, we wait for UNIT_AURA
    -- after each UNIT_SPELLCAST_SENT. If we see it before PLAYER_MOUNT_DISPLAY_CHANGED,
    -- we know that this special case has occured.
    self.waitingForUnitAura = true
    self.unitAuraBeforeMountDisplayChanged = false

    -- But we only wait for a very short time, lest other UNIT_SPELLCAST_SENT
    -- set the waitingForUnitAura make it look like we are still waiting when
    -- the player dismounts for any other reason.
    self:ScheduleTimer(function() self.waitingForUnitAura = false end, 0.1)




  -- Needed for mounting and entering taxis.
  elseif event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
    if not IsMounted() then

      -- print("PLAYER_MOUNT_DISPLAY_CHANGED: Not Mounted")

      -- Sometimes there is no UNIT_AURA after leaving a taxi.
      -- We can then set the value unmounted immedeately.
      if self.db.char.isOnTaxi then
        self.db.char.isOnTaxi = false
        return self:SetDelayedShoulderOffset()
      end

      -- The same goes for being dismounted automatically while entering indoors.
      if IsIndoors() then
        return self:SetDelayedShoulderOffset()
      end

      -- The same goes for being dismounted in certain outdoor areas
      -- (e.g. certain quest givers like Great-father Winter).
      -- This can be checked by trying if the last active mount is usable.
      -- Interestingly this does not work for entering indoors, so we still need the check above.
      local _, _, _, _, lastActiveMountUsable = C_MountJournal_GetMountInfoByID(self.db.char.lastActiveMount)
      if not lastActiveMountUsable then
        return self:SetDelayedShoulderOffset()
      end




      -- If the UNIT_AURA after UNIT_SPELLCAST_SENT has already occured before
      -- this PLAYER_MOUNT_DISPLAY_CHANGED, we must change the shoulder
      -- offset immedeately.
      if self.unitAuraBeforeMountDisplayChanged == true then
        self.unitAuraBeforeMountDisplayChanged = false
        return self:SetDelayedShoulderOffset()
      end

      -- Otherwise, we are good for our standard procedure
      self.waitingForUnitAura = false

      -- Change the shoulder offset once here and then again with the next UNIT_AURA.
      self.activateNextUnitAura = true



      -- TODO: https://github.com/LudiusMaximus/CameraOverShoulderFix/issues/9


      -- When shoulder offset is greater than 0, we need to set it to 10 times its actual value
      -- for the time between this PLAYER_MOUNT_DISPLAY_CHANGED and the next UNIT_AURA.
      local modelFactor = self:CorrectShoulderOffset()
      
      if self:GetCurrentShoulderOffset() > 0 then
        modelFactor = modelFactor * 10
      end
      -- Call with pre-determined modelFactor to avoid recalculation.
      return self:SetDelayedShoulderOffset(0, modelFactor)


    else
      -- print("PLAYER_MOUNT_DISPLAY_CHANGED: Mounted")
      return self:SetDelayedShoulderOffset()

    end


  -- Needed to determine the right time to change shoulder offset when dismounting,
  -- changing from Shaman Ghostwolf into normal, from shapeshifted Druid into normal,
  -- and for Demon Hunter Metamorphosis.
  elseif event == "UNIT_AURA" then

    -- Only do something if UNIT_AURA is for "player".
    local unitName = ...
    if unitName ~= "player" then
      return
    end

    -- This is flag is set while dismounting and while changing from Ghostwolf into Shaman.
    if self.activateNextUnitAura == true then

      -- print("Executing UNIT_AURA")

      self.activateNextUnitAura = false
      self.activateNextHealthFrequent = false

      return self:SetDelayedShoulderOffset()

    end

    -- Are we seeing this UNIT_AURA shortly after a UNIT_SPELLCAST_SENT
    -- but before PLAYER_MOUNT_DISPLAY_CHANGED?
    if self.waitingForUnitAura == true then
      self.waitingForUnitAura = false
      self.unitAuraBeforeMountDisplayChanged = true
    end


    -- We are also using UNIT_AURA to get the right timing for Demon Hunter Metamorphosis.
    -- TODO: https://github.com/LudiusMaximus/CameraOverShoulderFix/issues/10
    local _, englishClass = UnitClass("player")
    if englishClass == "DEMONHUNTER" then

      if self.timeOfLastSpellsChanged == GetTime() then

        local demonHunterForm = GetDemonHunterForm()

        if demonHunterForm == 1 then
          -- print("UNIT_AURA for METAMORPHOSIS HAVOC")
          -- TODO: This is never right!!! :-(
          return self:SetDelayedShoulderOffset(0.654)
        end

        if demonHunterForm == 2 then
          -- print("UNIT_AURA for METAMORPHOSIS VENGEANCE")
          return self:SetDelayedShoulderOffset(0.966)
        end

        if demonHunterForm == 0 then
          -- print("UNIT_AURA for DEMON HUNTER back to normal")
          -- TODO: For a framerate of 30 or lower, this still gives a camera jerk!
          return self:SetDelayedShoulderOffset(0.082)
        end

      end

    end  -- (englishClass == "DEMONHUNTER")

    -- print("... doing nothing!")


  elseif event == "SPELLS_CHANGED" then


    self.timeOfLastSpellsChanged = GetTime()



  -- Needed for vehicles.
  elseif event == "UNIT_ENTERING_VEHICLE" then
    local unitName, _, _, _, vehicleGuid = ...
    -- print(unitName)
    -- print(vehicleGuid)

    -- Only do something if UNIT_ENTERING_VEHICLE is for "player".
    if unitName ~= "player" then
      return
    end

    local modelFactor = self:CorrectShoulderOffset(vehicleGuid)

    -- Call with pre-determined modelFactor to avoid recalculation.
    return self:SetDelayedShoulderOffset(0, modelFactor)

  -- Needed for vehicles.
  elseif event == "UNIT_EXITING_VEHICLE" then
    local unitName = ...

    -- Only do something if UNIT_EXITING_VEHICLE is for "player".
    if unitName ~= "player" then
      return
    end

    return self:SetDelayedShoulderOffset()


  -- Needed for being teleported into a dungeon while mounted,
  -- because when entering you get automatically dismounted
  -- without PLAYER_MOUNT_DISPLAY_CHANGED being executed.
  elseif event == "PLAYER_ENTERING_WORLD" then
    return self:SetDelayedShoulderOffset()
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
  self:RegisterEvent("UNIT_HEALTH", "ShoulderOffsetEventHandler")


  -- Needed to know if you change from a non-travel form into travel form.
  self:RegisterEvent("UNIT_SPELLCAST_SENT", "ShoulderOffsetEventHandler")


  -- Needed for automatic dismounting when pet battle starts.
  self:RegisterEvent("PLAYER_CONTROL_LOST", "ShoulderOffsetEventHandler")


  -- Needed for mounting and entering taxis.
  self:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED", "ShoulderOffsetEventHandler")

  -- Needed to determine the right time to change shoulder offset when dismounting,
  -- changing from Shaman Ghostwolf into normal and for Demon Hunter Metamorphosis.
  self:RegisterEvent("UNIT_AURA", "ShoulderOffsetEventHandler")

  -- For Demon Hunter Metamorphosis.
  self:RegisterEvent("SPELLS_CHANGED", "ShoulderOffsetEventHandler")


  -- Needed for vehicles.
  self:RegisterEvent("UNIT_ENTERING_VEHICLE", "ShoulderOffsetEventHandler")
  self:RegisterEvent("UNIT_EXITING_VEHICLE", "ShoulderOffsetEventHandler")

  -- Needed for being teleported into a dungeon while mounted,
  -- because when entering you get automatically dismounted
  -- without PLAYER_MOUNT_DISPLAY_CHANGED being executed.
  self:RegisterEvent("PLAYER_ENTERING_WORLD", "ShoulderOffsetEventHandler")

end

