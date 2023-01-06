local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):NewAddon(folderName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")


-- Allow access for other addons.
_G.cosFix = cosFix



local _G = _G
local pairs = _G.pairs
local strsplit = _G.strsplit
local math_max = _G.math.max
local math_min = _G.math.min


local GetCameraZoom = _G.GetCameraZoom
local GetTime = _G.GetTime

local DynamicCam = _G.DynamicCam
local dynamicCamLoaded = _G.IsAddOnLoaded("DynamicCam")


-- Needed if un-hooks without reloading are required.
local runhook = false


function cosFix:GetShoulderOffsetZoomFactor(zoomLevel)
  if not dynamicCamLoaded then
    return 1
  else
    return DynamicCam:GetShoulderOffsetZoomFactor(zoomLevel)
  end
end


function cosFix:GetCurrentShoulderOffset()
  if dynamicCamLoaded then
    return DynamicCam.currentShoulderOffset
  else
    return self.db.profile.cvars.test_cameraOverShoulder
  end
end


function cosFix.HyperlinkHandler(...)
  if not runhook then return end

  local _, linkType = ...
  local _, cosFixIdentifier, idType, id = strsplit(":", linkType)

  if cosFixIdentifier == "cosFix" then
    -- No need to hide ItemRefTooltip, because it will not even show up with our modified link.
    cosFix.setFactorFrame:Show()
    cosFix.setFactorFrame:SetId(idType, tonumber(id))
  end
end





function cosFix:CosFixSetCVar(...)
  local variable, value = ...
  
  -- print("CosFixSetCVar", variable, value)
  
  if variable == "test_cameraOverShoulder" then
    cosFix.currentModelFactor = cosFix:CorrectShoulderOffset()
    value = value * cosFix:GetShoulderOffsetZoomFactor(GetCameraZoom()) * cosFix.currentModelFactor
  end
  
  SetCVar(variable, value)
end



-- Set the variables currently in the db.
function cosFix:SetVariables()
  for variable, value in pairs(self.db.profile.cvars) do
    self:CosFixSetCVar(variable, value)
  end
end


function cosFix:DebugPrint(...)
  if self.db.profile.debugOutput then
    self:Print(...)
  end
end

-- Only print this message once.
local lastUnknownModelPrint = GetTime()
function cosFix:DebugPrintUnknownModel(...)
  if lastUnknownModelPrint < GetTime() then
    self:DebugPrint(...)
    lastUnknownModelPrint = GetTime()
  end
end


function cosFix:OnInitialize()

  -- Hide the Blizzard warning.
  UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")

  self:InitializeDatabase()
  self:InitializeOptions()

  -- Initialize customOffsetFactors if not yet present.
  if not customOffsetFactors then
    customOffsetFactors = {
      mountId = {},
      -- TODO: For some reason you need intractably different offsets for Dracthyr.
      -- mountIdDracthyr = {},
      vehicleId = {},
      modelId = {},
    }
  
  -- Or check the variables already stored.
  else
  
     -- Purge possible entries of old addon versions.
    for k in pairs(customOffsetFactors) do
      if not (k == "mountId" or k == "vehicleId" or k == "modelId") then
        customOffsetFactors[k] = nil
      end
    end

    for _, idType in pairs({"mountId", "vehicleId", "modelId"}) do

      -- Initialize empty table if not yet present.
      if not customOffsetFactors[idType] then
        customOffsetFactors[idType] = {}
      
      -- Or purge values that are the same as hardcoded.
      else  
        for k, v in pairs(customOffsetFactors[idType]) do
          if v == self.hardcodedOffsetFactors[idType][k] then
            -- print("Purging", idType, k, "=", v, "from custom factors because it is now hardcoded!")
            customOffsetFactors[idType][k] = nil
          end
        end
      end
      
    end
  end
  
  
  -- Initialize newFactorTriggers if not yet present.
  if not newFactorTriggers then 
    newFactorTriggers = {}
    
    -- TODO: merge hardcoded values.
    
  else
    
    -- TODO: copy hardcoded values.
  
  end
  
  
end



function cosFix:OnEnable()

  if not cosFix.db.profile.enabled then return end


  -- Hide the Blizzard warning.
  UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")

  -- Hooking functions.
  hooksecurefunc(ItemRefTooltip, "SetHyperlink", cosFix.HyperlinkHandler)

  -- Cannot undo hooksecurefunc.
  runhook = true

  self:RegisterEvents()

  -- Must wait before setting variables in the beginning.
  -- Otherwise, the value for test_cameraOverShoulder might not be applied.
  if not dynamicCamLoaded then
    self:ScheduleTimer("SetVariables", 0.1)

    local modelFactor = self:CorrectShoulderOffset()
    if modelFactor == -1 then
      self.currentModelFactor = 1
    else
      self.currentModelFactor = modelFactor
    end
  end

end



function cosFix:OnDisable()

  -- Cannot undo hooksecurefunc.
  runhook = false

  self:UnregisterAllEvents()

  -- Restore all test variables and enable the Blizzard warning.
  ResetTestCvars()
  UIParent:RegisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")

end

















-- To test the SpellActivationOverlayFrame frame!
-- Thanks to Fizzlemizz: https://us.forums.blizzard.com/en/wow/t/are-there-any-areas-that-call-the-extra-and-zone-action-buttons-concurrently/526223/2

local function Overlay(frame)
	local f = CreateFrame("Frame", frame:GetName().."FizzOverlay", UIParent)
	f:SetAllPoints(frame)
	f.t = f:CreateTexture()
	f.t:SetAllPoints()
	f.t:SetTexture("Interface/BUTTONS/WHITE8X8")
	f.t:SetColorTexture(0.2, 0.2, 1, 0.5)
	f.f = f:CreateFontString()
	f.f:SetFont("Fonts/FRIZQT__.TTF", 12)
	f.f:SetJustifyH("CENTER")
	f.f:SetJustifyV("CENTER")
	f.f:SetPoint("CENTER")
	f.f:SetText(frame:GetName())
end








