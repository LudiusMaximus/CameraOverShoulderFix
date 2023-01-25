local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)



local math_floor = _G.math.floor

local function Round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0)
  return math_floor(num * mult + 0.5) / mult
end



-- Build our own vehicleIdToName lookup table,
-- because the vehicle name can only be obtained when actually on the vehicle.
cosFix.vehicleIdToName = {}
local mutex = false
local function StoreVehicleIdToName(unit)
  if unit ~= "vehicle" or mutex then return end

  mutex = true
  local vehicleGUID = UnitGUID("vehicle")
  mutex = false

  if not vehicleGUID then return end

  local _, _, _, _, _, vehicleId = strsplit("-", vehicleGUID)
  if cosFix.vehicleIdToName[tonumber(vehicleId)] then return end

  mutex = true
  cosFix.vehicleIdToName[tonumber(vehicleId)] = UnitName("vehicle")
  mutex = false
end
hooksecurefunc("UnitGUID", StoreVehicleIdToName)
hooksecurefunc("UnitName", StoreVehicleIdToName)
hooksecurefunc("GetUnitName", StoreVehicleIdToName)


local _G = _G
local pairs = _G.pairs
local tonumber = _G.tonumber

local ButtonFrameTemplate_HidePortrait = _G.ButtonFrameTemplate_HidePortrait
local C_DateAndTime_GetCurrentCalendarTime = _G.C_DateAndTime.GetCurrentCalendarTime
local C_BattleNet_GetGameAccountInfoByGUID = _G.C_BattleNet.GetGameAccountInfoByGUID
local C_MountJournal_GetMountInfoByID = _G.C_MountJournal.GetMountInfoByID
local C_MountJournal_GetMountIDs      = _G.C_MountJournal.GetMountIDs
local C_MountJournal_SummonByID       = _G.C_MountJournal.SummonByID

local CanExitVehicle = _G.CanExitVehicle
local CreateFrame    = _G.CreateFrame
local GameTooltip    = _G.GameTooltip
local IsMounted      = _G.IsMounted
local PlaySound      = _G.PlaySound
local UnitInVehicle  = _G.UnitInVehicle
local UnitGUID       = _G.UnitGUID
local UnitOnTaxi     = _G.UnitOnTaxi
local VehicleExit    = _G.VehicleExit





local maxFactor = 10


cosFix.setFactorFrame = CreateFrame("Frame", "cosFix_SetFactorFrame", UIParent, "ButtonFrameTemplate")
local f = cosFix.setFactorFrame
f:SetPoint("TOPLEFT")
ButtonFrameTemplate_HidePortrait(f)
-- SetPortraitToTexture(...)
-- ButtonFrameTemplate_HideAttic(f)
-- ButtonFrameTemplate_HideButtonBar(f)
f:SetFrameStrata("HIGH")
f:SetWidth(460)
f:SetHeight(220)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetClampedToScreen(true)
tinsert(UISpecialFrames, "cosFix_SetFactorFrame")
f:Hide()
_G[f:GetName().."TitleText"]:SetText("CameraOverShoulderFix - Set Offset Factor")
_G[f:GetName().."TitleText"]:ClearAllPoints()
_G[f:GetName().."TitleText"]:SetPoint("TOPLEFT", 10, -6)




f.deleteButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.deleteButton:SetPoint("BOTTOMLEFT", 6, 4)
f.deleteButton:SetText("Delete")
f.deleteButton:SetWidth(90)
f.deleteButton:SetScript("OnClick", function()
    if customOffsetFactors[f.idType][f.id] then
      customOffsetFactors[f.idType][f.id] = nil
    end
    f:SetId(f.idType, f.id, true)
  end)
f.deleteButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Delete custom offset factor.")
  end)
f.deleteButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)



f.resetButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.resetButton:SetPoint("BOTTOM", 0, 4)
f.resetButton:SetText("Reset")
f.resetButton:SetWidth(90)
f.resetButton:SetScript("OnClick", function()
    f:SetId(f.idType, f.id, true)
  end)
f.deleteButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Reset to custom//hardcoded factor.")
  end)
