local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)


local _G = _G
local math_abs = _G.math.abs
local math_floor = _G.math.floor
local math_max = _G.math.max
local math_min = _G.math.min
local pairs = _G.pairs
local string_find = _G.string.find
local string_sub = _G.string.sub
local tostring = _G.tostring
local tonumber = _G.tonumber
local type = _G.type
local wipe = _G.wipe

local CosFix_OriginalSetCVar = _G.CosFix_OriginalSetCVar
local oldCameraZoomIn = _G.CosFix_CameraZoomIn
local oldCameraZoomOut = _G.CosFix_CameraZoomOut

local GetCameraZoom = _G.GetCameraZoom

local GetCVar = _G.GetCVar
local ResetTestCvars = _G.ResetTestCvars
local SetCVar = _G.SetCVar
local SaveView = _G.SaveView
local SetView = _G.SetView
local UIParent = _G.UIParent

-- Nameplate stuff...
local C_NamePlate_GetNamePlateForUnit = _G.C_NamePlate.GetNamePlateForUnit
local UnitExists = _G.UnitExists
local UnitIsFriend = _G.UnitIsFriend
local GetScreenHeight = _G.GetScreenHeight
local GetTime = _G.GetTime
local StaticPopup_Show = _G.StaticPopup_Show
local InterfaceOptionsFrame_OpenToCategory = _G.InterfaceOptionsFrame_OpenToCategory



-- To integrate CameraOverShoulderFix into DynamicCam I would have needed
-- hooking access to important DynamicCam functions like
-- ReactiveZoom(), stopEasingShoulderOffset(), easeShoulderOffset(),
-- ApplyDefaultCameraSettings(), DC_RunScript(), etc.
--
-- As these are only local functions in DynamicCam, I would have needed to duplicate
-- at least these functions to apply my additions to them. But then I would also have
-- had to duplicate all of DynamicCam's other local functions using these functions and
-- so forth. This would have resulted in a cascade of dependencies that would eventually
-- almost span the entire code or DynamicCam.
--
-- Hence the duplication of DynamicCam's code in this file was necessary. My additions
-- are enclosed between "Begin of added cosFix code" and "End of added cosFix code" comments.
-- I feel that copying DynamicCam's code like this has been just, because both DynamicCam and
-- CameraOverShoulderFix are published under the MIT License allowing to do anything
-- with the code. Furthermore, the copied DynamicCam code in CameraOverShoulderFix is
-- only executed if the original DynamicCam is installed (if IsAddOnLoaded("DynamicCam")).
--
--
-- Apart from integrating the shoulder offset correction, I also made these minor
-- improvements for EnterSituation() and ExitSituation():
--   - When entering or exiting a situation, the target shoulder offset must
--     take into account the target camera zoom for GetShoulderOffsetZoomFactor().
--   - When exiting a situation we want to reset the shoulder offset just as fast
--     as the camera zoom, instead of setting it instantaneously (as done by
--     ApplyDefaultCameraSettings() called at the beginning of ExitSituation()).


-- This is the factor by which the userSetShoulderOffset must be multiplied at all times.
-- This is particularly important for shoulderOffset easing, because the factor may change
-- while the easing is happening.
cosFix.shoulderOffsetModelFactor = 1

-- To allow zooming during shoulder offset easing, we must store the current
-- shoulder offset in a global variable that is changed by the easing process
-- and taken into account by the zoom functions.
cosFix.currentShoulderOffset = 0


-- While shoulder offset easing is in progress
-- we do not want an event to set the new
-- value of test_cameraOverShoulder too early, which
-- we actually want to gradually ease to.
-- We have to differentiate between easing started by
-- reactive zoom or by situation changes.
-- The former may only start if the latter is not in progress.

-- Implemented as tables to allow pass by reference.
cosFix.easeShoulderOffsetInProgressReactiveZoom = {false}
cosFix.easeShoulderOffsetInProgressSituationChange = {false}







