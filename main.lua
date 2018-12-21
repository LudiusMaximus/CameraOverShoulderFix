local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):NewAddon(folderName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")



-- Hooking SetCVar().
CosFix_OriginalSetCVar = SetCVar

function CosFixSetCVar(...)
  local variable, value = ...
  
  if (variable == "test_cameraOverShoulder") then
    value = value * cosFix:CorrectShoulderOffset(value) * cosFix:GetShoulderOffsetZoomFactor(GetCameraZoom())
  end
  
  CosFix_OriginalSetCVar(variable, value)
end





-- Store original camera zoom functions.
CosFix_OriginalCameraZoomIn = CameraZoomIn
CosFix_OriginalCameraZoomOut = CameraZoomOut

-- These might already have been changed to reactive zoom by DynamicCam.
if IsAddOnLoaded("DynamicCam") then
  DynamicCam:ReactiveZoomOff()
  
  CosFix_OriginalCameraZoomIn = CameraZoomIn
  CosFix_OriginalCameraZoomOut = CameraZoomOut
  
  if (DynamicCam.db.profile.reactiveZoom.enabled) then
    DynamicCam:ReactiveZoomOn()
  end
end






-- Hooking functions for non-reactive zoom.
local targetZoom;
function CosFix_CameraZoomIn(...)

  local increments = ...
  local currentZoom = GetCameraZoom()

  -- Determine final zoom level.
  if (targetZoom and targetZoom > currentZoom) then
    targetZoom = nil
  end
  targetZoom = targetZoom or currentZoom
  targetZoom = math.max(0, targetZoom - increments)
  
  local userSetShoulderOffset = cosFix.db.profile.cvars.test_cameraOverShoulder
  if IsAddOnLoaded("DynamicCam") then
    userSetShoulderOffset = cosFix:getUserSetShoulderOffset()
  end
  local correctedShoulderOffset = userSetShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(targetZoom) * cosFix:CorrectShoulderOffset(userSetShoulderOffset)
  CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)

  return CosFix_OriginalCameraZoomIn(...)
end


function CosFix_CameraZoomOut(...)

  local increments = ...
  local currentZoom = GetCameraZoom()

  -- Determine final zoom level.
  if (targetZoom and targetZoom < currentZoom) then
    targetZoom = nil
  end
  targetZoom = targetZoom or currentZoom;
  targetZoom = math.min(39, targetZoom + increments)

  local userSetShoulderOffset = cosFix.db.profile.cvars.test_cameraOverShoulder
  if IsAddOnLoaded("DynamicCam") then
    userSetShoulderOffset = cosFix:getUserSetShoulderOffset()
  end
  local correctedShoulderOffset = userSetShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(targetZoom) * cosFix:CorrectShoulderOffset(userSetShoulderOffset)
  CosFix_OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset)

  return CosFix_OriginalCameraZoomOut(...)
end



function cosFix:NonReactiveZoomOn()
  CameraZoomIn = CosFix_CameraZoomIn
  CameraZoomOut = CosFix_CameraZoomOut
end



-- Set the variables currently in the db.
function cosFix:SetVariables()
  for variable, value in pairs(self.db.profile.cvars) do
    CosFixSetCVar(variable, value)
  end
end



function cosFix:DebugPrint(...)
  if (self.db.profile.debugOutput) then
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
  SetCVar = CosFixSetCVar
  
  if (IsAddOnLoaded("DynamicCam") and (DynamicCam.db.profile.reactiveZoom.enabled)) then
    DynamicCam:ReactiveZoomOn()
  else
    self:NonReactiveZoomOn()
  end
  

  self:RegisterEvents()
    
  -- Must wait before setting variables in the beginning.
  -- Otherwise, the value for test_cameraOverShoulder might not be applied.
  if not IsAddOnLoaded("DynamicCam") then
    self:ScheduleTimer("SetVariables", 0.1)
  end
  
end


function cosFix:OnDisable()

  -- Unhooking functions.
  SetCVar       = CosFix_OriginalSetCVar
  CameraZoomIn  = CosFix_OriginalCameraZoomIn
  CameraZoomOut = CosFix_OriginalCameraZoomOut
  
  self:UnregisterAllEvents()
  
  -- Restore all test variables and enable the Blizzard warning.
  ResetTestCvars();
  UIParent:RegisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED");
  
end