f.deleteButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)




f.saveButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.saveButton:SetPoint("BOTTOMRIGHT", -1, 4)
f.saveButton:SetText("Save")
f.saveButton:SetWidth(90)
f.saveButton:SetScript("OnClick", function()

    local modelId = cosFix:GetCurrentModelId()
    if modelId == 4207724 then
      print("For some reason being mounted in Dracthyr form needs intractably different offsets than all the other player models. More coding is required to store custom values just for them. So just don't use this for Dracythr form! Sorry.")
      return
    end



    -- Do not allow the same custom value as hardcoded value.
    if cosFix.hardcodedOffsetFactors[f.idType][f.id] and cosFix.hardcodedOffsetFactors[f.idType][f.id] == f.offsetFactor then
      customOffsetFactors[f.idType][f.id] = nil
      f:SetId(f.idType, f.id, true)
      return
    end

    -- Save the custom value.
    local gameAccountInfo = C_BattleNet_GetGameAccountInfoByGUID(UnitGUID("player"))
    local playerName = gameAccountInfo.characterName.."-"..gameAccountInfo.realmName
    local calendarTime = C_DateAndTime_GetCurrentCalendarTime()
    local today = format("%02d-%02d-%02d", calendarTime.year, calendarTime.month, calendarTime.monthDay)
    
    local _, raceFile = UnitRace("player")
    local character = raceFile .. " " .. ((UnitSex("player") == 2) and "Male" or "Female")
    customOffsetFactors[f.idType][f.id] = {
      factor     = f.offsetFactor,
      metaData   = f.mountName .. ";" .. today .. ";" .. playerName .. ";" .. character
    }

    f:SetId(f.idType, f.id, true)
  end)
f.saveButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Save custom offset factor.")
    
    local modelId = cosFix:GetCurrentModelId()
    if modelId == 4207724 then
      -- self:Disable()
      GameTooltip:SetText("For some reason being mounted in Dracthyr form needs intractably different offsets than all the other player models. More coding is required to store custom values just for them. So just don't use this for Dracythr form! Sorry.", 1, 0, 0, 1, true)
    end
    
  end)
f.saveButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)




f.exportButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.exportButton:SetFrameLevel(f.NineSlice:GetFrameLevel() + 10)
f.exportButton:SetPoint("TOPRIGHT", cosFix_SetFactorFrameCloseButton, "TOPLEFT", 0, 0)
f.exportButton:SetText("Export")
f.exportButton:SetWidth(70)
f.exportButton:SetScript("OnClick", function()
    print("TODO: Export")
    --https://stackoverflow.com/questions/36031078/lua-number-to-string-behaviour
  end)
f.exportButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Export your custom factors to send\nthem to the addon developer!")
  end)
f.exportButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)



f.coarseSlider = CreateFrame("Slider", "cosFix_coarseSlider", f.Inset, "OptionsSliderTemplate")
-- Alternative to using the template...
-- s:SetThumbTexture("Interface\\Buttons\\UI-SliderBar-Button-Horizontal")
-- s:SetBackdrop({
  -- bgFile = "Interface\\Buttons\\UI-SliderBar-Background",
  -- edgeFile = "Interface\\Buttons\\UI-SliderBar-Border",
  -- tile = true, tileSize = 8, edgeSize = 8,
  -- insets = { left = 3, right = 3, top = 6, bottom = 6 }})
-- s:SetOrientation('HORIZONTAL')
f.coarseSlider:SetPoint("TOP", 3, -60)
f.coarseSlider:SetWidth(240)
f.coarseSlider:SetHeight(17)
f.coarseSlider:SetMinMaxValues(0, maxFactor)
f.coarseSlider:SetValueStep(0.1)
f.coarseSlider:SetObeyStepOnDrag(true)
 _G[f.coarseSlider:GetName() .. 'Low']:SetText("0")
 _G[f.coarseSlider:GetName() .. 'High']:SetText(maxFactor)
 _G[f.coarseSlider:GetName() .. 'Text']:SetText("")
