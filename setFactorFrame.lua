local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)


local _G = _G
local pairs = _G.pairs
local tonumber = _G.tonumber

local C_MountJournal_GetMountInfoByID = _G.C_MountJournal.GetMountInfoByID

local math_floor = _G.math.floor

local function round(num, numDecimalPlaces)
  local mult = 10^(numDecimalPlaces or 0);
  return math_floor(num * mult + 0.5) / mult;
end


local maxFactor = 10


-- To test recipe tooltips by item id:
cosFix.setFactorFrame = CreateFrame("Frame", "cosFix_SetFactorFrame", UIparent, "ButtonFrameTemplate")
local f = cosFix.setFactorFrame

f:SetPoint("TOPLEFT")

ButtonFrameTemplate_HidePortrait(f)
-- ButtonFrameTemplate_HideAttic(f)
-- ButtonFrameTemplate_HideButtonBar(f)

f:SetFrameStrata("HIGH")

f:SetWidth(430)
f:SetHeight(200)

f:SetMovable(true)
f:EnableMouse(true)
f:RegisterForDrag("LeftButton")
f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", f.StopMovingOrSizing)
f:SetClampedToScreen(true)

tinsert(UISpecialFrames, "cosFix_SetFactorFrame")

_G[f:GetName().."TitleText"]:SetText("CameraOverShoulderFix - Set Offset Factor")





f.cancelButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.cancelButton:SetPoint("BOTTOMLEFT", 1, 4)
f.cancelButton:SetText("Cancel")
f.cancelButton:SetWidth(90)
f.cancelButton:SetScript("OnClick", function()
    print("Cancel")
    f:Hide()
  end)

f.resetButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.resetButton:SetPoint("BOTTOM", 0, 4)
f.resetButton:SetText("Reset")
f.resetButton:SetWidth(90)
f.resetButton:SetScript("OnClick", function()
    print("Reset")
  end)

