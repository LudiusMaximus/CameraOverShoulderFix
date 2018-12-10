local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)



if IsAddOnLoaded("DynamicCam") then

  print("DynamicCam loaded")
  
  
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

          
          -- Also correct the shoulder offset according to zoom level.
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
      CameraZoomIn = ReactiveZoomIn;
      CameraZoomOut = ReactiveZoomOut;
  end

  local function ReactiveZoomOff()
      cosFix:NonReactiveZoomOn()   
  end
  
  DynamicCam.ReactiveZoomOn = ReactiveZoomOn
  DynamicCam.ReactiveZoomOff = ReactiveZoomOff
  

end