f.coarseSlider:SetScript("OnValueChanged", function(self, value)
    f.offsetFactor = Round(value, 1)
    f:RefreshLabels()
  end)


f.fineSlider = CreateFrame("Slider", "cosFix_fineSlider", f.coarseSlider, "OptionsSliderTemplate")
f.fineSlider:SetPoint("TOP", 0, -35)
f.fineSlider:SetWidth(240)
f.fineSlider:SetHeight(17)
f.fineSlider:SetMinMaxValues(-0.5, 0.5)
f.fineSlider:SetValueStep(0.001)
f.fineSlider:SetObeyStepOnDrag(true)
 _G[f.fineSlider:GetName() .. 'Low']:SetText("-0.5")
 _G[f.fineSlider:GetName() .. 'High']:SetText("+0.5")
 _G[f.fineSlider:GetName() .. 'Text']:SetText("")
f.fineSlider:SetScript("OnValueChanged", function(self, value)
    if f.coarseSlider:GetValue() + value < 0 then
      f.offsetFactor = 0
    elseif f.coarseSlider:GetValue() + value > maxFactor then
      f.offsetFactor = maxFactor
    else
      f.offsetFactor = Round(f.coarseSlider:GetValue() + value, 3)
    end
    f:RefreshLabels()
  end)


f.valueBox = CreateFrame("EditBox", nil, f.Inset, "InputBoxTemplate")
f.valueBox:SetPoint("TOPRIGHT", -14, -60)
f.valueBox:SetFontObject(ChatFontNormal)
f.valueBox:SetSize(50, 20)
f.valueBox:SetMultiLine(false)
f.valueBox:SetAutoFocus(false)
f.valueBox.lastValidValue = nil
f.valueBox:SetScript("OnTextChanged", function(self, ...)
    -- Prevent invalid entries in the text box.
    if self:GetText() ~= "" and (tonumber(self:GetText()) == nil or tonumber(self:GetText()) < 0) then
      local oldCursorPosition = self:GetCursorPosition()
      local oldNumLetters = self:GetNumLetters()
      self:SetText(self.lastValidValue)
      self:SetCursorPosition(oldCursorPosition - oldNumLetters + self:GetNumLetters())
    else
      self.lastValidValue = tonumber(self:GetText())
    end
    f:RefreshButtons()
  end)
f.valueBox:SetScript("OnTextSet", function(self)
    self.lastValidValue = tonumber(self:GetText())
    f:RefreshButtons()
  end)
f.valueBox:SetScript("OnEscapePressed", function(self)
    self:ClearFocus()
    f:RefreshLabels()
  end)
f.valueBox:SetScript("OnEnterPressed", function(self)
    if self.lastValidValue > maxFactor then
      self.lastValidValue = maxFactor
    end
    f.offsetFactor = Round(self.lastValidValue, 3)
    f:RefreshLabels()
  end)


f.minusButton = CreateFrame("Button", nil, f.valueBox, "UIPanelButtonTemplate")
f.minusButton:SetPoint("TOPLEFT", f.valueBox, "BOTTOMLEFT", -7, 0)
f.minusButton:SetText("-")
f.minusButton:SetWidth(25)
f.minusButton:SetScript("OnClick", function()
    if f.offsetFactor - 0.001 < 0 then
      f.offsetFactor = 0
    else
      f.offsetFactor = f.offsetFactor - 0.001
    end
    f:RefreshLabels()
  end)

f.plusButton = CreateFrame("Button", nil, f.valueBox, "UIPanelButtonTemplate")
f.plusButton:SetPoint("TOPRIGHT", f.valueBox, "BOTTOMRIGHT", 2, 0)
f.plusButton:SetText("+")
f.plusButton:SetWidth(25)
f.plusButton:SetScript("OnClick", function()
    if f.offsetFactor + 0.001 > maxFactor then
      f.offsetFactor = maxFactor
    else
      f.offsetFactor = f.offsetFactor + 0.001
    end
    f:RefreshLabels()
  end)

