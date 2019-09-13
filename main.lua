local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):NewAddon(folderName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")


-- TODO: Build a frame to enter new model factors!
-- https://www.wowace.com/projects/ace3/pages/ace-db-3-0-tutorial
-- https://www.wowace.com/projects/ace3/pages/ace-gui-3-0-widgets


local _G = _G
local pairs = _G.pairs

_G.CosFix_OriginalSetCVar = _G.SetCVar
local CosFix_OriginalSetCVar = _G.CosFix_OriginalSetCVar

local GetCameraZoom = _G.GetCameraZoom

local DynamicCam = _G.DynamicCam

local dynamicCamLoaded = _G.IsAddOnLoaded("DynamicCam")



local runhook = true
local function CosFixSetCVar(...)

  if not runhook then return end

  local variable, value = ...

  if variable == "test_cameraOverShoulder" then

    local modelFactor = cosFix:CorrectShoulderOffset(value)
    -- setCVar should always work. For unknown model IDs we use the default 1.
    if modelFactor == -1 then
      modelFactor = 1
    end

    value = value * cosFix:GetShoulderOffsetZoomFactor(GetCameraZoom()) * modelFactor

    CosFix_OriginalSetCVar(variable, value)
  end

end


-- Store original camera zoom functions.
-- If DynamicCam has reative zoom enabled, these have already been
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
local targetZoom;
function CosFix_CameraZoomIn(increments, automated)

  -- No idea, why WoW does in-out-in-out with increments 0
  -- after each mouse wheel turn.
  if increments == 0 then return end

  local targetZoom = math.max(0, GetCameraZoom() - increments)

  local userSetShoulderOffset = cosFix.db.profile.cvars.test_cameraOverShoulder
  if dynamicCamLoaded then
    userSetShoulderOffset = cosFix.currentShoulderOffset
  end

  local modelFactor = cosFix:CorrectShoulderOffset(userSetShoulderOffset)

  -- Zooming should always have the intended effect. For unknown model IDs we use the default 1.
  if modelFactor == -1 then
    modelFactor = 1
  end

  local correctedShoulderOffset = userSetShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(targetZoom) * modelFactor
  CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)


  return CosFix_OriginalCameraZoomIn(increments, automated)
end


function CosFix_CameraZoomOut(increments, automated)

  -- No idea, why WoW does in-out-in-out with increments 0
  -- after each mouse wheel turn.
  if increments == 0 then return end

  targetZoom = math.min(39, GetCameraZoom() + increments)

  local userSetShoulderOffset = cosFix.db.profile.cvars.test_cameraOverShoulder
  if dynamicCamLoaded then
    userSetShoulderOffset = cosFix.currentShoulderOffset
  end

  local modelFactor = cosFix:CorrectShoulderOffset(userSetShoulderOffset)

  -- Zooming should always have the intended effect. For unknown model IDs we use the default 1.
  if modelFactor == -1 then
    modelFactor = 1
  end

  local correctedShoulderOffset = userSetShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(targetZoom) * modelFactor
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
    CosFixSetCVar(variable, value)
  end
end



function cosFix:DebugPrint(...)
  if self.db.profile.debugOutput then
    self:Print(...)
  end
end




function cosFix:OnInitialize()

  -- Hide the Blizzard warning.
  UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")

  self:InitializeDatabase()
  self:InitializeOptions()

  hooksecurefunc("SetCVar", CosFixSetCVar)
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

  runhook = true


  self:RegisterEvents()

  -- Must wait before setting variables in the beginning.
  -- Otherwise, the value for test_cameraOverShoulder might not be applied.
  if not dynamicCamLoaded then
    self:ScheduleTimer("SetVariables", 0.1)

    self.currentShoulderOffset = self.db.profile.cvars.test_cameraOverShoulder
    self.shoulderOffsetModelFactor = self:CorrectShoulderOffset(self.currentShoulderOffset)
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

