local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)


local _G = _G
local pairs = _G.pairs
local tonumber = _G.tonumber

local C_MountJournal_GetMountInfoByID = _G.C_MountJournal.GetMountInfoByID
local C_MountJournal_GetMountIDs = _G.C_MountJournal.GetMountIDs
local PlaySound = _G.PlaySound

local math_floor = _G.math.floor

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0);
  return math_floor(num * mult + 0.5) / mult;
end


local maxFactor = 10


cosFix.setFactorFrame = CreateFrame("Frame", "cosFix_SetFactorFrame", UIparent, "ButtonFrameTemplate")
local f = cosFix.setFactorFrame
f:SetPoint("TOPLEFT")
ButtonFrameTemplate_HidePortrait(f)
-- SetPortraitToTexture(...)
-- ButtonFrameTemplate_HideAttic(f)
-- ButtonFrameTemplate_HideButtonBar(f)
f:SetFrameStrata("HIGH")
f:SetWidth(430)
f:SetHeight(220)
f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetClampedToScreen(true)
tinsert(UISpecialFrames, "cosFix_SetFactorFrame")
_G[f:GetName().."TitleText"]:SetText("CameraOverShoulderFix - Set Offset Factor")
_G[f:GetName().."TitleText"]:ClearAllPoints()
_G[f:GetName().."TitleText"]:SetPoint("TOPLEFT", 10, -6)


-- Thanks to Vrul: https://www.wowinterface.com/forums/showthread.php?p=335437#post335437
local newSize = 60

local corner = f.NineSlice.BottomLeftCorner
local oldX, oldY = corner:GetSize()
local L, R, T, B = 0, newSize/oldX, 1-newSize/oldY, 1
corner:SetSize(newSize, newSize)
corner:SetTexCoord(L, R, T, B)

local corner = f.NineSlice.BottomRightCorner
local oldX, oldY = corner:GetSize()
local L, R, T, B = 1-newSize/oldX, 1, 1-newSize/oldY, 1
corner:SetSize(newSize, newSize)
corner:SetTexCoord(L, R, T, B)


f.deleteButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.deleteButton:SetPoint("BOTTOMLEFT", 1, 4)
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
    -- Do not allow the same custom value as hardcoded value.
    if f.idType == "vehicleId" then

    elseif f.idType == "mountId" then
      if cosFix.mountIdToShoulderOffsetFactor[f.id] and cosFix.mountIdToShoulderOffsetFactor[f.id] == f.offsetFactor then
        customOffsetFactors[f.idType][f.id] = nil
        f:SetId(f.idType, f.id, true)
        return
      end
    end

    -- Save the custom value.
    local gameAccountInfo = C_BattleNet.GetGameAccountInfoByGUID(UnitGUID("player"))
    local playerName = gameAccountInfo.characterName.."-"..gameAccountInfo.realmName
    local calendarTime = C_DateAndTime.GetCurrentCalendarTime()
    local today = format("%02d-%02d-%d", calendarTime.year, calendarTime.month, calendarTime.monthDay)
    local character = gameAccountInfo.raceName .. " " .. ((UnitSex("player") == 2) and "Male" or "Female")
    customOffsetFactors[f.idType][f.id] = {
      factor     = f.offsetFactor,
      metaData   = f.mountName .. ";" .. today .. ";" .. playerName .. ";" .. character
    }

    f:SetId(f.idType, f.id, true)
  end)
f.saveButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:SetText("Save custom offset factor.")
  end)
f.saveButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)



f.exportButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.exportButton:SetPoint("TOPRIGHT", -25, 0)
f.exportButton:SetText("Export")
f.exportButton:SetWidth(70)
f.exportButton:SetScript("OnClick", function()
    print("Export")
  end)
f.exportButton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:SetText("Export your custom factors to send\nthem to the addon developer!")
  end)
f.exportButton:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)

-- Place the nice button divider!
local layer, subLevel = f.NineSlice.TopRightCorner:GetDrawLayer()
f.exportButton.btnDivLeft = f.NineSlice:CreateTexture("cosFix_btnDivLeft", "BORDER")
f.exportButton.btnDivLeft:SetPoint("RIGHT", f.exportButton, "LEFT", 6, 0)
f.exportButton.btnDivLeft:SetDrawLayer(layer, subLevel+1)
f.exportButton.btnDivLeft:SetAtlas("UI-Frame-BtnDivLeft", true)
local oldX, oldY = f.exportButton.btnDivLeft:GetSize()
local shrinkFactor = 0.83
f.exportButton.btnDivLeft:SetSize(oldX*shrinkFactor, oldY*shrinkFactor)



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
f.coarseSlider:SetWidth(220)
f.coarseSlider:SetHeight(17)
f.coarseSlider:SetMinMaxValues(0, maxFactor)
f.coarseSlider:SetValueStep(0.1)
f.coarseSlider:SetObeyStepOnDrag(true)
 _G[f.coarseSlider:GetName() .. 'Low']:SetText("0")
 _G[f.coarseSlider:GetName() .. 'High']:SetText(maxFactor)
 _G[f.coarseSlider:GetName() .. 'Text']:SetText("")
