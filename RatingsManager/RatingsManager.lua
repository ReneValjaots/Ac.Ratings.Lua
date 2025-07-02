local json = require("json")

function script_path()
  local str = debug.getinfo(1, "S").source:sub(2) -- Remove "@"
  return str:match("(.*[\\/])") or "./" -- Extract directory or fallback
end

local configFilePath = script_path() .. "config.ini"
ac.log("Corrected script path: " .. script_path())
ac.log("Looking for config.ini at: " .. configFilePath)

local function readConfig()
  local f = io.open(configFilePath, "r")
  if not f then return nil, nil end
  local content = f:read("*all")
  f:close()
  
  local installPath = content:match("install_path=(.-)\n")
  local ratingScale = content:match("rating_scale=(%d+)")
  
  return installPath, tonumber(ratingScale) or 10
end

local function writeConfig(path, scale)
  path = path:gsub("\\", "/") -- Convert backslashes to forward slashes
  local f = io.open(configFilePath, "w")
  if f then
    f:write("[Settings]\ninstall_path=" .. path .. "\nrating_scale=" .. scale .. "\n")
    f:close()
    return true
  else
    ac.log("Error: Could not write to config.ini")
    return false
  end
end

local function readRatingScaleFromMainConfig(installPath)
  if not installPath then return 10 end -- Default to 10 if no install path
  
  local configJsonPath = installPath .. "/Resources/config/config.json"
  
  local f = io.open(configJsonPath, "r")
  if not f then
    ac.log("Warning: Could not open main config.json, defaulting to 10-point scale")
    return 10
  end
  
  local content = f:read("*all")
  f:close()
  
  local success, configData = pcall(json.decode, content)
  if not success then
    ac.log("Error: Could not parse main config.json, defaulting to 10-point scale")
    return 10
  end
  
  local ratingScale = tonumber(configData.RatingScaleMaximum) or 10
  return ratingScale
end

local function updateRatingScale(installPath)
  if not installPath then return 10 end
  
  local newScale = readRatingScaleFromMainConfig(installPath)
  
  -- Update the local config file with the new scale
  writeConfig(installPath, newScale)
  
  return newScale
end

local installPath, ratingScale = readConfig()

-- Always check and update rating scale from main config on startup
if installPath then
  local updatedScale = updateRatingScale(installPath)
  if updatedScale ~= ratingScale then
    ratingScale = updatedScale
  end
else
  ratingScale = ratingScale or 10 -- Fallback to 10 if no config exists
end

if not installPath then
  ac.log("Config file missing or install_path not set")
end

local function getCarFolder()
  return ac.getCarID(0)
end

local function loadCarRatings()
  if not installPath then return nil end

  local carFolder = getCarFolder()
  local jsonFilePath = installPath .. "/Resources/cars/" .. carFolder .. "/RatingsApp/ui.json"

  local f = io.open(jsonFilePath, "r")
  if not f then
    ac.log("Error: Could not open JSON file: " .. jsonFilePath)
    return nil
  end

  local content = f:read("*all")
  f:close()
  return json.decode(content), jsonFilePath
end

local function saveCarRatings(carData, jsonFilePath)
  if not carData or not carData.ratings then 
    ac.log("Error: Invalid car data")
    return
  end

  local ratings = carData.ratings

  local ratingKeys = {
    "cornerHandling", "brakes", "realism", "sound",
    "exteriorQuality", "interiorQuality", "dashboardQuality",
    "funFactor", "forceFeedbackQuality"
  }

  local sum, count = 0, 0
  for _, key in ipairs(ratingKeys) do 
    if ratings[key] then
      sum = sum + ratings[key]
      count = count + 1
    end
  end

  ratings.averageRating = count > 0 and (sum / count) or 0

  local f = io.open(jsonFilePath, "w")
  if not f then
    ac.log("Error: Could not write to JSON file: " .. jsonFilePath)
    return
  end

  f:write(json.encode(carData))
  f:close()
  ac.log("Saved updated ratings to: " .. jsonFilePath)
end

local function tabSettings()
  ui.text("Enter the installation path:")
  installPath = ui.inputText("##installPath", installPath or "")
  if ui.button("Save Path") then
    if installPath and installPath ~= "" then
      local newScale = updateRatingScale(installPath)
      if writeConfig(installPath, newScale) then
        ratingScale = newScale
        saveMessage = "Path saved successfully! Please restart the app."
      else
        saveMessage = "Error: Failed to save path."
      end
    else
      saveMessage = "Error: Install path cannot be empty."
    end
  end

  if saveMessage ~= "" then
    ui.text(saveMessage)
  end
end

-- Initial values
local carData, jsonFilePath = loadCarRatings()
local ratings = carData and carData.ratings or {}
local saveConfirmationMessage = ""

