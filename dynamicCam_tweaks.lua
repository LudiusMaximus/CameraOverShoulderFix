local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)



if IsAddOnLoaded("DynamicCam") then


  -------------------------------------------------------------------
  -- Copying local functions of DynamicCam to make slight changes. --
  -------------------------------------------------------------------


  local LibCamera = LibStub("LibCamera-1.0");
  local LibEasing = LibStub("LibEasing-1.0");

  local function round(num, numDecimalPlaces)
      local mult = 10^(numDecimalPlaces or 0);
      return math.floor(num * mult + 0.5) / mult;
  end


  ----------------------
  -- SHOULDER OFFSET  --
  ----------------------
  local easeShoulderOffsetHandle;

  local function setShoulderOffset(offset)
      if (offset and type(offset) == 'number') then
          CosFix_OriginalSetCVar("test_cameraOverShoulder", offset)    -- Changed line here!
      end
  end

  local function stopEasingShoulderOffset()
      if (easeShoulderOffsetHandle) then
          LibEasing:StopEasing(easeShoulderOffsetHandle);
          easeShoulderOffsetHandle = nil;
      end
  end

  local function easeShoulderOffset(endValue, duration, easingFunc)
      stopEasingShoulderOffset();

      local oldOffest = tonumber(GetCVar("test_cameraOverShoulder"));
      easeShoulderOffsetHandle = LibEasing:Ease(setShoulderOffset, oldOffest, endValue, duration, easingFunc);

      DynamicCam:DebugPrint("test_cameraOverShoulder", oldOffest, "->", endValue);
  end



  -------------------
  -- REACTIVE ZOOM --
  -------------------
  local targetZoom;
  local oldCameraZoomIn = CosFix_CameraZoomIn;       -- Changed line here!
  local oldCameraZoomOut = CosFix_CameraZoomOut;     -- Changed line here!

  local function clearTargetZoom(wasInterrupted)
      if (not wasInterrupted) then
          targetZoom = nil;
      end
  end

  local function ReactiveZoom(zoomIn, increments, automated)

      increments = increments or 1;

      if (not automated and increments == 1) then

          local currentZoom = GetCameraZoom();

          local addIncrementsAlways = DynamicCam.db.profile.reactiveZoom.addIncrementsAlways;
          local addIncrements = DynamicCam.db.profile.reactiveZoom.addIncrements;
          local maxZoomTime = DynamicCam.db.profile.reactiveZoom.maxZoomTime;
          local incAddDifference = DynamicCam.db.profile.reactiveZoom.incAddDifference;
          local easingFunc = DynamicCam.db.profile.reactiveZoom.easingFunc;

          -- if we've change directions, make sure to reset
          if (zoomIn) then
              if (targetZoom and targetZoom > currentZoom) then
                  targetZoom = nil;
              end
          else
              if (targetZoom and targetZoom < currentZoom) then
                  targetZoom = nil;
              end
          end

          -- scale increments up
          if (increments == 1) then
              if (targetZoom) then
                  local diff = math.abs(targetZoom - currentZoom);

                  if (diff > incAddDifference) then
                      increments = increments + addIncrementsAlways + addIncrements;
                  else
                      increments = increments + addIncrementsAlways;
                  end
              else
                  increments = increments + addIncrementsAlways;
              end
          end

          -- if there is already a target zoom, base off that one, or just use the current zoom
          targetZoom = targetZoom or currentZoom;

          if (zoomIn) then
              targetZoom = math.max(0, targetZoom - increments);
          else
              targetZoom = math.min(39, targetZoom + increments);
          end

          -- if we don't need to zoom because we're at the max limits, then don't
          if ((targetZoom == 39 and currentZoom == 39)
              or (targetZoom == 0 and currentZoom == 0)) then
              return;
          end

          -- round target zoom off to the nearest decimal
          targetZoom = round(targetZoom, 1);

          -- get the current time to zoom if we were going linearly or use maxZoomTime, if that's too high
          local zoomTime = math.min(maxZoomTime, math.abs(targetZoom - currentZoom)/tonumber(GetCVar("cameraZoomSpeed")));


          -- Added lines here!
          -- Also correct the shoulder offset according to zoom level.
          -- TODO: Should get the shoulder offset of current situation!
          local userSetShoulderOffset = DynamicCam.db.profile.defaultCvars["test_cameraOverShoulder"]
          local correctedShoulderOffset = userSetShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(targetZoom) * cosFix:CorrectShoulderOffset(userSetShoulderOffset);
          easeShoulderOffset(correctedShoulderOffset, zoomTime, LibEasing[easingFunc]);


          LibCamera:SetZoom(targetZoom, zoomTime, LibEasing[easingFunc], clearTargetZoom);
      else
          if (zoomIn) then
              oldCameraZoomIn(increments, automated);
          else
              oldCameraZoomOut(increments, automated);
          end
      end
  end

  local function ReactiveZoomIn(increments, automated)
      ReactiveZoom(true, increments, automated);
  end

  local function ReactiveZoomOut(increments, automated)
      ReactiveZoom(false, increments, automated);
  end


  local function ReactiveZoomOn()
    CameraZoomIn = ReactiveZoomIn
    CameraZoomOut = ReactiveZoomOut
  end

  local function ReactiveZoomOff()
    cosFix:NonReactiveZoomOn()
  end

  DynamicCam.ReactiveZoomOn = ReactiveZoomOn
  DynamicCam.ReactiveZoomOff = ReactiveZoomOff


  function cosFix:AccessStopEasingShoulderOffset()
    stopEasingShoulderOffset()
  end















  local ACTION_CAM_CVARS = {
      ["test_cameraOverShoulder"] = true,

      ["test_cameraTargetFocusEnemyEnable"] = true,
      ["test_cameraTargetFocusEnemyStrengthPitch"] = true,
      ["test_cameraTargetFocusEnemyStrengthYaw"] = true,

      ["test_cameraTargetFocusInteractEnable"] = true,
      ["test_cameraTargetFocusInteractStrengthPitch"] = true,
      ["test_cameraTargetFocusInteractStrengthYaw"] = true,

      ["test_cameraHeadMovementStrength"] = true,
      ["test_cameraHeadMovementRangeScale"] = true,
      ["test_cameraHeadMovementMovingStrength"] = true,
      ["test_cameraHeadMovementStandingStrength"] = true,
      ["test_cameraHeadMovementMovingDampRate"] = true,
      ["test_cameraHeadMovementStandingDampRate"] = true,
      ["test_cameraHeadMovementFirstPersonDampRate"] = true,
      ["test_cameraHeadMovementDeadZone"] = true,

      ["test_cameraDynamicPitch"] = true,
      ["test_cameraDynamicPitchBaseFovPad"] = true,
      ["test_cameraDynamicPitchBaseFovPadFlying"] = true,
      ["test_cameraDynamicPitchBaseFovPadDownScale"] = true,
      ["test_cameraDynamicPitchSmartPivotCutoffDist"] = true,
  };


  local function DC_SetCVar(cvar, setting)
      -- if actioncam flag is off and if cvar is an ActionCam setting, don't set it
      if (not DynamicCam.db.profile.actionCam and ACTION_CAM_CVARS[cvar]) then
          return;
      end

      -- don't apply cvars if they're already set to the new value
      if (GetCVar(cvar) ~= tostring(setting)) then
          DynamicCam:DebugPrint(cvar, setting);
          SetCVar(cvar, setting);
      end
  end


  -- If you override DynamicCam:ApplyDefaultCameraSettings(newSituationID) with this
  -- local function, the first argument will actually become "DynamicCam".
  local function ApplyDefaultCameraSettings(_, newSituationID)

      local curSituation = DynamicCam.db.profile.situations[DynamicCam.currentSituationID];

      if (newSituationID) then
          curSituation = DynamicCam.db.profile.situations[newSituationID];
      end

      -- apply ActionCam setting
      if (DynamicCam.db.profile.actionCam) then
          -- if it's on, unregister the event, so that we don't get popup
          UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED");
      else
          -- if it's off, make sure to reset all ActionCam settings, then reenable popup
          ResetTestCvars();
          UIParent:RegisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED");
      end

      -- apply default settings if the current situation isn't overriding them
      for cvar, value in pairs(DynamicCam.db.profile.defaultCvars) do

          if (not curSituation or not curSituation.cameraCVars[cvar]) then
              if (cvar == "test_cameraOverShoulder") then

                  -- vvv Changed lines here vvv
                  -- When exiting a situation, we want to restore the shoulderOffset just as fast as the zoom,
                  -- instead of setting the shoulder offset instantaneously. Setting it here might result in glitches.
                  if (not cosFix.exitingSituationFlag) then
                      cosFix.exitingSituationFlag = false

                      local correctedShoulderOffset = value * cosFix:GetShoulderOffsetZoomFactor(GetCameraZoom()) * cosFix:CorrectShoulderOffset(value);
                      if (GetCVar("test_cameraOverShoulder") ~= tostring(correctedShoulderOffset)) then
                          stopEasingShoulderOffset();
                          easeShoulderOffset(correctedShoulderOffset, 0.75);
                      end
                  end
                  -- ^^^ Changed lines here ^^^

              else
                  DC_SetCVar(cvar, value);
              end
          end
      end
  end


  DynamicCam.ApplyDefaultCameraSettings = ApplyDefaultCameraSettings












  local DynamicCamExitSituation = DynamicCam.ExitSituation

  local function ExitSituation(...)

      _, situationID, newSituationID = ...

      -- Setting this will prevent ApplyDefaultCameraSettings(),
      -- called from within DynamicCamExitSituation(),
      -- from changing the shoulder offset.
      cosFix.exitingSituationFlag = true

      DynamicCamExitSituation(...)

      -- Restore the shoulder offset here at the same speed as the zoom gets restored!
      if (DynamicCam:ShouldRestoreZoom(situationID, newSituationID)) then

          local defaultTime = math.abs(restoration[situationID].zoom - GetCameraZoom()) / tonumber(GetCVar("cameraZoomSpeed"));
          local t = math.max(10.0/60.0, math.min(defaultTime, .75));
          local zoomLevel = restoration[situationID].zoom;

          -- TODO: Should get the shoulder offset of the newSituationID!
          local userSetShoulderOffset = DynamicCam.db.profile.defaultCvars["test_cameraOverShoulder"];
          local correctedShoulderOffset = userSetShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(zoomLevel) * cosFix:CorrectShoulderOffset(userSetShoulderOffset);
          easeShoulderOffset(correctedShoulderOffset, t, LibEasing[DynamicCam.db.profile.easingZoom]);

          DynamicCam:DebugPrint("Restoring shoulder offset:", correctedShoulderOffset, "with duration:", t, "(same as zoom restore)");
      else
          -- Just restore test_cameraOverShoulder, because we skipped it by setting cosFix.exitingSituationFlag above.
          -- TODO: Should get the shoulder offset of the newSituationID!
          local userSetShoulderOffset = DynamicCam.db.profile.defaultCvars["test_cameraOverShoulder"];
          local correctedShoulderOffset = userSetShoulderOffset * cosFix:GetShoulderOffsetZoomFactor(GetCameraZoom()) * cosFix:CorrectShoulderOffset(userSetShoulderOffset);
          easeShoulderOffset(correctedShoulderOffset, 0.75);

          DynamicCam:DebugPrint("Not restoring zoom level but shoulder offset: " .. correctedShoulderOffset);
      end

  end

  DynamicCam.ExitSituation = ExitSituation










  -- TODO: Now do the same as above with ExitSituation here with EnterSituation.
  -- The shoulder offset needs to be set at the same speed as transitionTime in DynamicCam.EnterSituation.
  -- DynamicCam.EnterSituation = EnterSituation







end