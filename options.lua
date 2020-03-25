local folderName = ...
local cosFix = LibStub("AceAddon-3.0"):GetAddon(folderName)


local dynamicCamLoaded = _G.IsAddOnLoaded("DynamicCam")
local DynamicCam = _G.DynamicCam


local defaults = {
  profile = {
    modelIndependentShoulderOffset = true,
    shoulderOffsetZoom = true,
    debugOutput = false,
    enabled = true,
    cvars = {
      test_cameraOverShoulder = 1.5,
      test_cameraDynamicPitch = 1,
      test_cameraDynamicPitchBaseFovPad = 0.7,
      test_cameraDynamicPitchBaseFovPadFlying = 0.95,
      test_cameraDynamicPitchBaseFovPadDownScale = 1,
    }
  }
}


local optionsTable = {
  type = 'group',
  args = {
    modelIndependentShoulderOffset = {
      order = 1,
      type = 'toggle',
      name = "Correct Shoulder Offset",
      desc = "The game interprets the Camera Shoulder Offset differently depending on what model (race, gender, mount, vehicle) is currently active. Setting this option will try to compensate this as good as possible. \n\n(Not all mounts, vehicles and shapeshift forms have been added to the code yet. If you feel that an offset for some model is right, enable the Debug Output below to get a chat window message if a model is not in the code. The addon's project page contains a video tutorial of how you can determine the perfect factor yourself; and ideally submit it to the addon developer.)",
      descStyle = "inline",
      width = "full",
      get = function() return cosFix.db.profile.modelIndependentShoulderOffset end,
      set = function(_, newValue)
              cosFix.db.profile.modelIndependentShoulderOffset = newValue
              if dynamicCamLoaded then
                DynamicCam:ApplyDefaultCameraSettings()
              else
                for variable, value in pairs(cosFix.db.profile.cvars) do
                  SetCVar(variable, value)
                end
              end
            end,
    },
    shoulderOffsetZoom = {
      order = 2,
      type = 'toggle',
      name = "Shoulder Offset Zoom-In",
      desc = "Enabling this option will gradually reduce the Camera Shoulder Offset as you zoom-in (mouse wheel) on your character. Otherwise a greater shoulder offset may be awkward while walking through narrow corridors. With this option enabled you just have to zoom in a little more on your character while walking through such corridors and it will be more pleasent as the shoulder offset is reduced.",
      descStyle = "inline",
      width = "full",
      get = function() return cosFix.db.profile.shoulderOffsetZoom end,
      set = function(_, newValue)
              cosFix.db.profile.shoulderOffsetZoom = newValue
              if dynamicCamLoaded then
                DynamicCam:ApplyDefaultCameraSettings()
              else
                for variable, value in pairs(cosFix.db.profile.cvars) do
                  SetCVar(variable, value)
                end
              end
            end,
    },
    debugOutput = {
      order = 3,
      type = 'toggle',
      name = "Debug Output",
      desc = "Print out debug messages to the chat window.\n",
      descStyle = "inline",
      width = "full",
      get = function() return cosFix.db.profile.debugOutput end,
      set = function(_, newValue) cosFix.db.profile.debugOutput = newValue end,
    },
    -- These settings are only shown when DynamicCam is not loaded.
    cvarSettings = {
      order = 4,
      type = 'group',
      name = "Basic camera variables",
      hidden = dynamicCamLoaded,
      inline = true,
      args = {
        description = {
          order = 1,
          type = 'description',
          name = "As you are using " .. folderName .. " as a stand alone addon, you can set some basic variables here.\nWe recommend, however, to use " .. folderName .. " as a plugin to DynamicCam which provides a lot more customisation options and camera movement easing.\n",
          width = "full",
        },
        enabled = {
          order = 2,
          type = 'toggle',
          name = "Enable all",
          descStyle = "inline",
          width = "full",
          get = function() return cosFix.db.profile.enabled end,
          set = function(_, newValue)
                  if (newValue) then
                    cosFix:OnEnable()
                  else
                    cosFix:OnDisable()
                  end
                  cosFix.db.profile.enabled = newValue
                end,
        },
        test_cameraOverShoulder = {
          order = 3,
          type = 'range',
          name = "Camera Shoulder Offset",
          disabled = function() return not cosFix.db.profile.enabled end,
          desc = "Moves the camera left or right from your character.",
          min = -8,
          max = 8,
          step = .1,
          width = "full",
          get = function() return cosFix.db.profile.cvars.test_cameraOverShoulder end,
          set = function(_, newValue)
                  
                  -- If offset changes sign while mounted, we need to update currentModelFactor!
                  if IsMounted() then
                    local oldOffset = cosFix.currentShoulderOffset
                    cosFix.currentShoulderOffset = newValue
                    if (oldOffset < 0 and cosFix.currentShoulderOffset >= 0) or (oldOffset >= 0 and cosFix.currentShoulderOffset < 0) then
                      local modelFactor = cosFix:CorrectShoulderOffset()
                      if modelFactor ~= -1 then
                        cosFix.currentModelFactor = modelFactor
                      end
                    end
                  else
                    cosFix.currentShoulderOffset = newValue
                  end
                  
                  cosFix.db.profile.cvars.test_cameraOverShoulder = newValue
                  SetCVar("test_cameraOverShoulder", newValue)
                end,
        },
        dynamicPitch = {
          order = 4,
          type = 'group',
          name = "DynamicPitch",
          disabled = function() return not cosFix.db.profile.enabled end,
          inline = true,
          args = {
            test_cameraDynamicPitchBaseFovPad = {
              order = 1,
              type = 'range',
              name = "BaseFovPad",
              desc = "Adjusting how far the camera is pitched up or down. The value of 1.0 disables the setting.",
              min = 0,
              max = 1,
              step = .01,
              width = 1.08,
              get = function() return cosFix.db.profile.cvars.test_cameraDynamicPitchBaseFovPad end,
              set = function(_, newValue)
                      cosFix.db.profile.cvars.test_cameraDynamicPitchBaseFovPad = newValue
                      SetCVar("test_cameraDynamicPitch", 1)
                      SetCVar("test_cameraDynamicPitchBaseFovPad", newValue)
                    end,
            },
            test_cameraDynamicPitchBaseFovPadFlying = {
              order = 2,
              type = 'range',
              name = "BaseFovPad (Flying)",
              desc = "The same as BaseFovPad for while you are flying.",
              min = .01,
              max = 1,
              step = .01,
              width = 1.08,
              get = function() return cosFix.db.profile.cvars.test_cameraDynamicPitchBaseFovPadFlying end,
              set = function(_, newValue)
                      cosFix.db.profile.cvars.test_cameraDynamicPitchBaseFovPadFlying = newValue
                      SetCVar("test_cameraDynamicPitch", 1)
                      SetCVar("test_cameraDynamicPitchBaseFovPadFlying", newValue)
                    end,
            },
            test_cameraDynamicPitchBaseFovPadDownScale = {
              order = 3,
              type = 'range',
              name = "BaseFovPadDownScale",
              desc = "A multiplier for how much pitch is applied. Higher values allow the character to be further down the screen.",
              min = .0,
              max = 1,
              step = .01,
              width = 1.08,
              get = function() return cosFix.db.profile.cvars.test_cameraDynamicPitchBaseFovPadDownScale end,
              set = function(_, newValue)
                      cosFix.db.profile.cvars.test_cameraDynamicPitchBaseFovPadDownScale = newValue
                      SetCVar("test_cameraDynamicPitch", 1)
                      SetCVar("test_cameraDynamicPitchBaseFovPadDownScale", newValue)
                    end,
            },
          },
        },
        restoreDefaults = {
          order = 5,
          type = 'execute',
          name = "Restore defaults",
          disabled = function() return not cosFix.db.profile.enabled end,
          desc = "Restore settings to the preference of the " .. folderName .. " developer.",
          width = "full",
          func = function()
                  for variable, value in pairs(defaults.profile.cvars) do
                    cosFix.db.profile.cvars[variable] = value
                    SetCVar(variable, value)
                  end
                end,
        },
      },
    },
  },
}


function cosFix:InitializeDatabase()
  self.db = LibStub("AceDB-3.0"):New("cosFixDB", defaults, true)
end


function cosFix:OpenOptionsMenu()
  InterfaceOptionsFrame_OpenToCategory(self.optionsMenu)
  InterfaceOptionsFrame_OpenToCategory(self.optionsMenu)
end


function cosFix:OpenSetFactorFrame()
  self.setFactorFrame:Show()
end


function cosFix:InitializeOptions()

  LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable(folderName, optionsTable)

  self.optionsMenu = LibStub("AceConfigDialog-3.0"):AddToBlizOptions(folderName, folderName)

  self:RegisterChatCommand(folderName, "OpenOptionsMenu")
  self:RegisterChatCommand("cosfix", "OpenOptionsMenu")
  self:RegisterChatCommand("cf", "OpenOptionsMenu")
  self:RegisterChatCommand("defineOffset", "OpenSetFactorFrame")
  self:RegisterChatCommand("cfdo", "OpenSetFactorFrame")

end