f.okButton = CreateFrame("Button", nil, f.valueBox, "UIPanelButtonTemplate")
f.okButton:SetPoint("LEFT", f.valueBox, "RIGHT", 0, 0)
f.okButton:SetText("OK")
f.okButton:SetWidth(35)
f.okButton:SetFrameStrata("DIALOG")
f.okButton:SetScript("OnClick", function()
    if f.valueBox.lastValidValue > maxFactor then
      f.valueBox.lastValidValue = maxFactor
    end
    f.offsetFactor = Round(f.valueBox.lastValidValue, 3)
    f:RefreshLabels()
  end)


-- Did not get into this template. Texture size was greater than the button size
-- when using SetNormalTexture.
-- f.mountButton = CreateFrame("CheckButton", nil, f.Inset, "SecureActionButtonTemplate, ActionButtonTemplate")

-- Doing it manually like this.
f.mountButton = CreateFrame("CheckButton", nil, f.Inset)
f.mountButton:SetPoint("TOPLEFT", 14, -60)
f.mountButton:SetSize(55, 55)
f.mountButton.mountButtonBackgroundTexture = f.mountButton:CreateTexture()
f.mountButton.mountButtonBackgroundTexture:SetAllPoints()
f.mountButton.mountButtonBackgroundTexture:SetDrawLayer("BACKGROUND", 0)
f.mountButton:SetHighlightTexture("UI-HUD-ActionBar-IconFrame-Mouseover")
f.mountButton:SetPushedTexture("UI-HUD-ActionBar-IconFrame-Down")
f.mountButton:SetCheckedTexture("UI-HUD-ActionBar-IconFrame-Mouseover")

-- The normal texture will be set when the mount is set.
-- (SetNormalTexture() does not work here, as it will be replaced by the PushedTexture.)
-- https://www.wowinterface.com/forums/showthread.php?t=57901







f.mountButton:SetScript("OnClick", function(self)
    C_MountJournal_SummonByID(f.id)
    f:RefreshButtons()
  end)



f.vehicleButton = CreateFrame("Button", nil, f.Inset)
f.vehicleButton:SetPoint("TOPLEFT", 14, -60)
f.vehicleButton:SetSize(55, 55)
f.vehicleButton:SetNormalTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
f.vehicleButton:SetDisabledTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Up")
f.vehicleButton:GetDisabledTexture():SetDesaturated(true)
f.vehicleButton:SetPushedTexture("Interface\\Vehicles\\UI-Vehicles-Button-Exit-Down")
f.vehicleButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")

local L, R, T, B = 0.15, 0.85, 0.15, 0.85
f.vehicleButton:GetNormalTexture():SetTexCoord(L, R, T, B )
f.vehicleButton:GetDisabledTexture():SetTexCoord(L, R, T, B )
f.vehicleButton:GetPushedTexture():SetTexCoord(L, R, T, B )

f.vehicleButton:SetScript("OnClick", function(self)
    VehicleExit()
    f:RefreshButtons()
  end)



f.prevMountButton = CreateFrame("Button", nil, f.Inset)
f.prevMountButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Up")
f.prevMountButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Down")
f.prevMountButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-PrevPage-Disabled")
f.prevMountButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
f.prevMountButton:SetSize(25, 25)
f.prevMountButton:SetPoint("TOPRIGHT", -79, -10)
f.prevMountButton:SetScript("OnClick", function()
    f:SetId("mountId", f.prevMountId, true)
  end)
f.prevMountButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Previous usable mount.")
  end)
f.prevMountButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)


f.nextMountButton = CreateFrame("Button", nil, f.Inset)
f.nextMountButton:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
f.nextMountButton:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
f.nextMountButton:SetDisabledTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Disabled")
f.nextMountButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
f.nextMountButton:SetSize(25, 25)
f.nextMountButton:SetPoint("TOPLEFT", f.prevMountButton, "TOPRIGHT", 0, 0)
f.nextMountButton:SetScript("OnClick", function()
    f:SetId("mountId", f.nextMountId, true)
  end)
f.nextMountButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Next usable mount.")
  end)
f.nextMountButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)


