local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):NewAddon(folderName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")


-- TODO: Build a frame to enter new model factors!
-- https://www.wowace.com/projects/ace3/pages/ace-db-3-0-tutorial
-- https://www.wowace.com/projects/ace3/pages/ace-gui-3-0-widgets


local _G = _G
local pairs = _G.pairs
local strsplit = _G.strsplit



_G.CosFix_OriginalChatFrame_OnHyperlinkShow = _G.ChatFrame_OnHyperlinkShow

function HyperlinkHandler(...)
  local _, linkType = ...
  local cosFixIdentifier, idType, id = strsplit(":", linkType)

  if cosFixIdentifier == "cosFix" then

    print("TODO: Open window to modify", idType, id)

  else
    CosFix_OriginalChatFrame_OnHyperlinkShow(...)
  end
end



_G.CosFix_OriginalSetCVar = _G.SetCVar
local CosFix_OriginalSetCVar = _G.CosFix_OriginalSetCVar

local GetCameraZoom = _G.GetCameraZoom


local dynamicCamLoaded = _G.IsAddOnLoaded("DynamicCam")
local DynamicCam = _G.DynamicCam

local runhook = true
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

  -- print("CosFix_CameraZoomIn")

  -- No idea, why WoW does in-out-in-out with increments 0
  -- after each mouse wheel turn.
  if increments == 0 then return end

  local targetZoom = math.max(0, GetCameraZoom() - increments)

  -- Stop zooming that might currently be in progress from a situation change.
  if dynamicCamLoaded then
    DynamicCam.LibCamera:StopZooming(true)
  end

  local correctedShoulderOffset = cosFix.currentShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(targetZoom) * cosFix.currentModelFactor
  CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)

  return CosFix_OriginalCameraZoomIn(increments, automated)
end

function CosFix_CameraZoomOut(increments, automated)

  -- print("CosFix_CameraZoomOut")

  -- No idea, why WoW does in-out-in-out with increments 0
  -- after each mouse wheel turn.
  if increments == 0 then return end

  targetZoom = math.min(39, GetCameraZoom() + increments)

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

  ChatFrame_OnHyperlinkShow = HyperlinkHandler

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

  ChatFrame_OnHyperlinkShow = CosFix_OriginalChatFrame_OnHyperlinkShow

  self:UnregisterAllEvents()

  -- Restore all test variables and enable the Blizzard warning.
  ResetTestCvars();
  UIParent:RegisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED")

end