f.coarseSlider:SetScript("OnValueChanged", function(self, value)
    f.offsetFactor = round(value, 1)
    f:RefreshLabels()
  end)


f.fineSlider = CreateFrame("Slider", "cosFix_fineSlider", f.coarseSlider, "OptionsSliderTemplate")
f.fineSlider:SetPoint("TOP", 0, -35)
f.fineSlider:SetWidth(220)
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
      f.offsetFactor = round(f.coarseSlider:GetValue() + value, 3)
    end
    f:RefreshLabels()
  end)


f.valueBox = CreateFrame("EditBox", nil, f.Inset, "InputBoxTemplate")
f.valueBox:SetPoint("TOPRIGHT", -14, -62)
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
    f.offsetFactor = round(self.lastValidValue, 3)
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
    f.offsetFactor = round(f.valueBox.lastValidValue, 3)
    f:RefreshLabels()
  end)


f.mountButton = CreateFrame("CheckButton", nil, f.Inset)
f.mountButton:SetPoint("TOPLEFT", 20, -62)
f.mountButton:SetSize(50, 50)
f.mountButton:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square")
f.mountButton:SetCheckedTexture("Interface\\Buttons\\CheckButtonHilight")
f.mountButton:SetScript("OnClick", function(self)
    C_MountJournal.SummonByID(f.id)
    _, _, _, _, _, _, _, _, spellId = UnitCastingInfo("player")
    if spellId then
      if spellId == f.mountSpellId then
        self:SetChecked(true)
      else
        self:SetChecked(false)
      end
    end
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
);
f.onlyCustomCheckBox:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT", 0, -20)
    GameTooltip:SetText("Only skip through mounts for which\nyou have set a custom factor.")
  end)
f.onlyCustomCheckBox:SetScript("OnLeave", function(self)
    GameTooltip:Hide()
  end)







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

      -- If no mount is selected, take the first usable mounts.
      if f.idType ~= "mountId" or not f.id then
        if not f.nextMountId then f.nextMountId = v end
        if not f.prevMountId then f.prevMountId = v end

        if not customOffsetFactors["mountId"][v] and not cosFix.mountIdToShoulderOffsetFactor[v] then
          f.nextUnknownMountId = v
        end

      else
        if takeNext and not f.nextMountId then f.nextMountId = v end

        if not customOffsetFactors["mountId"][v] and not cosFix.mountIdToShoulderOffsetFactor[v] then
          if not firstUnknownMountId then firstUnknownMountId = v end
          if takeNext and not f.nextUnknownMountId then f.nextUnknownMountId = v end
        end

        if f.id == v then
          takeNext = true
          if lastMountId then f.prevMountId = lastMountId end
        end

        lastMountId = v
      end
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
    self.mountButton:Hide()
    self.coarseSlider:Hide()
    self.fineSlider:Hide()
    self.valueBox:Hide()
    self.okButton:Hide()
    self.minusButton:Hide()
    self.plusButton:Hide()
    return
  else
    self.mountButton:Show()
    self.coarseSlider:Show()
    self.fineSlider:Show()
    self.valueBox:Show()
    self.minusButton:Show()
    self.plusButton:Show()
  end

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


  if self.idType == "mountId" then
    self.mountButton:Show()
    self.mountButton:SetNormalTexture(self.mountIcon)

    _, _, _, _, _, _, _, _, spellId = UnitCastingInfo("player")
    if (IsMounted() and self.id == cosFix:GetCurrentMount()) or (spellId and spellId == self.mountSpellId) then
      self.mountButton:SetChecked(true)
    else
      self.mountButton:SetChecked(false)
    end
  else
    self.mountButton:Hide()
  end


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
  elseif (not cosFix.mountIdToShoulderOffsetFactor[self.id] and self.offsetFactor ~= 0) or
         (    cosFix.mountIdToShoulderOffsetFactor[self.id] and self.offsetFactor ~= cosFix.mountIdToShoulderOffsetFactor[self.id]) then
    self.saveButton:Enable()
    self.resetButton:Enable()
  else
    self.saveButton:Disable()
    self.resetButton:Disable()
  end

end





f.instructionTextLabel = f:CreateFontString(nil, "HIGH")
f.instructionTextLabel:SetFont("Fonts\\FRIZQT__.TTF", 12)
f.instructionTextLabel:SetTextColor(0.8, 0.8, 0.8)
f.instructionTextLabel:SetPoint("TOPLEFT", f.TopTileStreaks, "TOPLEFT", 10, -10)
f.instructionTextLabel:SetPoint("TOPRIGHT", f.TopTileStreaks, "TOPRIGHT", -10, -10)
f.instructionTextLabel:SetJustifyH("LEFT")
f.instructionTextLabel:SetText("Mount and dismount repeatedly to find the ideal factor for a mount or vehicle. See the addon web page for a video tutorial.")