f.returnToCurrentButton = CreateFrame("Button", nil, f.Inset)
f.returnToCurrentButton:SetNormalTexture("Interface\\Buttons\\UI-MICROBUTTON-QUEST-UP")
f.returnToCurrentButton:SetPushedTexture("Interface\\Buttons\\UI-MICROBUTTON-QUEST-DOWN")
f.returnToCurrentButton:SetHighlightTexture("Interface\\Buttons\\UI-MicroButton-Hilight", "ADD")
local shrinkFactor = 0.55
f.returnToCurrentButton:SetSize(32*shrinkFactor, 64*shrinkFactor)
f.returnToCurrentButton:SetPoint("RIGHT", f.prevMountButton, "LEFT", -2, 6)
f.returnToCurrentButton:SetScript("OnClick", function()
    local idType, id = f:GetCurrentTypeAndId()
    f:SetId(idType, id, true)
  end)
f.returnToCurrentButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, -11.5)
    GameTooltip:SetText("Current mount/vehicle/model.")
  end)
f.returnToCurrentButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)



f.nextUnknownMountButton = CreateFrame("Button", nil, f.Inset)
f.nextUnknownMountButton:SetNormalAtlas("QuestCollapse-Show-Up")
f.nextUnknownMountButton:SetPushedAtlas("QuestCollapse-Show-Down")
f.nextUnknownMountButton:SetDisabledAtlas("QuestCollapse-Show-Up")
f.nextUnknownMountButton:GetDisabledTexture():SetDesaturated(true)
f.nextUnknownMountButton:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
f.nextUnknownMountButton:GetHighlightTexture():SetTexCoord(0.15, 0.85, 0.15, 0.85)
f.nextUnknownMountButton:SetSize(21, 21)
f.nextUnknownMountButton:SetPoint("LEFT", f.nextMountButton, "RIGHT", 20, 0)
f.nextUnknownMountButton:SetScript("OnClick", function()
    f:SetId("mountId", f.nextUnknownMountId, true)
  end)
f.nextUnknownMountButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP", 0, 2)
    GameTooltip:SetText("Next mount without factor.")
  end)
f.nextUnknownMountButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)



f.onlyCustomCheckBox = CreateFrame("CheckButton", "cosFix_onlyCustomCheckBox", f, "UICheckButtonTemplate")
f.onlyCustomCheckBox:SetSize(22, 22)
f.onlyCustomCheckBox:SetPoint("TOPLEFT", f.prevMountButton, "BOTTOMLEFT", 0, 3)
_G[f.onlyCustomCheckBox:GetName() .. "Text"]:SetText(" Custom only")
f.onlyCustomCheckBox:SetScript("OnClick", function(self)
    f:PrepareMountSelectButtons()
  end
)
f.onlyCustomCheckBox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, -20)
    GameTooltip:SetText("Only skip through mounts for which\nyou have set a custom factor.")
  end
)
f.onlyCustomCheckBox:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end
)







f.nextMountId = nil
f.prevMountId = nil
f.nextUnknownMountId = nil

function f:PrepareMountSelectButtons()

  f.nextMountId = nil
  f.prevMountId = nil
  f.nextUnknownMountId = nil

  local takeNext = false
  local firstMountId = nil
  local lastMountId = nil
  local firstUnknownMountId = nil

  for k, v in pairs (C_MountJournal_GetMountIDs()) do
    local _, _, _, _, isUsable = C_MountJournal_GetMountInfoByID(v)
    if isUsable and (not f.onlyCustomCheckBox:GetChecked() or customOffsetFactors["mountId"][v]) then

      if not firstMountId then firstMountId = v end

      if takeNext and not f.nextMountId then f.nextMountId = v end

      if not customOffsetFactors["mountId"][v] and not cosFix.hardcodedOffsetFactors["mountId"][v] then
        if not firstUnknownMountId then firstUnknownMountId = v end
        if takeNext and not f.nextUnknownMountId then f.nextUnknownMountId = v end
      end

      if f.id == v then
        takeNext = true
        if lastMountId then f.prevMountId = lastMountId end
      end

      lastMountId = v
    end

    -- If we have all, we are done!
    if f.nextMountId and f.prevMountId and f.nextUnknownMountId then break end
  end


  if not f.prevMountId and lastMountId then f.prevMountId = lastMountId end
  if not f.nextMountId and firstMountId then f.nextMountId = firstMountId end
  if not f.nextUnknownMountId and firstUnknownMountId then f.nextUnknownMountId = firstUnknownMountId end


  -- If the player has no usable mounts at all.
  if not f.nextMountId then
    f.prevMountButton:Disable()
    f.nextMountButton:Disable()
    f.nextUnknownMountButton:Disable()
  else
    f.prevMountButton:Enable()
    f.nextMountButton:Enable()
    if not f.nextUnknownMountId then
      f.nextUnknownMountButton:Disable()
    else
      f.nextUnknownMountButton:Enable()
    end
  end