f.saveButton = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
f.saveButton:SetPoint("BOTTOMRIGHT", -1, 4)
f.saveButton:SetText("Save")
f.saveButton:SetWidth(90)
f.saveButton:SetScript("OnClick", function()

    local gameAccountInfo = C_BattleNet.GetGameAccountInfoByGUID(UnitGUID("player"))
    local playerName = gameAccountInfo.characterName.."-"..gameAccountInfo.realmName
    local calendarTime = C_DateAndTime.GetCurrentCalendarTime()
    local today = format("%02d-%02d-%d", calendarTime.year, calendarTime.month, calendarTime.monthDay)
    local character = gameAccountInfo.raceName .. " " .. ((UnitSex("player") == 2) and "Male" or "Female")
    customOffsetFactors[f.idType][f.id] = {
      factor     = f.offsetFactor,
      metaData   = f.mountName .. ";" .. today .. ";" .. playerName .. ";" .. character
    }
    
    f.RefreshLabels()
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

f.coarseSlider:SetPoint("TOP", 0, -36)
f.coarseSlider:SetWidth(200)
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
-- f.coarseSlider:SetScript("OnEnter", function(self)
    -- GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    -- GameTooltip:SetText("Coarse Tuning")
  -- end)
-- f.coarseSlider:SetScript("OnLeave", function(self)
    -- GameTooltip:Hide()
  -- end)




f.fineSlider = CreateFrame("Slider", "cosFix_fineSlider", f.coarseSlider, "OptionsSliderTemplate")

f.fineSlider:SetPoint("TOP", 0, -35)
f.fineSlider:SetWidth(200)
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
-- f.fineSlider:SetScript("OnEnter", function(self)
    -- GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
    -- GameTooltip:SetText("Fine Tuning")
  -- end)
-- f.fineSlider:SetScript("OnLeave", function(self)
    -- GameTooltip:Hide()
  -- end)



f.valueBox = CreateFrame("EditBox", "cosFix_valueBox", f.Inset, "InputBoxTemplate")
f.valueBox:SetPoint("TOPRIGHT", -24, -43)
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
-- f.valueBox:SetScript("OnEnter", function(self)
    -- GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    -- GameTooltip:SetText("Ultra Fine Tuning")
  -- end)
-- f.valueBox:SetScript("OnLeave", function(self)
    -- GameTooltip:Hide()
  -- end)

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

f.applyButton = CreateFrame("Button", nil, f.valueBox, "UIPanelButtonTemplate")
f.applyButton:SetPoint("BOTTOM", f.valueBox, "TOP", -2, 0)
f.applyButton:SetText("Apply")
f.applyButton:SetWidth(58)
f.applyButton:SetScript("OnClick", function()
    if f.valueBox.lastValidValue > maxFactor then
      f.valueBox.lastValidValue = maxFactor
    end
    f.offsetFactor = round(f.valueBox.lastValidValue, 3)
    f:RefreshLabels()
  end)


f.mountButton = CreateFrame("Button", nil, f.Inset, "UIPanelButtonTemplate")
f.mountButton:SetPoint("TOPLEFT", 10, -43)
f.mountButton:SetWidth(80)
f.mountButton:SetScript("OnClick", function()
    if f.idType == "mountId" then
      C_MountJournal.SummonByID(f.id)
    end
  end)


function f:RefreshButtons()

  if self.valueBox.lastValidValue ~= self.offsetFactor then
    self.applyButton:Show()
    self.minusButton:Disable()
    self.plusButton:Disable()
  else
    self.applyButton:Hide()

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


  if f.idType == "mountId" and f.id == cosFix:GetCurrentMount() and IsMounted() then
    f.mountButton:SetText("Dismount")
  else
    f.mountButton:SetText("Mount")
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
f.mountNameLabel:SetPoint("TOPLEFT", f.Inset, "TOPLEFT", 13, -10)
f.mountNameLabel:SetPoint("TOPRIGHT", f.Inset, "TOPRIGHT", -6, -10)
f.mountNameLabel:SetJustifyH("LEFT")
f.mountNameLabel:SetText("No mount or vehicle detected.")


function f:RefreshLabels()
  -- print("RefreshLabels", self.mountName, self.offsetFactor)
  -- print(self.coarseSlider:GetValue(), self.fineSlider:GetValue(), self.valueBox:GetText())

  self.mountNameLabel:SetText(self.mountName)

  if self.offsetFactor ~= self.valueBox:GetText() then
    self.valueBox:SetText(self.offsetFactor)
  end

  local roundedCoarseSlider = round(self.coarseSlider:GetValue(), 1)

  if self.offsetFactor < roundedCoarseSlider - 0.5 or self.offsetFactor > roundedCoarseSlider + 0.5 then

    local roundedOffsetFactor = round(self.offsetFactor, 1)
    self.coarseSlider:SetValue(roundedOffsetFactor)
    self.fineSlider:SetValue(self.offsetFactor - roundedOffsetFactor)

  else
    -- Only needed for the initial call!
    self.coarseSlider:SetValue(roundedCoarseSlider)
    self.fineSlider:SetValue(self.offsetFactor - roundedCoarseSlider)
  end

  self:RefreshButtons()

  if cosFix.currentModelFactor ~= self.offsetFactor then
    cosFix:setDelayedShoulderOffset()
  end

end




f.idType = nil
f.id = nil
f.mountName = nil

f.offsetFactor = nil



f:SetScript("OnHide", function(self)
    -- To make this conditional we would have to call CorrectShoulderOffset() anyway.
    -- So we can just as well always call it.
    cosFix:setDelayedShoulderOffset()
  end)


f:SetScript("OnShow", function(self)
    if cosFix.currentModelFactor ~= self.offsetFactor then
      cosFix:setDelayedShoulderOffset()
    end
  end)


function f:SetId(idType, id)
  -- print("SetId", self.idType, idType, self.id, id)

  if self.idType == idType and self.id == id then return end

  self.idType = idType
  self.id = id

  if idType == "vehicleId" then
    self.mountName = GetUnitName("vehicle", false)

  elseif idType == "mountId" then
    self.mountName = C_MountJournal_GetMountInfoByID(id)
    if cosFix.mountIdToShoulderOffsetFactor[id] then
      self.offsetFactor = cosFix.mountIdToShoulderOffsetFactor[id]
    else
      self.offsetFactor = 0
    end
  end

  self:RefreshLabels()
end





local mountChangedFrame = CreateFrame("Frame")
mountChangedFrame:RegisterEvent("PLAYER_MOUNT_DISPLAY_CHANGED")
mountChangedFrame:SetScript("OnEvent", function(self, event, ...)

  if IsMounted() and not UnitOnTaxi("player") then
    f:SetId("mountId", cosFix:GetCurrentMount())
  else
    f:RefreshButtons()
  end

end)