if IsAddOnLoaded("DynamicCam") then


  -- Shut down DynamicCam before defining the duplicate functions and variables.
  DynamicCam:Shutdown();



  ---------------
  -- LIBRARIES --
  ---------------
  local AceAddon = LibStub("AceAddon-3.0");
  local LibCamera = LibStub("LibCamera-1.0");
  local LibEasing = LibStub("LibEasing-1.0");


  ---------------
  -- CONSTANTS --
  ---------------
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



  ------------
  -- LOCALS --
  ------------
  local _;
  local Options;
  local functionCache = {};
  local situationEnvironments = {}
  local conditionExecutionCache = {};

  local function DC_RunScript(script, situationID)

      if (not script or script == "") then
          return;
      end

      -- make sure that we're not creating tables willy nilly
      if (not functionCache[script]) then
          functionCache[script] = assert(loadstring(script));

          -- if env, set the environment to that
          if (situationID) then
              if (not situationEnvironments[situationID]) then
                  situationEnvironments[situationID] = setmetatable({}, { __index =
                      function(t, k)
                          if (k == "_G") then
                              return t;
                          elseif (k == "this") then
                              return situationEnvironments[situationID].this;
                          else
                              return _G[k];
                          end
                      end
                  });
                  situationEnvironments[situationID].this = {};
              end

              setfenv(functionCache[script], situationEnvironments[situationID]);
          end
      end

      -- return the result
      return functionCache[script]();
  end

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

  local function round(num, numDecimalPlaces)
      local mult = 10^(numDecimalPlaces or 0);
      return math_floor(num * mult + 0.5) / mult;
  end

  local function gotoView(view, instant)
      -- if you call SetView twice, then it's instant
      if (instant) then
          SetView(view);
      end
      SetView(view);
  end

  local function copyTable(originalTable)
      local origType = type(originalTable);
      local copy;
      if (origType == 'table') then
          -- this child is a table, copy the table recursively
          copy = {};
          for orig_key, orig_value in next, originalTable, nil do
              copy[copyTable(orig_key)] = copyTable(orig_value);
          end
      else
          -- this child is a value, copy it cover
          copy = originalTable;
      end
      return copy;
  end


  -------------------------
  -- easeShoulderOffset  --
  -------------------------
  local easeShoulderOffsetHandle;

  local function setShoulderOffset(offset)

      ---------------------------------------------------------
      -- Begin of added cosFix code ---------------------------
      ---------------------------------------------------------
      offset = offset * cosFix:GetShoulderOffsetZoomFactor(GetCameraZoom()) * cosFix.shoulderOffsetModelFactor

      -- Also check for nan (offset == offset).
      if (offset and type(offset) == 'number' and offset == offset) then

          cosFix.currentShoulderOffset = offset
          ---------------------------------------------------------
          -- End of added cosFix code -----------------------------
          ---------------------------------------------------------

          CosFix_OriginalSetCVar("test_cameraOverShoulder", offset)
      end
  end

  local function stopEasingShoulderOffset()

      ---------------------------------------------------------
      -- Begin of added cosFix code ---------------------------
      ---------------------------------------------------------
      cosFix.easeShoulderOffsetInProgressReactiveZoom[1] = false
      cosFix.easeShoulderOffsetInProgressSituationChange[1] = false
      ---------------------------------------------------------
      -- End of added cosFix code -----------------------------
      ---------------------------------------------------------

      if (easeShoulderOffsetHandle) then
          LibEasing:StopEasing(easeShoulderOffsetHandle);
          easeShoulderOffsetHandle = nil;
      end
  end

  local function easeShoulderOffset(endValue, duration, easingFunc, inProgressFlag)
      stopEasingShoulderOffset();

      ---------------------------------------------------------
      -- Begin of added cosFix code ---------------------------
      ---------------------------------------------------------
      local oldOffest = cosFix.currentShoulderOffset

      DynamicCam:DebugPrint("test_cameraOverShoulder", oldOffest, "->", endValue);

      if oldOffest == endValue then return end

      -- setShoulderOffset does the correction at any call.
      -- This is why oldOffest and endValue must be the uncorrected values!
      local zoomFactor = cosFix:GetShoulderOffsetZoomFactor(GetCameraZoom())

      if zoomFactor == 0 then
        oldOffest = 0
      else
        oldOffest = oldOffest / (zoomFactor * cosFix.shoulderOffsetModelFactor)
      end

      -- Store that we are currently easing,
      -- such that no triggered event will set the shoulder offset prematurely.
      -- The events just set cosFix.shoulderOffsetModelFactor to the new value.
      inProgressFlag[1] = true
      easeShoulderOffsetHandle = LibEasing:Ease(setShoulderOffset, oldOffest, endValue, duration, easingFunc,
        function() inProgressFlag[1] = false end );

      ---------------------------------------------------------
      -- End of added cosFix code -----------------------------
      ---------------------------------------------------------

  end





  -------------
  -- FADE UI --
  -------------
  local easeUIAlphaHandle;
  local hidMinimap;
  local unfadeUIFrame = CreateFrame("Frame", "CosFixDynamicCamUnfadeUIFrame");
  local combatSecureFrame = CreateFrame("Frame", "CosFixDynamicCamCombatSecureFrame", nil, "SecureHandlerStateTemplate");
  combatSecureFrame.hidUI = nil;
  combatSecureFrame.lastUIAlpha = nil;

  -- Remove the StateDriver function of original DC frame.
  DynamicCamCombatSecureFrame:SetAttribute("_onstate-dc_combat_state", nil);

  RegisterStateDriver(combatSecureFrame, "dc_combat_state", "[combat] combat; [nocombat] nocombat");
  combatSecureFrame:SetAttribute("_onstate-dc_combat_state", [[ -- arguments: self, stateid, newstate
      if (newstate == "combat") then
          if (self.hidUI) then
              setUIAlpha(combatSecureFrame.lastUIAlpha);
              UIParent:Show();

              combatSecureFrame.lastUIAlpha = nil;
              self.hidUI = nil;
          end
      end
  ]]);

  local function setUIAlpha(newAlpha)

      if (newAlpha and type(newAlpha) == 'number') then
          UIParent:SetAlpha(newAlpha);

          -- show unfadeUIFrame if we're faded
          if (newAlpha < 1 and not unfadeUIFrame:IsShown()) then
              unfadeUIFrame:Show();
          elseif (newAlpha == 1) then
              -- UI is no longer faded, remove the esc handler
              if (unfadeUIFrame:IsShown()) then
                  -- want to hide the frame without calling it's onhide handler
                  local onHide = unfadeUIFrame:GetScript("OnHide");
                  unfadeUIFrame:SetScript("OnHide", nil);
                  unfadeUIFrame:Hide();
                  unfadeUIFrame:SetScript("OnHide", onHide);
              end
          end
      end
  end

  local function stopEasingUIAlpha()

      -- if we are currently easing the UI out, make sure to stop that
      if (easeUIAlphaHandle) then
          LibEasing:StopEasing(easeUIAlphaHandle);
          easeUIAlphaHandle = nil;
      end

      -- show the minimap if we hid it and it's still hidden
      if (hidMinimap and not Minimap:IsShown()) then
          Minimap:Show();
          hidMinimap = nil;
      end

      -- show the UI if we hid it and it's still hidden
      if (combatSecureFrame.hidUI) then
          if (not UIParent:IsShown() and (not InCombatLockdown() or issecure())) then
              setUIAlpha(combatSecureFrame.lastUIAlpha);
              UIParent:Show();
          end

          combatSecureFrame.hidUI = nil;
          combatSecureFrame.lastUIAlpha = nil;
      end
  end

  local function easeUIAlpha(endValue, duration, easingFunc, callback)

      stopEasingUIAlpha();

      if (UIParent:GetAlpha() ~= endValue) then
          easeUIAlphaHandle = LibEasing:Ease(setUIAlpha, UIParent:GetAlpha(), endValue, duration, easingFunc, callback);
      else
          -- we're not going to ease because we're already there, have to call the callback anyways
          if (callback) then
              callback();
          end
      end
  end

  local function fadeUI(opacity, duration, hideUI)
      -- setup a callback that will hide the UI if given or hide the minimap if opacity is 0
      local callback = function()
          if (opacity == 0 and hideUI and UIParent:IsShown() and (not InCombatLockdown() or issecure())) then
              -- hide the UI, but make sure to make opacity 1 so that if escape is pressed, it is shown
              setUIAlpha(1);
              UIParent:Hide();

              combatSecureFrame.lastUIAlpha = opacity;
              combatSecureFrame.hidUI = true;
          elseif (opacity == 0 and Minimap:IsShown()) then
              -- hide the minimap
              Minimap:Hide();
              hidMinimap = true;
          end
      end

      easeUIAlpha(opacity, duration, nil, callback);
  end

  local function unfadeUI(opacity, duration)
      stopEasingUIAlpha();
      easeUIAlpha(opacity, duration);
  end


  -- Remove the OnHide of original DC frame.
  DynamicCamUnfadeUIFrame:SetScript("OnHide", nil);

  -- need to be able to clear the faded UI, use dummy frame that Show() on fade, which will cause esc to
  -- hide it, make OnHide
  unfadeUIFrame:SetScript("OnHide", function(self)
      stopEasingUIAlpha();
      UIParent:SetAlpha(1);
  end);
  tinsert(UISpecialFrames, unfadeUIFrame:GetName());


  -----------------------
  -- NAMEPLATE ZOOMING --
  -----------------------
  local nameplateRestore = {};
  local RAMP_TIME = .25;
  local HYS = 3;
  local SETTLE_TIME = .5;
  local ERROR_MULT = 2.5;
  local STOPPING_SPEED = 5;

  local function restoreNameplates()
      if (not InCombatLockdown()) then
          for k, v in pairs(nameplateRestore) do
              SetCVar(k, v);
          end
          nameplateRestore = {};
      end
  end

  local function fitNameplate(minZoom, maxZoom, nameplatePosition, continously, toggleNameplates)

      if (toggleNameplates) then
          nameplateRestore["nameplateShowAll"] = GetCVar("nameplateShowAll");
          nameplateRestore["nameplateShowFriends"] = GetCVar("nameplateShowFriends");
          nameplateRestore["nameplateShowEnemies"] = GetCVar("nameplateShowEnemies");

          SetCVar("nameplateShowAll", 1);
          if (UnitExists("target")) then
              if (UnitIsFriend("player", "target")) then
                  SetCVar("nameplateShowFriends", 1);
              else
                  SetCVar("nameplateShowEnemies", 1);
              end
          else
              SetCVar("nameplateShowFriends", 1);
              SetCVar("nameplateShowEnemies", 1);
          end
      end

      local lastSpeed = 0;
      local startTime = GetTime();
      local settleTimeStart;
      local zoomFunc = function() -- returning 0 will stop camera, returning nil stops camera, returning number puts camera to that speed
          local nameplate = C_NamePlate_GetNamePlateForUnit("target");

          if (nameplate) then
              local yCenter = (nameplate:GetTop() + nameplate:GetBottom())/2;
              local screenHeight = GetScreenHeight() * UIParent:GetEffectiveScale();
              local difference = screenHeight - yCenter;
              local ratio = (1 - difference/screenHeight) * 100;
              local error = ratio - nameplatePosition;

              local speed = 0;
              if (lastSpeed == 0 and abs(error) < HYS) then
                  speed = 0;
              elseif (abs(error) > HYS/4 or abs(lastSpeed) > STOPPING_SPEED) then
                  speed = ERROR_MULT * error;

                  local deltaTime = GetTime() - startTime;
                  if (deltaTime < RAMP_TIME) then
                      speed = speed * (deltaTime / RAMP_TIME);
                  end
              end

              local curZoom = GetCameraZoom();
              if (speed > 0 and curZoom >= maxZoom) then
                  speed = 0;
              elseif (speed < 0 and curZoom <= minZoom) then
                  speed = 0;
              end

              if (speed == 0) then
                  startTime = GetTime();
                  settleTimeStart = settleTimeStart or GetTime();
              else
                  settleTimeStart = nil;
              end

              if (speed == 0 and not continously and (GetTime() - settleTimeStart > SETTLE_TIME)) then
                  return nil;
              end

              lastSpeed = speed;
              return speed;
          end

          if (continously) then
              return 0;
          end

          return nil;
      end

      LibCamera:CustomZoom(zoomFunc, restoreNameplates);
      DynamicCam:DebugPrint("zoom fit nameplate");
  end



  ----------
  -- CORE --
  ----------
  local started;
  local events = {};
  local evaluateTimer;

  local function OnInitialize()
      -- setup db
      DynamicCam:InitDatabase();
      DynamicCam:RefreshConfig();

      -- setup chat commands
      DynamicCam:RegisterChatCommand("dynamiccam", "OpenMenu");
      DynamicCam:RegisterChatCommand("dc", "OpenMenu");

      DynamicCam:RegisterChatCommand("saveview", "SaveViewCC");
      DynamicCam:RegisterChatCommand("sv", "SaveViewCC");

      DynamicCam:RegisterChatCommand("zoominfo", "ZoomInfoCC");
      DynamicCam:RegisterChatCommand("zi", "ZoomInfoCC");

      DynamicCam:RegisterChatCommand("zoom", "ZoomSlash");
      DynamicCam:RegisterChatCommand("pitch", "PitchSlash");
      DynamicCam:RegisterChatCommand("yaw", "YawSlash");

      -- make sure to disable the message if ActionCam setting is on
      if (DynamicCam.db.profile.actionCam) then
          UIParent:UnregisterEvent("EXPERIMENTAL_CVAR_CONFIRMATION_NEEDED");
      end

      -- disable if the setting is enabled
      if (not DynamicCam.db.profile.enabled) then
          DynamicCam:Disable();
      end
  end
  DynamicCam.OnInitialize = OnInitialize



  local function OnEnable()
      DynamicCam.db.profile.enabled = true;

      DynamicCam:Startup();
  end
  DynamicCam.OnEnable = OnEnable


  local function OnDisable()
      DynamicCam.db.profile.enabled = false;
      DynamicCam:Shutdown();
  end
  DynamicCam.OnDisable = OnDisable

  local function Startup()
      -- make sure that shortcuts have values
      if (not Options) then
          Options = DynamicCam.Options;
      end

      -- register for dynamiccam messages
      DynamicCam:RegisterMessage("DC_SITUATION_ENABLED");
      DynamicCam:RegisterMessage("DC_SITUATION_DISABLED");
      DynamicCam:RegisterMessage("DC_SITUATION_UPDATED");
      DynamicCam:RegisterMessage("DC_BASE_CAMERA_UPDATED");

      -- initial evaluate needs to be delayed because the camera doesn't like changing cvars on startup
      DynamicCam:ScheduleTimer("ApplyDefaultCameraSettings", 2.5);
      evaluateTimer = DynamicCam:ScheduleTimer("EvaluateSituations", 3);
      DynamicCam:ScheduleTimer("RegisterEvents", 3);

      -- turn on reactive zoom if it's enabled
      if (DynamicCam.db.profile.reactiveZoom.enabled) then
          DynamicCam:ReactiveZoomOn();
      end

      started = true;
  end
  DynamicCam.Startup = Startup


  local function Shutdown()
      -- kill the evaluate timer if it's running
      if (evaluateTimer) then
          DynamicCam:CancelTimer(evaluateTimer);
          evaluateTimer = nil;
      end

      -- exit the current situation if in one
      if (DynamicCam.currentSituationID) then
          DynamicCam:ExitSituation(DynamicCam.currentSituationID);
      end

      events = {};
      DynamicCam:UnregisterAllEvents();
      DynamicCam:UnregisterAllMessages();

      -- apply default settings
      DynamicCam:ApplyDefaultCameraSettings();

      -- turn off reactiveZoom
      DynamicCam:ReactiveZoomOff();

      started = false;
  end
  DynamicCam.Shutdown = Shutdown



  ----------------
  -- SITUATIONS --
  ----------------
  local delayTime;
  local delayTimer;
  local restoration = {};

  local function EvaluateSituations()

      -- if we currently have timer running, kill it
      if (evaluateTimer) then
          DynamicCam:CancelTimer(evaluateTimer);
          evaluateTimer = nil;
      end

      if (DynamicCam.db.profile.enabled) then
          local highestPriority = -100;
          local topSituation;

          -- go through all situations pick the best one
          for id, situation in pairs(DynamicCam.db.profile.situations) do
              if (situation.enabled) then
                  -- evaluate the condition, if it checks out and the priority is larger then any other, set it
                  local lastEvaluate = conditionExecutionCache[id];
                  local thisEvaluate = DC_RunScript(situation.condition, id);
                  conditionExecutionCache[id] = thisEvaluate;

                  if (thisEvaluate) then
                      -- the condition is true
                      if (not lastEvaluate) then
                          -- last evaluate wasn't true, so this we "flipped"
                          DynamicCam:SendMessage("DC_SITUATION_ACTIVE", id);
                      end

                      -- check to see if we've already found something with higher priority
                      if (situation.priority > highestPriority) then
                          highestPriority = situation.priority;
                          topSituation = id;
                      end
                  else
                      -- the condition is false
                      if (lastEvaluate) then
                          -- last evaluate was true, so we "flipped"
                          DynamicCam:SendMessage("DC_SITUATION_INACTIVE", id);
                      end
                  end
              end
          end

          local swap = true;
          if (DynamicCam.currentSituationID and (not topSituation or topSituation ~= DynamicCam.currentSituationID)) then
              -- we're in a situation that isn't the topSituation or there is no topSituation
              local delay = DynamicCam.db.profile.situations[DynamicCam.currentSituationID].delay;
              if (delay > 0) then
                  if (not delayTime) then
                      -- not yet cooling down, make sure to guarentee an evaluate, don't swap
                      delayTime = GetTime() + delay;
                      delayTimer = DynamicCam:ScheduleTimer("EvaluateSituations", delay, "DELAY_TIMER");
                      DynamicCam:DebugPrint("Not changing situation because of a delay");
                      swap = false;
                  elseif (delayTime > GetTime()) then
                      -- still cooling down, don't swap
                      swap = false;
                  end
              end
          end

          if (swap) then
              if (topSituation) then
                  if (topSituation ~= DynamicCam.currentSituationID) then
                      -- we want to swap and there is a situation to swap into, and it's not the current situation
                      DynamicCam:SetSituation(topSituation);
                  end

                  -- if we had a delay previously, make sure to reset it
                  delayTime = nil;
              else
                  --none of the situations are active, leave the current situation
                  if (DynamicCam.currentSituationID) then
                      DynamicCam:ExitSituation(DynamicCam.currentSituationID);
                  end
              end
          end
      end
  end
  DynamicCam.EvaluateSituations = EvaluateSituations


  local function SetSituation(_, situationID)
      local oldSituationID = DynamicCam.currentSituationID;
      local restoringZoom;

      -- if currently in a situation, leave it
      if (DynamicCam.currentSituationID) then
          restoringZoom = DynamicCam:ExitSituation(DynamicCam.currentSituationID, situationID);
      end

      -- go into the new situation
      DynamicCam:EnterSituation(situationID, oldSituationID, restoringZoom);
  end
  DynamicCam.SetSituation = SetSituation


  local function EnterSituation(_, situationID, oldSituationID, skipZoom)

      ---------------------------------------------------------
      -- Begin of added cosFix code ---------------------------
      ---------------------------------------------------------
      -- Necessary if you are entering a situation without zoom but with a view,
      -- and the zoom easing of a previous situation change is still in progress.
      -- E.g. stop NPC interacation and start it again right away.
      LibCamera:StopZooming();
      ---------------------------------------------------------
      -- End of added cosFix code -----------------------------
      ---------------------------------------------------------

      local situation = DynamicCam.db.profile.situations[situationID];
      local this = situationEnvironments[situationID].this;

      DynamicCam:DebugPrint("Entering situation", situation.name);

      -- load and run advanced script onEnter
      DC_RunScript(situation.executeOnEnter, situationID);

      DynamicCam.currentSituationID = situationID;

      restoration[situationID] = {};
      local a = situation.cameraActions;

      local transitionTime = a.transitionTime;
      if (this.transitionTime) then
          transitionTime = this.transitionTime;
      end
      -- min 10 frames
      transitionTime = math_max(10.0/60.0, transitionTime);

      -- set view settings
      if (situation.view.enabled) then
          if (situation.view.restoreView) then
              SaveView(1);
          end

          gotoView(situation.view.viewNumber, situation.view.instant);
      end

      -- ZOOM --
      if (not skipZoom) then

          -- save old zoom level
          local cameraZoom = GetCameraZoom();
          restoration[situationID].zoom = round(cameraZoom, 1);
          restoration[situationID].zoomSituation = oldSituationID;

          -- set zoom level
          local newZoomLevel;

          if (a.zoomSetting == "in" and cameraZoom > a.zoomValue) then
              newZoomLevel = a.zoomValue;
          elseif (a.zoomSetting == "out" and cameraZoom < a.zoomValue) then
              newZoomLevel = a.zoomValue;
          elseif (a.zoomSetting == "set") then
              newZoomLevel = a.zoomValue;
          elseif (a.zoomSetting == "range") then
              if (cameraZoom < a.zoomMin) then
                  newZoomLevel = a.zoomMin;
              elseif (cameraZoom > a.zoomMax) then
                  newZoomLevel = a.zoomMax;
              end
          elseif (a.zoomSetting == "fit") then
              local min = a.zoomMin;
              if (a.zoomFitUseCurAsMin) then
                  min = math_min(GetCameraZoom(), a.zoomMax);
              end

              fitNameplate(min, a.zoomMax, a.zoomFitPosition, a.zoomFitContinous, a.zoomFitToggleNameplate);
          end

          -- actually do zoom
          if (newZoomLevel) then
              local difference = math_abs(newZoomLevel - cameraZoom)
              local linearSpeed = difference / transitionTime;
              local currentSpeed = tonumber(GetCVar("cameraZoomSpeed"));
              local duration = transitionTime;

              -- if zoom speed is lower than current speed, then calculate a new transitionTime
              if (a.timeIsMax and linearSpeed < currentSpeed) then
                  -- min time 10 frames
                  duration = math_max(10.0/60.0, difference / currentSpeed)
              end

              DynamicCam:DebugPrint("Setting zoom level because of situation entrance", newZoomLevel, duration);

              LibCamera:SetZoom(newZoomLevel, duration, LibEasing[DynamicCam.db.profile.easingZoom]);
          end

          -- if we didn't adjust the zoom, then reset oldZoom
          if (not newZoomLevel and a.zoomSetting ~= "fit") then
              restoration[situationID].zoom = nil;
              restoration[situationID].zoomSituation = nil;
          end
      else
          DynamicCam:DebugPrint("Restoring zoom level, so skipping zoom action")
      end

      -- set all cvars
      for cvar, value in pairs(situation.cameraCVars) do
          if (cvar == "test_cameraOverShoulder") then

              ---------------------------------------------------------
              -- Begin of added cosFix code ---------------------------
              ---------------------------------------------------------

              -- When we are entering a view, there is no additional zoom for
              -- the situation. We also want to ignore the transition time
              -- but ease test_cameraOverShoulder as fast at the view change.
              -- 0.5 seems to be good for that.
              local shoulderTransitionTime = nil
              local oldSituation = DynamicCam.db.profile.situations[oldSituationID]
              if situation.view.enabled or (oldSituation and oldSituation.view.enabled and oldSituation.view.restoreView) then
                  shoulderTransitionTime = 0.5
              else
                shoulderTransitionTime = transitionTime
              end


              local modelFactor = cosFix:CorrectShoulderOffset(value)
              if modelFactor ~= -1 then
                  -- This is only necessary because the modelFactor for mounts depends on value.
                  cosFix.shoulderOffsetModelFactor = modelFactor

                  easeShoulderOffset(value, shoulderTransitionTime, nil, cosFix.easeShoulderOffsetInProgressSituationChange)
              end
              ---------------------------------------------------------
              -- End of added cosFix code -----------------------------
              ---------------------------------------------------------

          else
              DC_SetCVar(cvar, value);
          end
      end

      -- ROTATE --
      if (a.rotate) then
          if (a.rotateSetting == "continous") then
              LibCamera:BeginContinuousYaw(a.rotateSpeed, transitionTime);
          elseif (a.rotateSetting == "degrees") then
              if (a.yawDegrees ~= 0) then
                  LibCamera:Yaw(a.yawDegrees, transitionTime, LibEasing[DynamicCam.db.profile.easingYaw]);
              end

              if (a.pitchDegrees ~= 0) then
                  LibCamera:Pitch(a.pitchDegrees, transitionTime, LibEasing[DynamicCam.db.profile.easingPitch]);
              end
          end
      end

      -- EXTRAS --
      if (situation.extras.hideUI) then
          fadeUI(situation.extras.hideUIFadeOpacity, math_min(0.5, transitionTime), situation.extras.actuallyHideUI);
      end

      DynamicCam:SendMessage("DC_SITUATION_ENTERED");
  end
  DynamicCam.EnterSituation = EnterSituation


  local function ExitSituation(_, situationID, newSituationID)

      local restoringZoom;
      local situation = DynamicCam.db.profile.situations[situationID];
      DynamicCam.currentSituationID = nil;

      DynamicCam:DebugPrint("Exiting situation "..situation.name);

      -- load and run advanced script onExit
      DC_RunScript(situation.executeOnExit, situationID);


      ---------------------------------------------------------
      -- Begin of added cosFix code ---------------------------
      ---------------------------------------------------------
      -- Setting this flag will prevent ApplyDefaultCameraSettings() from setting
      -- the shoulder offset instantaneously, because we rather want to ease-restore
      -- it at the same speed as the camera zoom (see below).
      cosFix.exitingSituationFlag = true
      ---------------------------------------------------------
      -- End of added cosFix code -----------------------------
      ---------------------------------------------------------

      -- restore cvars to their default values
      DynamicCam:ApplyDefaultCameraSettings(newSituationID);

      ---------------------------------------------------------
      -- Begin of added cosFix code ---------------------------
      ---------------------------------------------------------
      cosFix.exitingSituationFlag = false
      ---------------------------------------------------------
      -- End of added cosFix code -----------------------------
      ---------------------------------------------------------


      -- restore view that is enabled
      if (situation.view.enabled and situation.view.restoreView) then
          gotoView(1, situation.view.instant);
          ---------------------------------------------------------
          -- Begin of added cosFix code ---------------------------
          ---------------------------------------------------------
          -- If we restore the view, we do not want the new situation
          -- to put a different zoom on top.
          restoringZoom = true
          ---------------------------------------------------------
          -- End of added cosFix code -----------------------------
          ---------------------------------------------------------
      end

      local a = situation.cameraActions;

      -- stop rotating if we started to
      if (a.rotate) then
          if (a.rotateSetting == "continous") then
              local yaw = LibCamera:StopYawing();

              -- rotate back if we want to
              if (a.rotateBack) then
                  DynamicCam:DebugPrint("Ended rotate, degrees rotated, yaw:", yaw);
                  if (yaw) then
                      local yawBack = yaw % 360;

                      -- we're beyond 180 degrees, go the other way
                      if (yawBack > 180) then
                          yawBack = yawBack - 360;
                      end

                      LibCamera:Yaw(-yawBack, 0.75, LibEasing[DynamicCam.db.profile.easingYaw]);
                  end
              end
          elseif (a.rotateSetting == "degrees") then
              if (LibCamera:IsRotating()) then
                  -- interrupted rotation
                  local yaw, pitch = LibCamera:StopRotating();

                  -- rotate back if we want to
                  if (a.rotateBack) then
                      DynamicCam:DebugPrint("Ended rotate early, degrees rotated, yaw:", yaw, "pitch:", pitch);
                      if (yaw) then
                          LibCamera:Yaw(-yaw, 0.75, LibEasing[DynamicCam.db.profile.easingYaw]);
                      end

                      if (pitch) then
                          LibCamera:Pitch(-pitch, 0.75, LibEasing[DynamicCam.db.profile.easingPitch]);
                      end
                  end
              else
                  if (a.rotateBack) then
                      if (a.yawDegrees ~= 0) then
                          LibCamera:Yaw(-a.yawDegrees, 0.75, LibEasing[DynamicCam.db.profile.easingYaw]);
                      end

                      if (a.pitchDegrees ~= 0) then
                          LibCamera:Pitch(-a.pitchDegrees, 0.75, LibEasing[DynamicCam.db.profile.easingPitch]);
                      end
                  end
              end
          end
      end

      -- restore zoom level if we saved one
      if (DynamicCam:ShouldRestoreZoom(situationID, newSituationID)) then

          restoringZoom = true;

          local defaultTime = math_abs(restoration[situationID].zoom - GetCameraZoom()) / tonumber(GetCVar("cameraZoomSpeed"));
          local t = math_max(10.0/60.0, math_min(defaultTime, .75));
          local zoomLevel = restoration[situationID].zoom;

          LibCamera:SetZoom(zoomLevel, t, LibEasing[DynamicCam.db.profile.easingZoom]);


          ---------------------------------------------------------
          -- Begin of added cosFix code ---------------------------
          ---------------------------------------------------------

          -- Must get shoulder offset of newSituationID if any!
          local userSetShoulderOffset = cosFix:GetUserSetShoulderOffset(newSituationID);

          local modelFactor = cosFix:CorrectShoulderOffset(userSetShoulderOffset);
          if (modelFactor ~= -1) then
              -- This is only necessary because the modelFactor for mounts depends on userSetShoulderOffset.
              cosFix.shoulderOffsetModelFactor = modelFactor;
              
              -- If we are resetting a view, we want the shoulder offset change to be as fast as the view change!
              if (situation.view.enabled and situation.view.restoreView) then
                  t = 0.5
              end
              
              easeShoulderOffset(userSetShoulderOffset, t, LibEasing[DynamicCam.db.profile.easingZoom], cosFix.easeShoulderOffsetInProgressSituationChange);

              DynamicCam:DebugPrint("Restoring zoom level:", zoomLevel, " and shoulder offset:", userSetShoulderOffset, " with duration:", t);
          end
      else

          -- Restore only test_cameraOverShoulder, because we skipped it by passing
          -- exitingSituationFlag=true to ApplyDefaultCameraSettings() above.

          -- But only restore test_cameraOverShoulder, if newSituationID has no shoulder offset.
          if (not newSituationID) or
             (not DynamicCam.db.profile.situations[newSituationID]) or
             (not DynamicCam.db.profile.situations[newSituationID].cameraCVars) or
             (not DynamicCam.db.profile.situations[newSituationID].cameraCVars.test_cameraOverShoulder) then

            -- Must get shoulder offset of newSituationID if any!
            local userSetShoulderOffset = cosFix:GetUserSetShoulderOffset(newSituationID);

            local modelFactor = cosFix:CorrectShoulderOffset(userSetShoulderOffset);
            if (modelFactor ~= -1) then
                -- This is only necessary because the modelFactor for mounts depends on userSetShoulderOffset.
                cosFix.shoulderOffsetModelFactor = modelFactor;
                
                -- Actually no idea, why DynamicCam uses 0.75 here as a default...
                local t = 0.75
                -- If we are setting a view, we want the shoulder offset change to be as fast as the view change!
                if (situation.view.enabled and situation.view.restoreView) then
                    t = 0.5
                end
                easeShoulderOffset(userSetShoulderOffset, t, nil, cosFix.easeShoulderOffsetInProgressSituationChange);

                DynamicCam:DebugPrint("Not restoring zoom level but shoulder offset: " .. userSetShoulderOffset);
            end

          end
          ---------------------------------------------------------
          -- End of added cosFix code -----------------------------
          ---------------------------------------------------------

      end


      -- unhide UI
      if (situation.extras.hideUI) then
          unfadeUI(1, .5);
      end

      wipe(restoration[situationID]);

      DynamicCam:SendMessage("DC_SITUATION_EXITED");

      return restoringZoom;
  end
  DynamicCam.ExitSituation = ExitSituation



  local function GetSituationList()

      local situationList = {};

      for id, situation in pairs(DynamicCam.db.profile.situations) do
          local prefix = "";
          local suffix = "";
          local customPrefix = "";

          if (DynamicCam.currentSituationID == id) then
              prefix = "|cFF00FF00";
              suffix = "|r";
          elseif (not situation.enabled) then
              prefix = "|cFF808A87";
              suffix = "|r";
          elseif (conditionExecutionCache[id]) then
              prefix = "|cFF63B8FF";
              suffix = "|r";
          end

          if (string_find(id, "custom")) then
              customPrefix = "Custom: ";
          end

          situationList[id] = prefix..customPrefix..situation.name..suffix;
      end

      return situationList;
  end
  DynamicCam.GetSituationList = GetSituationList


  local function CopySituationInto(_, fromID, toID)
      -- make sure that both from and to are valid situationIDs
      if (not fromID or not toID or fromID == toID or not DynamicCam.db.profile.situations[fromID] or not DynamicCam.db.profile.situations[toID]) then
          DynamicCam:DebugPrint("CopySituationInto has invalid from or to!");
          return;
      end

      local from = DynamicCam.db.profile.situations[fromID];
      local to = DynamicCam.db.profile.situations[toID];

      -- copy settings over
      to.enabled = from.enabled;

      -- a more robust solution would be much better!
      to.cameraActions = {};
      for key, value in pairs(from.cameraActions) do
          to.cameraActions[key] = from.cameraActions[key];
      end

      to.view = {};
      for key, value in pairs(from.view) do
          to.view[key] = from.view[key];
      end

      to.extras = {};
      for key, value in pairs(from.extras) do
          to.extras[key] = from.extras[key];
      end

      to.cameraCVars = {};
      for key, value in pairs(from.cameraCVars) do
          to.cameraCVars[key] = from.cameraCVars[key];
      end

      DynamicCam:SendMessage("DC_SITUATION_UPDATED", toID);
  end
  DynamicCam.CopySituationInto = DynamicCam


  local function UpdateSituation(_, situationID)

      local situation = DynamicCam.db.profile.situations[situationID];
      if (situation and (situationID == DynamicCam.currentSituationID)) then
          -- apply cvars
          for cvar, value in pairs(situation.cameraCVars) do

              ---------------------------------------------------------
              -- Begin of added cosFix code ---------------------------
              ---------------------------------------------------------
              if (cvar == "test_cameraOverShoulder") then
                  cosFix.currentShoulderOffset = value
              end
              ---------------------------------------------------------
              -- End of added cosFix code -----------------------------
              ---------------------------------------------------------

              DC_SetCVar(cvar, value);
          end
          DynamicCam:ApplyDefaultCameraSettings();
      end
      DC_RunScript(situation.executeOnInit, situationID);
      DynamicCam:RegisterSituationEvents(situationID);
      DynamicCam:EvaluateSituations();
  end
  DynamicCam.UpdateSituation = UpdateSituation


  local function CreateCustomSituation(_, name)
      -- search for a clear id
      local highest = 0;

      -- go through each and every situation, look for the custom ones, and find the
      -- highest custom id
      for id, situation in pairs(DynamicCam.db.profile.situations) do
          local i, j = string_find(id, "custom");

          if (i and j) then
              local num = tonumber(string_sub(id, j+1));

              if (num and num > highest) then
                  highest = num;
              end
          end
      end

      -- copy the default situation into a new table
      local newSituationID = "custom"..(highest+1);
      local newSituation = copyTable(DynamicCam.defaults.profile.situations["**"]);

      newSituation.name = name;

      -- create the entry in the profile with an id 1 higher than the highest already customID
      DynamicCam.db.profile.situations[newSituationID] = newSituation;

      -- make sure that the options panel reselects a situation
      if (Options) then
          Options:SelectSituation(newSituationID);
      end

      DynamicCam:SendMessage("DC_SITUATION_UPDATED", newSituationID);
      return newSituation, newSituationID;
  end
  DynamicCam.CreateCustomSituation = CreateCustomSituation


  local function DeleteCustomSituation(_, situationID)
      if (not DynamicCam.db.profile.situations[situationID]) then
          DynamicCam:DebugPrint("Cannot delete this situation since it doesn't exist", situationID)
      end

      if (not string_find(situationID, "custom")) then
          DynamicCam:DebugPrint("Cannot delete a non-custom situation");
      end

      -- if we're currently in this situation, exit it
      if (DynamicCam.currentSituationID == situationID) then
          DynamicCam:ExitSituation(situationID);
      end

      -- delete the situation
      DynamicCam.db.profile.situations[situationID] = nil;

      -- make sure that the options panel reselects a situation
      if (Options) then
          Options:ClearSelection();
          Options:SelectSituation();
      end

      -- EvaluateSituations because we might have changed the current situation
      DynamicCam:EvaluateSituations();
  end
  DynamicCam.DeleteCustomSituation = DeleteCustomSituation


  -------------
  -- UTILITY --
  -------------
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

                  ---------------------------------------------------------
                  -- Begin of added cosFix code ---------------------------
                  ---------------------------------------------------------
                  -- ApplyDefaultCameraSettings() is called in the beginning of ExitSituation().
                  -- But when exiting a situation, we want to restore the shoulderOffset
                  -- just as fast as the camera zoom, instead of setting it instantaneously here.
                  -- Thus this flag can be set in ExitSituation() before calling ApplyDefaultCameraSettings().
                  if (not cosFix.exitingSituationFlag) then
                      local modelFactor = cosFix:CorrectShoulderOffset(value);
                      if (modelFactor ~= -1) then
                          -- This is only necessary because the modelFactor for mounts depends on value.
                          cosFix.shoulderOffsetModelFactor = modelFactor;
                          easeShoulderOffset(value, 0.75, nil, cosFix.easeShoulderOffsetInProgressSituationChange);
                      end
                  end
                  ---------------------------------------------------------
                  -- End of added cosFix code -----------------------------
                  ---------------------------------------------------------

              else
                  DC_SetCVar(cvar, value);
              end
          end
      end
  end
  DynamicCam.ApplyDefaultCameraSettings = ApplyDefaultCameraSettings


  local function ShouldRestoreZoom(_, oldSituationID, newSituationID)
      local newSituation = DynamicCam.db.profile.situations[newSituationID];

      -- don't restore if we don't have a saved zoom value
      if (not restoration[oldSituationID].zoom) then
          return false;
      end

      -- restore if we're just exiting a situation, but not going into a new one
      if (not newSituation) then
          DynamicCam:DebugPrint("Restoring because just exiting");
          return true;
      end


      -- only restore zoom if returning to the same situation
      if (restoration[oldSituationID].zoomSituation ~= newSituationID) then
          -- TODO (Ludius): But I want to return to the zoom I had when I was last in that situation...
          return false;
      end

      -- don't restore zoom if we're about to go into a view
      if (newSituation.view.enabled) then
          return false;
      end

      -- restore zoom based on newSituation zoomSetting
      if (newSituation.cameraActions.zoomSetting == "off") then
          -- don't restore zoom if the new situation doesn't zoom at all
          return false;
      elseif (newSituation.cameraActions.zoomSetting == "set") then
          -- don't restore zoom if the zoom is going to be setting the zoom anyways
          return false;
      elseif (newSituation.cameraActions.zoomSetting == "fit") then
          -- don't restore zoom to a zoom fit
          return false;
      elseif (newSituation.cameraActions.zoomSetting == "range") then
          --only restore zoom if zoom will be in the range
          if ((newSituation.cameraActions.zoomMin <= restoration[oldSituationID].zoom + .5) and
              (newSituation.cameraActions.zoomMax >= restoration[oldSituationID].zoom - .5)) then
              return true;
          end
      elseif (newSituation.cameraActions.zoomSetting == "in") then
          -- only restore if restoration zoom will still be acceptable
          if (newSituation.cameraActions.zoomValue >= restoration[oldSituationID].zoom - .5) then
              return true;
          end
      elseif (newSituation.cameraActions.zoomSetting == "out") then
          -- restore zoom if newSituation is zooming out and we would already be zooming out farther
          if (newSituation.cameraActions.zoomValue <= restoration[oldSituationID].zoom + .5) then
              return true;
          end
      end

      -- if nothing else, don't restore
      return false;
  end
  DynamicCam.ShouldRestoreZoom = ShouldRestoreZoom



  ------------------
  -- ReactiveZoom --
  ------------------
  local targetZoom;

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
          if (targetZoom) then
              local diff = math_abs(targetZoom - currentZoom);

              if (diff > incAddDifference) then
                  increments = increments + addIncrementsAlways + addIncrements;
              else
                  increments = increments + addIncrementsAlways;
              end
          else
              increments = increments + addIncrementsAlways;
          end


          -- if there is already a target zoom, base off that one, or just use the current zoom
          targetZoom = targetZoom or currentZoom;

          if (zoomIn) then
              targetZoom = math_max(0, targetZoom - increments);
          else
              targetZoom = math_min(39, targetZoom + increments);
          end

          -- if we don't need to zoom because we're at the max limits, then don't
          if ((targetZoom == 39 and currentZoom == 39)
              or (targetZoom == 0 and currentZoom == 0)) then
              return;
          end

          -- round target zoom off to the nearest decimal
          targetZoom = round(targetZoom, 1);

          -- get the current time to zoom if we were going linearly or use maxZoomTime, if that's too high
          local zoomTime = math_min(maxZoomTime, math_abs(targetZoom - currentZoom)/tonumber(GetCVar("cameraZoomSpeed")));


          ---------------------------------------------------------
          -- Begin of added cosFix code ---------------------------
          ---------------------------------------------------------
          -- Correct the shoulder offset according to zoom level.
          -- But only if no situation change shoulder offset easing is in progress!
          -- The setShoulderOffset() function will make the zoomFactor adjustments anyway.
          if cosFix.easeShoulderOffsetInProgressSituationChange[1] == false then
            local userSetShoulderOffset = cosFix:GetUserSetShoulderOffset()
            easeShoulderOffset(userSetShoulderOffset, zoomTime, LibEasing[easingFunc], cosFix.easeShoulderOffsetInProgressReactiveZoom)
          end
          ---------------------------------------------------------
          -- End of added cosFix code -----------------------------
          ---------------------------------------------------------

          LibCamera:SetZoom(targetZoom, zoomTime, LibEasing[easingFunc]);

      else
          if (zoomIn) then
              oldCameraZoomIn(increments, automated);
          else
              oldCameraZoomOut(increments, automated);
          end
      end
  end

  local function ReactiveZoomIn(increments, automated)
      ---------------------------------------------------------
      -- Begin of added cosFix code ---------------------------
      ---------------------------------------------------------
      -- No idea, why WoW does in-out-in-out with increments 0
      -- after each mouse wheel turn.
      if increments == 0 then return end
      ---------------------------------------------------------
      -- End of added cosFix code -----------------------------
      ---------------------------------------------------------
      ReactiveZoom(true, increments, automated);
  end

  local function ReactiveZoomOut(increments, automated)
      ---------------------------------------------------------
      -- Begin of added cosFix code ---------------------------
      ---------------------------------------------------------
      -- No idea, why WoW does in-out-in-out with increments 0
      -- after each mouse wheel turn.
      if increments == 0 then return end
      ---------------------------------------------------------
      -- End of added cosFix code -----------------------------
      ---------------------------------------------------------
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


  -- Access function.
  function cosFix:AccessStopEasingShoulderOffset()
    stopEasingShoulderOffset()
  end



  ------------
  -- EVENTS --
  ------------
  local lastEvaluate;
  local TIME_BEFORE_NEXT_EVALUATE = .1;
  local EVENT_DOUBLE_TIME = .2;

  local function EventHandler(_, event, possibleUnit, ...)
      -- we don't want to evaluate too often, some of the events can be *very* spammy
      if (not lastEvaluate or (lastEvaluate and ((lastEvaluate + TIME_BEFORE_NEXT_EVALUATE) < GetTime()))) then
          lastEvaluate = GetTime();

          -- call the evaluate
          DynamicCam:EvaluateSituations();

          -- double the event, since a lot of events happen before the condition turns out to be true
          evaluateTimer = DynamicCam:ScheduleTimer("EvaluateSituations", EVENT_DOUBLE_TIME);
      else
          -- we're delaying the call of evaluate situations until next evaluate
          if (not evaluateTimer) then
              evaluateTimer = DynamicCam:ScheduleTimer("EvaluateSituations", TIME_BEFORE_NEXT_EVALUATE);
          end
      end
  end
  DynamicCam.EventHandler = EventHandler


  local function RegisterEvents()
      DynamicCam:RegisterEvent("PLAYER_CONTROL_GAINED", "EventHandler");

      for situationID, situation in pairs(DynamicCam.db.profile.situations) do
          DynamicCam:RegisterSituationEvents(situationID);
      end
  end
  DynamicCam.RegisterEvents = RegisterEvents


  local function RegisterSituationEvents(_, situationID)
      local situation = DynamicCam.db.profile.situations[situationID];
      if (situation and situation.events) then
          for i, event in pairs(situation.events) do
              if (not events[event]) then
                  events[event] = true;
                  DynamicCam:RegisterEvent(event, "EventHandler");
                  -- DynamicCam:DebugPrint("Registered for event:", event);
              end
          end
      end
  end
  DynamicCam.RegisterSituationEvents = RegisterSituationEvents




  --------------
  -- DATABASE --
  --------------
  local firstDynamicCamLaunch = false;
  local upgradingFromOldVersion = false;


  local function InitDatabase()
      DynamicCam.db = LibStub("AceDB-3.0"):New("DynamicCamDB", DynamicCam.defaults, true);
      DynamicCam.db.RegisterCallback(DynamicCam, "OnProfileChanged", "RefreshConfig");
      DynamicCam.db.RegisterCallback(DynamicCam, "OnProfileCopied", "RefreshConfig");
      DynamicCam.db.RegisterCallback(DynamicCam, "OnProfileReset", "RefreshConfig");
      DynamicCam.db.RegisterCallback(DynamicCam, "OnDatabaseShutdown", "Shutdown");

      -- remove dbVersion, move to a per-profile version number
      if (DynamicCam.db.global.dbVersion) then
          upgradingFromOldVersion = true;
          DynamicCam.db.global.dbVersion = nil;
      end

      if (not DynamicCamDB.profiles) then
          firstDynamicCamLaunch = true;
      else
          -- reset db if we've got a really old version
          local veryOldVersion = false;
          for profileName, profile in pairs(DynamicCamDB.profiles) do
              if (profile.defaultCvars and profile.defaultCvars["cameraovershoulder"]) then
                  veryOldVersion = true;
              end
          end

          if (veryOldVersion) then
              DynamicCam:Print("Detected very old version, resetting DB, sorry about that!");
              DynamicCam.db:ResetDB();
          end

          -- modernize each profile
          for profileName, profile in pairs(DynamicCamDB.profiles) do
              DynamicCam:ModernizeProfile(profile);
          end

          -- show the updated popup
          if (upgradingFromOldVersion) then
              StaticPopup_Show("DYNAMICCAM_UPDATED");
          end
      end
  end
  DynamicCam.InitDatabase = InitDatabase


  local function ModernizeProfile(_, profile)
      if (not profile.version) then
          profile.version = 1;
      end

      local startVersion = profile.version;

      if (profile.version == 1) then
          if (profile.defaultCvars and profile.defaultCvars["test_cameraLockedTargetFocusing"] ~= nil) then
              profile.defaultCvars["test_cameraLockedTargetFocusing"] = nil;
          end

          upgradingFromOldVersion = true;
          profile.version = 2;
          profile.firstRun = false;
      end

      -- modernize each situation
      if (profile.situations) then
          for situationID, situation in pairs(profile.situations) do
              DynamicCam:ModernizeSituation(situation, startVersion);
          end
      end
  end
  DynamicCam.ModernizeProfile = ModernizeProfile


  local function ModernizeSituation(_, situation, version)
      if (version == 1) then
          -- clear unused nameplates db stuff
          if (situation.extras) then
              situation.extras["nameplates"] = nil;
              situation.extras["friendlyNameplates"] = nil;
              situation.extras["enemyNameplates"] = nil;
          end

          -- update targetlock features
          if (situation.targetLock) then
              if (situation.targetLock.enabled) then
                  if (not situation.cameraCVars) then
                      situation.cameraCVars = {};
                  end

                  if (situation.targetLock.onlyAttackable ~= nil and situation.targetLock.onlyAttackable == false) then
                      situation.cameraCVars["test_cameraTargetFocusEnemyEnable"] = 1;
                      situation.cameraCVars["test_cameraTargetFocusInteractEnable"] = 1
                  else
                      situation.cameraCVars["test_cameraTargetFocusEnemyEnable"] = 1;
                  end
              end

              situation.targetLock = nil;
          end

          -- update camera rotation
          if (situation.cameraActions) then
              -- convert to yaw degrees instead of rotate degrees
              if (situation.cameraActions.rotateDegrees) then
                  situation.cameraActions.yawDegrees = situation.cameraActions.rotateDegrees;
                  situation.cameraActions.pitchDegrees = 0;
                  situation.cameraActions.rotateDegrees = nil;
              end

              -- convert old scalar rotate speed to something that's in degrees/second
              if (situation.cameraActions.rotateSpeed and situation.cameraActions.rotateSpeed < 5) then
                  situation.cameraActions.rotateSpeed = situation.cameraActions.rotateSpeed * tonumber(GetCVar("cameraYawMoveSpeed"));
              end
          end
      end
  end
  DynamicCam.ModernizeSituation = ModernizeSituation


  local function RefreshConfig()

      local profile = DynamicCam.db.profile;

      -- shutdown the addon if it's enabled
      if (profile.enabled and started) then
          DynamicCam:Shutdown();
      end

      -- situation is active, but db killed it
      if (DynamicCam.currentSituationID) then
          DynamicCam.currentSituationID = nil;
      end

      -- clear the options panel so that it reselects
      -- make sure that options panel selects a situation
      if (Options) then
          Options:ClearSelection();
          Options:SelectSituation();
      end

      -- present a menu that loads a set of defaults, if this is the profiles first run
      if (profile.firstRun) then
          if (firstDynamicCamLaunch) then
              StaticPopup_Show("DYNAMICCAM_FIRST_RUN");
              firstDynamicCamLaunch = false;
          else
              StaticPopup_Show("DYNAMICCAM_FIRST_LOAD_PROFILE");
          end
          profile.firstRun = false;
      end

      -- start the addon back up
      if (profile.enabled and not started) then
          DynamicCam:Startup();
      end

      -- run all situations's advanced init script
      for id, situation in pairs(DynamicCam.db.profile.situations) do
          DC_RunScript(situation.executeOnInit, id);
      end
  end
  DynamicCam.RefreshConfig = RefreshConfig


  -------------------
  -- CHAT COMMANDS --
  -------------------
  local function tokenize(str, delimitor)
      local tokens = {};
      for token in str:gmatch(delimitor or "%S+") do
          table.insert(tokens, token);
      end
      return tokens;
  end



  local function OpenMenu(_, input)
      if (not Options) then
          Options = self.Options;
      end

      Options:SelectSituation();

      -- just open to the frame, double call because blizz bug
      InterfaceOptionsFrame_OpenToCategory(Options.menu);
      InterfaceOptionsFrame_OpenToCategory(Options.menu);
  end
  DynamicCam.OpenMenu = OpenMenu


  local function SaveViewCC(_, input)
      local tokens = tokenize(input);

      local viewNum = tonumber(tokens[1]);

      if (viewNum and viewNum <= 5 and viewNum > 1) then
          SaveView(viewNum);
      else
          DynamicCam:Print("Improper view number provided.")
      end
  end
  DynamicCam.SaveViewCC = SaveViewCC



  local function ZoomSlash(_, input)
      local tokens = tokenize(input);

      local zoom = tonumber(tokens[1]);
      local time = tonumber(tokens[2]);
      local easingFuncName;
      local easingFunc;

      if (not time) then
          -- time not provided, maybe 2nd param is easingfunc?
          easingFuncName = tokens[2];
      else
          easingFuncName = tokens[3];
      end

      -- look up easing func
      if (easingFuncName) then
          easingFunc = LibEasing[easingFuncName] or LibEasing.InOutQuad;
      end

      if (zoom and (zoom <= 39 or zoom >= 0)) then
          local defaultTime = math_abs(zoom - GetCameraZoom()) / tonumber(GetCVar("cameraZoomSpeed"));
          LibCamera:SetZoom(zoom, time or math_min(defaultTime, 0.75), easingFunc);
      end
  end
  DynamicCam.ZoomSlash = ZoomSlash



  local function PitchSlash(_, input)
      local tokens = tokenize(input);

      local pitch = tonumber(tokens[1]);
      local time = tonumber(tokens[2]);
      local easingFuncName;
      local easingFunc;

      if (not time) then
          -- time not provided, maybe 2nd param is easingfunc?
          easingFuncName = tokens[2];
      else
          easingFuncName = tokens[3];
      end

      -- look up easing func
      if (easingFuncName) then
          easingFunc = LibEasing[easingFuncName] or LibEasing.InOutQuad;
      end

      if (pitch and (pitch <= 90 or pitch >= -90)) then
          LibCamera:Pitch(pitch, time or 0.75, easingFunc);
      end
  end
  DynamicCam.PitchSlash = PitchSlash


  local function YawSlash(_, input)
      local tokens = tokenize(input);

      local yaw = tonumber(tokens[1]);
      local time = tonumber(tokens[2]);
      local easingFuncName;
      local easingFunc;

      if (not time) then
          -- time not provided, maybe 2nd param is easingfunc?
          easingFuncName = tokens[2];
      else
          easingFuncName = tokens[3];
      end

      -- look up easing func
      if (easingFuncName) then
          easingFunc = LibEasing[easingFuncName] or LibEasing.InOutQuad;
      end

      if (yaw) then
          LibCamera:Yaw(yaw, time or 0.75, easingFunc);
      end
  end
  DynamicCam.YawSlash = YawSlash



  -- A function to get the current shoulder offset; either the global default
  -- or the one of the current situation
  -- or the one of the new situation we are about to enter.
  function cosFix:GetUserSetShoulderOffset(newSituationID)

      local curSituation = DynamicCam.db.profile.situations[DynamicCam.currentSituationID];

      if (newSituationID) then
          curSituation = DynamicCam.db.profile.situations[newSituationID];
      end

      if curSituation and curSituation.cameraCVars.test_cameraOverShoulder then
          return curSituation.cameraCVars.test_cameraOverShoulder
      end

      return DynamicCam.db.profile.defaultCvars.test_cameraOverShoulder
  end


  -- Refill the new local variables and start DynamicCam again with the overridden functions.
  DynamicCam:RefreshConfig();
  DynamicCam:Startup();


end