end


function f:RefreshButtons()

  if not self:IsShown() then return end
  -- print("RefreshButtons")

  if not self.id then
    self.deleteButton:Disable()
    self.resetButton:Disable()
    self.saveButton:Disable()

    self.mountButton:Hide()
    self.vehicleButton:Hide()
    self.returnToCurrentButton:Hide()
    self.okButton:Hide()

    self.coarseSlider:Hide()
    self.fineSlider:Hide()
    self.valueBox:Hide()
    self.minusButton:Hide()
    self.plusButton:Hide()

    return
  else
    self.coarseSlider:Show()
    self.fineSlider:Show()
    self.valueBox:Show()
    self.minusButton:Show()
    self.plusButton:Show()
  end


  -- Value box.
  if self.valueBox.lastValidValue ~= self.offsetFactor then
    self.okButton:Show()
    self.minusButton:Disable()
    self.plusButton:Disable()
  else
    self.okButton:Hide()

    if self.offsetFactor <= 0 then
      self.minusButton:Disable()
    else
      self.minusButton:Enable()
    end

    if self.offsetFactor >= maxFactor then
      self.plusButton:Disable()
    else
      self.plusButton:Enable()
    end
  end


  -- Mount/Vehicle button.
  self.mountButton:Hide()
  self.vehicleButton:Hide()
  if self.idType == "mountId" then
    self.mountButton:Show()
    
    self.mountButton.mountButtonBackgroundTexture:SetTexture(self.mountIcon)
    

    -- Set the checked status!
    _, _, _, _, _, _, _, _, spellId = UnitCastingInfo("player")
    if (IsMounted() and f.id == cosFix:GetCurrentMount()) or (spellId and spellId == f.mountSpellId) then
      self.mountButton:SetChecked(true)
    else
      self.mountButton:SetChecked(false)
    end

  elseif self.idType == "vehicleId" then
    self.vehicleButton:Show()

    -- Set the enabled status!
    if CanExitVehicle() then
      self.vehicleButton:Enable()
    else
      self.vehicleButton:Disable()
    end
  end


  -- Return to current mount button.
  local idType, id = self:GetCurrentTypeAndId()
  if not idType or (idType == self.idType and id == self.id) then
    self.returnToCurrentButton:Hide()
  else
    self.returnToCurrentButton:Show()
  end


  -- Delete, Reset, Save buttons.
  if customOffsetFactors[self.idType][self.id] then
    self.deleteButton:Enable()
  else
    self.deleteButton:Disable()
  end

  if customOffsetFactors[self.idType][self.id] then
    if customOffsetFactors[self.idType][self.id]["factor"] ~= self.offsetFactor then
      self.saveButton:Enable()
      self.resetButton:Enable()
    else
      self.saveButton:Disable()
      self.resetButton:Disable()
    end
  elseif (not cosFix.hardcodedOffsetFactors[self.idType][self.id] and self.offsetFactor ~= 0) or
         (    cosFix.hardcodedOffsetFactors[self.idType][self.id] and self.offsetFactor ~= cosFix.hardcodedOffsetFactors[self.idType][self.id]) then
    self.saveButton:Enable()
    self.resetButton:Enable()
  else
    self.saveButton:Disable()
    self.resetButton:Disable()
  end

end