local function tabRatings()
  if not carData then
    ui.text("Error: Could not load car data.")
    return
  end

  ratings.cornerHandling = ui.slider("Corner Handling", ratings.cornerHandling or 0, 0, ratingScale, "%.0f")
  ratings.brakes = ui.slider("Brakes", ratings.brakes or 0, 0, ratingScale, "%.0f")
  ratings.realism = ui.slider("Realism", ratings.realism or 0, 0, ratingScale, "%.0f")
  ratings.sound = ui.slider("Sound", ratings.sound or 0, 0, ratingScale, "%.0f")
  ratings.exteriorQuality = ui.slider("Exterior Quality", ratings.exteriorQuality or 0, 0, ratingScale, "%.0f")
  ratings.interiorQuality = ui.slider("Interior Quality", ratings.interiorQuality or 0, 0, ratingScale, "%.0f")
  ratings.dashboardQuality = ui.slider("Dashboard Quality", ratings.dashboardQuality or 0, 0, ratingScale, "%.0f")
  ratings.funFactor = ui.slider("Fun Factor", ratings.funFactor or 0, 0, ratingScale, "%.0f")
  ratings.forceFeedbackQuality = ui.slider("Force Feedback Quality", ratings.forceFeedbackQuality or 0, 0, ratingScale, "%.0f")

  if ui.button("Save Ratings") then
    saveCarRatings(carData, jsonFilePath)
    saveConfirmationMessage = "Car ratings have been saved!"
  end

  if saveConfirmationMessage ~= "" then
    ui.text(saveConfirmationMessage)
  end
end

local function createCheckbox(label, stateKey, sameLine)
  if sameLine then
    ui.sameLine()
  end
  if ui.checkbox(label, ratings[stateKey]) then
    ratings[stateKey] = not ratings[stateKey]
  end
end

local function tabExtraFeatures()
  if not carData then
    ui.text("Error: Could not load car data.")
    return
  end

  -- Dashboard Lights Section
  ui.header("Dashboard Lights")
  ui.columns(2, "DashboardColumns", false)
  
  createCheckbox("Turn Signals", "turnSignalsDashboard", false)
  createCheckbox("ABS On (Flashing)", "absOnFlashing", false)
  createCheckbox("TC On (Flashing)", "tcOnFlashing", false)
  createCheckbox("ABS Off", "absOff", false)
  
  ui.nextColumn()
  
  createCheckbox("TC Off", "tcOff", false)
  createCheckbox("Handbrake", "handbrake", false)
  createCheckbox("Lights", "lightsDashboard", false)
  createCheckbox("Other", "otherDashboard", false)
  
  ui.columns(1)
  ui.text("")

  -- Exterior Section
  ui.header("Exterior Features")
  ui.columns(2, "ExteriorColumns", false)
  
  createCheckbox("Turn Signals", "turnSignalsExterior", false)
  createCheckbox("Good Quality Lights", "goodQualityLights", false)
  createCheckbox("Emergency Brake Lights", "emergencyBrakeLights", false)
  
  ui.nextColumn()
  
  createCheckbox("Fog Lights", "fogLights", false)
  createCheckbox("Sequential Turn Signals", "sequentialTurnSignals", false)
  createCheckbox("Animations", "animations", false)
  
  ui.columns(1)
  ui.text("")

  -- Others Section
  ui.header("Other Features")
  ui.columns(2, "OtherColumns", false)
  
  createCheckbox("Extended Physics", "extendedPhysics", false)
  createCheckbox("Startup Sound", "startupSound", false)
  
  ui.nextColumn()
  
  createCheckbox("Different Displays", "differentDisplays", false)
  createCheckbox("Different Driving Modes", "differentDrivingModes", false)
  
  ui.columns(1)

  if ui.button("Save Extra Features") then
    saveCarRatings(carData, jsonFilePath)
    saveConfirmationMessage = "Car extra features have been saved!"
  end

  ui.sameLine()

  if ui.button("Reset All") then
    local extraFeatureKeys = {
      "turnSignalsDashboard", "absOnFlashing", "tcOnFlashing", "absOff", "tcOff",
      "handbrake", "lightsDashboard", "otherDashboard", "turnSignalsExterior",
      "goodQualityLights", "emergencyBrakeLights", "fogLights", "sequentialTurnSignals",
      "animations", "extendedPhysics", "startupSound", "differentDisplays", "differentDrivingModes"
    }
    
    for _, key in ipairs(extraFeatureKeys) do
      ratings[key] = false
    end
    saveConfirmationMessage = "All extra features have been reset (not saved yet)."
  end

  if saveConfirmationMessage ~= "" then
    ui.text(saveConfirmationMessage)
  end
end

function script.windowMain(dt)
  ui.beginOutline()
  ui.tabBar("TabBarId", function()
    ui.tabItem("Rate Car", tabRatings)
    ui.tabItem("Extra Features", tabExtraFeatures)
    ui.tabItem("Settings", tabSettings)
  end)
  ui.endOutline(rgbm(0, 0, 0, ac.windowFading()), 1)
end