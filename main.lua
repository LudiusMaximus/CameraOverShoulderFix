local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):NewAddon(folderName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")


-- Allow access for other addons.
_G.cosFix = cosFix



local _G = _G
local pairs = _G.pairs
local strsplit = _G.strsplit
local math_max = _G.math.max
local math_min = _G.math.min


_G.CosFix_OriginalSetCVar = _G.SetCVar
local CosFix_OriginalSetCVar = _G.CosFix_OriginalSetCVar

local GetCameraZoom = _G.GetCameraZoom
local GetTime = _G.GetTime

local DynamicCam = _G.DynamicCam
local dynamicCamLoaded = _G.IsAddOnLoaded("DynamicCam")


-- Needed if un-hooks without reloading are required.
local runhook = false


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



local function CosFixSetCVar(...)
  if not runhook then return end

  local variable, value = ...
  if variable == "test_cameraOverShoulder" then

    cosFix.currentShoulderOffset = value

    local modelFactor = cosFix:CorrectShoulderOffset()
    -- setCVar should always work. For unknown model IDs we use the default 1.
    if modelFactor == -1 then
      modelFactor = 1
    end

    cosFix.currentModelFactor = modelFactor

    value = value * cosFix:GetShoulderOffsetZoomFactor(GetCameraZoom()) * modelFactor
    CosFix_OriginalSetCVar(variable, value)
  end
end
hooksecurefunc("SetCVar", CosFixSetCVar)
-- TODO: This is good, because if other addons set a deliberate test_cameraOverShoulder
-- value, the correction will be applied.
-- On the other hand, if some addon does
-- SetCVar("test_cameraOverShoulder", GetCVar("test_cameraOverShoulder"))
-- expecting it to not change anything, we have a problem, because
-- the correction will be applied repeatedly...
-- What is better?


-- Store original camera zoom functions.
-- If DynamicCam has reactive zoom enabled, these have already been
-- overridden, we will get the real original functions below by
-- temporarily deactivating reactive zoom.
local CosFix_OriginalCameraZoomIn = CameraZoomIn
local CosFix_OriginalCameraZoomOut = CameraZoomOut

if dynamicCamLoaded then
  -- Deactivate reactive zoom to restore original CameraZoomIn and CameraZoomOut.
  DynamicCam:ReactiveZoomOff()

  -- Store the original CameraZoomIn and CameraZoomOut.
  CosFix_OriginalCameraZoomIn = CameraZoomIn
  CosFix_OriginalCameraZoomOut = CameraZoomOut

  -- Reactivate reactive zoom if necessary.
  if DynamicCam.db.profile.reactiveZoom.enabled then
    DynamicCam:ReactiveZoomOn()
  end

end



-- Hooking functions for non-reactive zoom.
local targetZoom
function CosFix_CameraZoomIn(increments, automated)

  -- print("CosFix_CameraZoomIn", increments)

  -- No idea, why WoW does in-out-in-out with increments 0
  -- after each mouse wheel turn.
  if increments == 0 then return end

  local targetZoom = math_max(0, GetCameraZoom() - increments)

  -- Stop zooming that might currently be in progress from a situation change.
  if dynamicCamLoaded then
    DynamicCam.LibCamera:StopZooming(true)
  end

  local correctedShoulderOffset = cosFix.currentShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(targetZoom) * cosFix.currentModelFactor
  CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)

  return CosFix_OriginalCameraZoomIn(increments, automated)
end

function CosFix_CameraZoomOut(increments, automated)

  -- print("CosFix_CameraZoomOut", increments)

  -- No idea, why WoW does in-out-in-out with increments 0
  -- after each mouse wheel turn.
  if increments == 0 then return end

  targetZoom = math_min(39, GetCameraZoom() + increments)

  -- Stop zooming that might currently be in progress from a situation change.
  if dynamicCamLoaded then
    DynamicCam.LibCamera:StopZooming(true)
  end

  local correctedShoulderOffset = cosFix.currentShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(targetZoom) * cosFix.currentModelFactor
  CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)

  return CosFix_OriginalCameraZoomOut(increments, automated)
end



function cosFix:NonReactiveZoomOn()
  CameraZoomIn  = CosFix_CameraZoomIn
  CameraZoomOut = CosFix_CameraZoomOut
end

function cosFix:NonReactiveZoomOff()
  CameraZoomIn  = CosFix_OriginalCameraZoomIn
  CameraZoomOut = CosFix_OriginalCameraZoomOut
end


-- Set the variables currently in the db.
function cosFix:SetVariables()
  for variable, value in pairs(self.db.profile.cvars) do
    SetCVar(variable, value)
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

  -- Initialize custom offset factors variable.
  if not customOffsetFactors then
    customOffsetFactors = {
      mountId = {},
      vehicleId = {},
    }
  end

end



function cosFix:OnEnable()

  -- Hide the Blizzard warning.
  UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")

  -- Hooking functions.
  if dynamicCamLoaded and DynamicCam.db.profile.reactiveZoom.enabled then
    DynamicCam:ReactiveZoomOn()
  else
    self:NonReactiveZoomOn()
  end

  hooksecurefunc(ItemRefTooltip, "SetHyperlink", cosFix.HyperlinkHandler)

  -- Cannot undo hooksecurefunc.
  runhook = true

  self:RegisterEvents()

  -- Must wait before setting variables in the beginning.
  -- Otherwise, the value for test_cameraOverShoulder might not be applied.
  if not dynamicCamLoaded then
    self:ScheduleTimer("SetVariables", 0.1)

    self.currentShoulderOffset = self.db.profile.cvars.test_cameraOverShoulder

    local modelFactor = self:CorrectShoulderOffset()
    if modelFactor == -1 then
      self.currentModelFactor = 1
    else
      self.currentModelFactor = modelFactor
    end
  end

end



function cosFix:OnDisable()

  -- Unhooking functions.
  if not dynamicCamLoaded or not DynamicCam.db.profile.reactiveZoom.enabled then
    self:NonReactiveZoomOff()
  end

  -- Cannot undo hooksecurefunc.
  runhook = false

  self:UnregisterAllEvents()

  -- Restore all test variables and enable the Blizzard warning.
  ResetTestCvars();
  UIParent:RegisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")

end