f.instructionTextLabel = f:CreateFontString(nil, "OVERLAY")
f.instructionTextLabel:SetFont("Fonts\\FRIZQT__.TTF", 12)
f.instructionTextLabel:SetTextColor(0.8, 0.8, 0.8)
f.instructionTextLabel:SetPoint("TOPLEFT", f.TopTileStreaks, "TOPLEFT", 10, -10)
f.instructionTextLabel:SetPoint("TOPRIGHT", f.TopTileStreaks, "TOPRIGHT", -10, -10)
f.instructionTextLabel:SetJustifyH("LEFT")
f.instructionTextLabel:SetText("Mount and dismount repeatedly to find the ideal factor for a mount or vehicle. See the addon web page for a video tutorial.")

f.mountNameLabel = f:CreateFontString(nil, "OVERLAY")
f.mountNameLabel:SetFont("Fonts\\FRIZQT__.TTF", 14)
f.mountNameLabel:SetTextColor(1.0, 0.6, 0.0)
f.mountNameLabel:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 13, -14)
f.mountNameLabel:SetPoint("TOPRIGHT", f.Inset, "TOPRIGHT", -6, -14)
f.mountNameLabel:SetJustifyH("LEFT")

f.storeStatusLabel = f:CreateFontString(nil, "OVERLAY")
f.storeStatusLabel:SetFont("Fonts\\FRIZQT__.TTF", 10)
f.storeStatusLabel:SetTextColor(0.2, 0.7, 1.0)
f.storeStatusLabel:SetPoint("TOPLEFT", f.mountNameLabel, "BOTTOMLEFT", 0, -4)
f.storeStatusLabel:SetJustifyH("LEFT")


function f:RefreshLabels()

  if not self:IsShown() then return end
  -- print("RefreshLabels", self.mountName, self.offsetFactor)
  -- print(self.coarseSlider:GetValue(), self.fineSlider:GetValue(), self.valueBox:GetText())

  if not self.id then
    self.mountNameLabel:SetText("No mount or vehicle selected.")
    self.storeStatusLabel:SetText("")
    self:RefreshButtons()
    return
  end

  self.mountNameLabel:SetText(self.mountName .. " (ID: " .. self.id .. ")")
  -- Longest possible string...
  -- self.mountNameLabel:SetText("Heavenly Crimson Cloud Serpent (ID: 9999)")

  if self.offsetFactor ~= self.valueBox:GetText() then
    self.valueBox:SetText(self.offsetFactor)
  end

  local storeStatus = ""
  if customOffsetFactors[self.idType][self.id] then
    storeStatus = "Custom factor ("..customOffsetFactors[self.idType][self.id]["factor"]..")"
    if cosFix.hardcodedOffsetFactors[self.idType][self.id] then
      storeStatus = storeStatus .. " overriding hardcoded factor ("..cosFix.hardcodedOffsetFactors[self.idType][self.id]..")"
    end
  elseif cosFix.hardcodedOffsetFactors[self.idType][self.id] then
    storeStatus = "Hardcoded factor ("..cosFix.hardcodedOffsetFactors[self.idType][self.id]..")"
  else
    storeStatus = "No factor available"
  end
  self.storeStatusLabel:SetText(storeStatus..".")


  -- Got to remember the original offsetFactor, because when we do coarseSlider:SetValue() it
  -- will change self.offsetFactor.
  local originalOffsetFactor = f.offsetFactor
  local roundedCoarseSlider = Round(self.coarseSlider:GetValue(), 1)
  if originalOffsetFactor < roundedCoarseSlider - 0.5 or originalOffsetFactor > roundedCoarseSlider + 0.5 then
    local roundedOffsetFactor = Round(originalOffsetFactor, 1)
    self.coarseSlider:SetValue(roundedOffsetFactor)
    self.fineSlider:SetValue(originalOffsetFactor - roundedOffsetFactor)
  else
    -- Only needed for the initial call!
    self.coarseSlider:SetValue(roundedCoarseSlider)
    self.fineSlider:SetValue(originalOffsetFactor - roundedCoarseSlider)
  end

  self:RefreshButtons()

  cosFix:SetDelayedShoulderOffset()
