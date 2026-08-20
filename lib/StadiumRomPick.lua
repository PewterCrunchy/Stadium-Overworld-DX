local V = ...
local StadiumRomPick = {}

local StadiumInstall = V.require("StadiumInstall")

StadiumRomPick.PICKED = "picked_stadium.z64"

local DEBUG_NAME = "stadium_overworld_dx_import.txt"

local IMPORT_CANDIDATES = {
  "baserom.z64",
  "baseroms/baserom.z64",
  "imports/baserom.z64",
  "stadium_us_v10_rom",
  "picked_stadium.z64"
}

local function dbg(message)
  local f = love and love.filesystem
  if not (f and type(f.write) == "function") then return end

  local old = ""
  if type(f.read) == "function" then
    local okRead, prev = pcall(f.read, DEBUG_NAME)
    if okRead and type(prev) == "string" then old = prev end
  end

  if #old > 50000 then old = old:sub(#old - 40000) end
  pcall(f.write, DEBUG_NAME, old .. tostring(message or "") .. "\n")
end

local function statusText()
  local s = StadiumInstall and StadiumInstall.status

  if s and s.state == "ready" then return "READY" end
  if s and s.state == "building" then return "BUILDING" end
  if s and s.state == "failed" then return "FAILED" end

  if type(StadiumInstall.available) == "function" then
    local ok, available = pcall(StadiumInstall.available)
    if ok and available then return "READY" end
  end

  return "IMPORT"
end

function StadiumRomPick.canDialog()
  -- Modern beta path uses Gen1Recomp's Mod Manager imported-files button.
  return false
end

function StadiumRomPick.choose()
  return nil
end

function StadiumRomPick.read(path)
  if type(path) ~= "string" or path == "" then
    return nil, "no path"
  end

  if not (io and io.open) then
    return nil, "io.open unavailable"
  end

  local h, err = io.open(path, "rb")
  if not h then return nil, err or "could not open file" end

  local bytes = h:read("*a")
  h:close()

  if type(bytes) ~= "string" or #bytes == 0 then
    return nil, "empty file"
  end

  return bytes
end

local function readViaLove(path)
  local f = love and love.filesystem
  if not (f and type(f.getInfo) == "function" and type(f.read) == "function") then
    return nil
  end

  local okInfo, info = pcall(f.getInfo, path, "file")
  if not (okInfo and info) then return nil end

  local okRead, bytes = pcall(f.read, path)
  if okRead and type(bytes) == "string" and #bytes > 0 then
    return bytes
  end

  return nil
end

local function readViaMod(path)
  if not (V and V.mod and type(V.mod.read) == "function") then return nil end

  local ok, bytes = pcall(function()
    return V.mod:read(path)
  end)

  if ok and type(bytes) == "string" and #bytes > 0 then
    return bytes
  end

  return nil
end

local function readImportedRom()
  dbg("readImportedRom called")

  for _, path in ipairs(IMPORT_CANDIDATES) do
    local bytes = readViaLove(path)
    if bytes then
      dbg("found via love.filesystem: " .. tostring(path) .. " bytes=" .. tostring(#bytes))
      return bytes, path
    end

    bytes = readViaMod(path)
    if bytes then
      dbg("found via mod:read: " .. tostring(path) .. " bytes=" .. tostring(#bytes))
      return bytes, path
    end

    dbg("not found: " .. tostring(path))
  end

  return nil, nil
end

local function fail(game, why)
  StadiumInstall.status.state = "failed"
  StadiumInstall.status.error = why
  dbg("FAIL: " .. tostring(why))

  local okScreen, StadiumScreen = pcall(V.require, "StadiumScreen")
  if okScreen and type(StadiumScreen) == "table" and game and game.stack then
    game.stack:push(StadiumScreen.new(game, true))
  end

  return false
end

local function startBuild(game, bytes, label)
  dbg("startBuild label=" .. tostring(label) .. " bytes=" .. tostring(#(bytes or "")))

  local ok, beginErr = StadiumInstall.beginFrom(bytes, label)
  if not ok then
    return fail(game, tostring(beginErr))
  end

  local okScreen, StadiumScreen = pcall(V.require, "StadiumScreen")
  if okScreen and type(StadiumScreen) == "table" and game and game.stack then
    game.stack:push(StadiumScreen.new(game, true))
  end

  return true
end

function StadiumRomPick.import(game)
  dbg("import called")

  if StadiumInstall.status.state == "building" then
    dbg("already building")
    return false
  end

  local bytes, label = readImportedRom()

  if not bytes then
    dbg("no imported Stadium ROM found")
    return false
  end

  return startBuild(game, bytes, label)
end

function StadiumRomPick.row()
  return {
    label = "STADIUM ROM FILE",
    value = function()
      return statusText()
    end,
    activate = function(game)
      return StadiumRomPick.import(game)
    end,
    step = function(game)
      return StadiumRomPick.import(game)
    end,
  }
end

return StadiumRomPick