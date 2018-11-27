local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):NewAddon(folderName, "AceConsole-3.0", "AceEvent-3.0", "AceTimer-3.0")



-- Hooking SetCVar().
local OriginalSetCVar = SetCVar

function CosFixSetCVar(...)
  local variable, value = ...
  
  if (variable == "test_cameraOverShoulder") then
    -- print("CosFixSetCVar()", value)
    value = value * cosFix:CorrectShoulderOffset(value) * cosFix:GetShoulderOffsetZoomFactor(GetCameraZoom())
    -- print("CosFixSetCVar()", value)
  end
  
  OriginalSetCVar(variable, value)
end

-- Access function for OriginalSetCVar().
function cosFix:OriginalSetCVar(variable, value)
  OriginalSetCVar(variable, value)
end



-- Hooking CameraZoomIn() and CameraZoomOut().
local targetZoom;
local OriginalCameraZoomIn = CameraZoomIn;
local OriginalCameraZoomOut = CameraZoomOut;

function CosFixCameraZoomIn(...)

    local increments = ...;
    local currentZoom = GetCameraZoom();

    -- Determine final zoom level.
    if (targetZoom and targetZoom > currentZoom) then
        targetZoom = nil;
    end
    targetZoom = targetZoom or currentZoom;
    targetZoom = math.max(0, targetZoom - increments);

    local userSetShoulderOffset = cosFix.db.profile.cvars["test_cameraOverShoulder"];
    local correctedShoulderOffset = userSetShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(targetZoom) * cosFix:CorrectShoulderOffset(userSetShoulderOffset);
    OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset);

    return OriginalCameraZoomIn(...);
end


function CosFixCameraZoomOut(...)

    local increments = ...;
    local currentZoom = GetCameraZoom();

    -- Determine final zoom level.
    if (targetZoom and targetZoom < currentZoom) then
        targetZoom = nil;
    end
    targetZoom = targetZoom or currentZoom;
    targetZoom = math.min(39, targetZoom + increments);

    local userSetShoulderOffset = cosFix.db.profile.cvars["test_cameraOverShoulder"];
    local correctedShoulderOffset = userSetShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(targetZoom) * cosFix:CorrectShoulderOffset(userSetShoulderOffset);
    OriginalSetCVar("test_cameraOverShoulder", correctedShoulderOffset);

    return OriginalCameraZoomOut(...);
end




-- Set the variables currently in the db.
function cosFix:SetVariables()
  -- TODO: Only if DyncamicCam is not loaded??
  for variable, value in pairs(self.db.profile.cvars) do
    SetCVar(variable, value)
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
  CameraZoomIn = CosFixCameraZoomIn
  CameraZoomOut = CosFixCameraZoomOut

  self:RegisterEvents()
    
  -- Must wait before setting variables in the beginning.
  -- Otherwise, the value for test_cameraOverShoulder might not be applied.
  self:ScheduleTimer("SetVariables", 0.1)
  
end


function cosFix:OnDisable()

  -- Unhooking functions.
  SetCVar = OriginalSetCVar
  CameraZoomIn = OriginalCameraZoomIn
  CameraZoomOut = OriginalCameraZoomOut
  
  self:UnregisterAllEvents()
  
  -- Restore all test variables and enable the Blizzard warning.
  ResetTestCvars();
  UIParent:RegisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED");
  
end