end






f.idType = nil
f.id = nil
f.mountName = nil
f.mountIcon = nil
f.mountSpellId = nil

f.offsetFactor = nil



f:SetScript("OnHide", function(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_CLOSE)

    -- To make this conditional we would have to call CorrectShoulderOffset() anyway.
    -- So we can just as well always call it.
    cosFix:SetDelayedShoulderOffset()
  end)




function f:GetCurrentTypeAndId()
  if IsMounted() and not UnitOnTaxi("player") then
    return "mountId", cosFix:GetCurrentMount()
  elseif UnitInVehicle("player") then
    local _, _, _, _, _, vehicleId = strsplit("-", UnitGUID("vehicle"))
    return "vehicleId", tonumber(vehicleId)
  elseif not cosFix.playerModelOffsetFactors[cosFix:GetCurrentModelId()] then
    return "modelId", cosFix:GetCurrentModelId()
  else
    return nil, nil
  end
end


f:SetScript("OnShow", function(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)
    local idType, id = self:GetCurrentTypeAndId()
    self:SetId(idType, id, true)

    self:PrepareMountSelectButtons()
    self:RefreshLabels()
  end)


function f:SetId(idType, id, reset)
  -- print("SetId", self.idType, idType, self.id, id, reset)

  if not idType or not id or (not reset and self.idType == idType and self.id == id and self.mountName ~= "") then
    -- print("doing nothing")
    return
  end

  if idType == "mountId" then
    self.mountName, self.mountSpellId, self.mountIcon = C_MountJournal_GetMountInfoByID(id)

  elseif idType == "vehicleId" then
    -- If we are currently in a vehicle, call UnitGUID()
    -- which will store the vehicle name in vehicleIdToName.
    if UnitInVehicle("player") then UnitGUID("vehicle") end
    if cosFix.vehicleIdToName[id] then
      self.mountName = cosFix.vehicleIdToName[id]
    else
      self.mountName = ""
    end

  elseif idType == "modelId" then
    self.mountName = "Unknown Model"
    self.mountIcon = nil
    self.mountSpellId = nil

  else
    return
  end


  if customOffsetFactors[idType][id] then
    self.offsetFactor = customOffsetFactors[idType][id]["factor"]
  elseif cosFix.hardcodedOffsetFactors[idType][id] then
    self.offsetFactor = cosFix.hardcodedOffsetFactors[idType][id]
  else
    self.offsetFactor = 0
  end

  self.idType = idType
  self.id = id

  self:PrepareMountSelectButtons()
  self:RefreshLabels()
end



local mountChangedFrame = CreateFrame("Frame")
mountChangedFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mountChangedFrame:RegisterEvent("UNIT_SPELLCAST_START")
mountChangedFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
mountChangedFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
mountChangedFrame:RegisterEvent("UNIT_ENTERED_VEHICLE")
mountChangedFrame:RegisterEvent("UNIT_EXITING_VEHICLE")
mountChangedFrame:RegisterEvent("UNIT_MODEL_CHANGED")
mountChangedFrame:SetScript("OnEvent", function(self, event, ...)
  if not f:IsShown() then return end

  if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
    if IsMounted() and not UnitOnTaxi("player") then
      f:SetId("mountId", cosFix:GetCurrentMount())
      return
    end
  else
    local unit = ...
    if unit ~= "player" then
      return
    end
  end

  if event == "UNIT_ENTERED_VEHICLE" then
    local _, _, _, _, _, vehicleId = strsplit("-", UnitGUID("vehicle"))
    f:SetId("vehicleId", tonumber(vehicleId))
  elseif event == "UNIT_MODEL_CHANGED" then
    local idType, id = f:GetCurrentTypeAndId()
    f:SetId(idType, id)
  end


  f:RefreshButtons()
end)


-- For debugging.
-- local startup = CreateFrame("Frame")
-- startup:RegisterEvent("PLAYER_ENTERING_WORLD")
-- startup:SetScript("OnEvent", function(self, event, ...)
  -- f:Hide()
  -- f:Show()
-- end)