f.mountNameLabel = f:CreateFontString(nil, "HIGH")
f.mountNameLabel:SetFont("Fonts\\FRIZQT__.TTF", 14)
f.mountNameLabel:SetTextColor(1.0, 0.6, 0.0)
f.mountNameLabel:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 13, -14)
f.mountNameLabel:SetPoint("TOPRIGHT", f.Inset, "TOPRIGHT", -6, -14)
f.mountNameLabel:SetJustifyH("LEFT")

f.storeStatusLabel = f:CreateFontString(nil, "HIGH")
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
    return
  end

  self.mountNameLabel:SetText(self.mountName .. " (ID: " .. self.id .. ")")

  if self.offsetFactor ~= self.valueBox:GetText() then
    self.valueBox:SetText(self.offsetFactor)
  end

  if self.idType == "vehicleId" then

  elseif self.idType == "mountId" then
    local storeStatus = ""
    if customOffsetFactors[self.idType][self.id] then
      storeStatus = "Custom factor ("..customOffsetFactors[self.idType][self.id]["factor"]..")"
      if cosFix.mountIdToShoulderOffsetFactor[self.id] then
        storeStatus = storeStatus .. " overriding hardcoded factor ("..cosFix.mountIdToShoulderOffsetFactor[self.id]..")"
      end
    elseif cosFix.mountIdToShoulderOffsetFactor[self.id] then
      storeStatus = "Hardcoded factor ("..cosFix.mountIdToShoulderOffsetFactor[self.id]..")"
    else
      storeStatus = "No factor available"
    end
    self.storeStatusLabel:SetText(storeStatus..".")
  end

  -- Got to remember the original offsetFactor, because when we do coarseSlider:SetValue() it
  -- will change self.offsetFactor.
  local originalOffsetFactor = f.offsetFactor
  local roundedCoarseSlider = round(self.coarseSlider:GetValue(), 1)
  if originalOffsetFactor < roundedCoarseSlider - 0.5 or originalOffsetFactor > roundedCoarseSlider + 0.5 then
    local roundedOffsetFactor = round(originalOffsetFactor, 1)
    self.coarseSlider:SetValue(roundedOffsetFactor)
    self.fineSlider:SetValue(originalOffsetFactor - roundedOffsetFactor)
  else
    -- Only needed for the initial call!
    self.coarseSlider:SetValue(roundedCoarseSlider)
    self.fineSlider:SetValue(originalOffsetFactor - roundedCoarseSlider)
  end

  self:RefreshButtons()

  cosFix:setDelayedShoulderOffset()
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
    cosFix:setDelayedShoulderOffset()
  end)


f:SetScript("OnShow", function(self)
    PlaySound(SOUNDKIT.IG_CHARACTER_INFO_OPEN)

    if IsMounted() and not UnitOnTaxi("player") then
      f:SetId("mountId", cosFix:GetCurrentMount(), true)
    end

    cosFix:setDelayedShoulderOffset()
    self:PrepareMountSelectButtons()
    self:RefreshLabels()
  end)


function f:SetId(idType, id, reset)
  -- print("SetId", self.idType, idType, self.id, id)

  if not reset and self.idType == idType and self.id == id then return end

  self.idType = idType
  self.id = id

  if idType == "vehicleId" then
    self.mountName = GetUnitName("vehicle", false)

  elseif idType == "mountId" then
    self.mountName, self.mountSpellId, self.mountIcon = C_MountJournal_GetMountInfoByID(id)

    if customOffsetFactors[idType][id] then
      self.offsetFactor = customOffsetFactors[idType][id]["factor"]
    elseif cosFix.mountIdToShoulderOffsetFactor[id] then
      self.offsetFactor = cosFix.mountIdToShoulderOffsetFactor[id]
    else
      self.offsetFactor = 0
    end
  end

  self:PrepareMountSelectButtons()
  self:RefreshLabels()
end



local mountChangedFrame = CreateFrame("Frame")
mountChangedFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mountChangedFrame:RegisterEvent("UNIT_SPELLCAST_START")
mountChangedFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
mountChangedFrame:SetScript("OnEvent", function(self, event, ...)
  if not self:IsShown() then return end

  if event == "PLAYER_MOUNT_DISPLAY_CHANGED" and IsMounted() and not UnitOnTaxi("player") then
    f:SetId("mountId", cosFix:GetCurrentMount())
  else
    local unit = ...
    if unit ~= "player" then return end
  end

  f:RefreshButtons()
end)




-- -- For debugging.
-- local startup = CreateFrame("Frame")
-- startup:RegisterEvent("PLAYER_ENTERING_WORLD")
-- startup:SetScript("OnEvent", function(self, event, ...)
  -- f:Hide()
  -- f:Show()
-- end)

