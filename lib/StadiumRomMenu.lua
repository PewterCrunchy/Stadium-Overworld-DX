-- Pokemon Stadium ROM menu bridge
--
-- v0.1.14: primary UI is this mod's own Mod Manager -> Options screen.
-- Gen1Recomp's standard option schema has toggles/choices/numbers/text but no
-- native "action" row, so we register a supported placeholder choice and then
-- replace only that generated row with a file-picker activate callback.
-- The older general OPTIONS hook is retained solely as a compatibility fallback.
--
-- Preferred path: delegate to Dramatic Shape's own StadiumRomPick module when
-- it exists.  Android: always use gen1recomp's native document picker before any Dramatic Shape helper.  The
-- Android bridge delivers a chosen file as picked_rom.gb regardless of the
-- source extension. We validate the N64 byte-order magic, normalize the data
-- to z64 byte order when needed, then stage the exact path Dramatic Shape asks
-- for: baseroms/baserom.z64.
local V = ...
local M = {}

local PICKED_ROM = "picked_rom.gb"
local PICKED_STADIUM = "picked_stadium.z64"
local PENDING_FLAG = "stadium_overworld_picker_pending.flag"

-- Android compatibility note:
-- Gen1Recomp's currently deployed native picker copies the generic "rom"
-- selection to picked_rom.gb.  Some voxel-host/mobile builds already reserve
-- a dedicated picked_stadium.z64 target.  Watch both names so the companion
-- works with either bridge without another release.

local function text(s, ...)
  local ok, Strings = pcall(require, "src.core.Strings")
  if ok and type(Strings) == "function" then
    local okText, value = pcall(Strings, s, ...)
    if okText then return value end
  end
  if select("#", ...) > 0 then
    local okFmt, value = pcall(string.format, s, ...)
    if okFmt then return value end
  end
  return s
end

local function picker()
  -- v0.1.69-local test15:
  -- Diagnostic wrapper. If StadiumRomPick fails to load, write the exact
  -- pcall result/error instead of silently returning nil.
  local DEBUG_NAME = "stadium_overworld_test15_picker_require.txt"

  local function dbg(message)
    local f = love and love.filesystem
    if not (f and type(f.write) == "function") then return end

    local old = ""
    if type(f.read) == "function" then
      local okRead, prev = pcall(f.read, DEBUG_NAME)
      if okRead and type(prev) == "string" then old = prev end
    end

    pcall(f.write, DEBUG_NAME, old .. tostring(message or "") .. "\n")
  end

  dbg("picker() called")

  local okReqFunc, reqFunc = pcall(function()
    return V and V.require
  end)

  dbg("V.require lookup ok=" .. tostring(okReqFunc)
    .. " type=" .. type(reqFunc)
    .. " value=" .. tostring(reqFunc))

  if not (okReqFunc and type(reqFunc) == "function") then
    dbg("No usable V.require")
    return nil
  end

  local ok, p = pcall(reqFunc, "StadiumRomPick")

  dbg("V.require('StadiumRomPick') ok=" .. tostring(ok)
    .. " type=" .. type(p)
    .. " value=" .. tostring(p))

  if not ok then
    dbg("require error: " .. tostring(p))
    return nil
  end

  if type(p) ~= "table" then
    dbg("require returned non-table")
    return nil
  end

  dbg("picker loaded table. import type=" .. type(p.import)
    .. " row type=" .. type(p.row)
    .. " canDialog type=" .. type(p.canDialog))

  return p
end
local function rawRow()
  local p = picker()
  if not p or type(p.row) ~= "function" then return nil end
  local ok, row = pcall(p.row)
  if not ok then ok, row = pcall(p.row, p) end
  if ok and type(row) == "table" then return row end
  return nil
end

local function safeRemove(path)
  if love and love.filesystem and love.filesystem.remove then
    pcall(love.filesystem.remove, path)
  end
end

local function setStatus(value)
  M._status = value
end

local function pickedPath()
  if not (love and love.filesystem and love.filesystem.getInfo) then return nil end
  if love.filesystem.getInfo(PICKED_STADIUM, "file") then return PICKED_STADIUM end
  if love.filesystem.getInfo(PICKED_ROM, "file") then return PICKED_ROM end
  return nil
end

local function stadiumReady()
  local ok, install = pcall(V.require, "StadiumInstall")
  if not ok or type(install) ~= "table" or type(install.ready) ~= "function" then
    return false
  end
  local okReady, ready = pcall(install.ready)
  if not okReady then okReady, ready = pcall(install.ready, install) end
  return okReady and ready == true
end

local function cleanupStagingIfReady()
  if not stadiumReady() then return false end
  -- The ROM is only an import source.  Once all Stadium packs are current,
  -- remove any Android picker leftovers so a later boot cannot mistake them
  -- for a fresh import.
  safeRemove(PENDING_FLAG)
  safeRemove(PICKED_ROM)
  safeRemove(PICKED_STADIUM)
  setStatus("READY")
  return true
end

-- v0.1.61-local test7:
-- The old Options hook calls M.poll() while building/displaying the OPTIONS
-- rows.  M.poll() referenced notifyDramaticShape(), but this helper was not
-- defined in v0.1.56, causing Gen1Recomp v0.1.98 to crash as soon as the
-- normal START -> OPTIONS menu opened.  Keep this deliberately defensive:
-- desktop/legacy StadiumRomPick may expose poll/update/step, or nothing.
local function notifyDramaticShape(game)
  local p = picker()
  if type(p) ~= "table" then return false end

  for _, name in ipairs({ "poll", "update", "step" }) do
    local fn = p[name]
    if type(fn) == "function" then
      local ok, result = pcall(fn, game)
      if not ok then ok, result = pcall(fn, p, game) end
      if ok and result ~= nil then return result end
    end
  end

  return false
end

local function n64Format(data)
  if type(data) ~= "string" or #data < 4 then return nil end
  local a, b, c, d = data:byte(1, 4)
  if a == 0x80 and b == 0x37 and c == 0x12 and d == 0x40 then return "z64" end
  if a == 0x37 and b == 0x80 and c == 0x40 and d == 0x12 then return "v64" end
  if a == 0x40 and b == 0x12 and c == 0x37 and d == 0x80 then return "n64" end
  return nil
end

local function resolveGame(game)
  if game and game.stack then return game end
  local ok, Game = pcall(require, "src.core.Game")
  if ok and Game and Game.stack then return Game end
  return game
end

local function pushBuildScreen(game)
  game = resolveGame(game)
  if not (game and game.stack) then return false end
  local okScreen, StadiumScreen = pcall(V.require, "StadiumScreen")
  if not (okScreen and type(StadiumScreen) == "table"
      and type(StadiumScreen.new) == "function") then return false end
  local ok = pcall(function()
    game.stack:push(StadiumScreen.new(game, true))
  end)
  return ok
end

local function failAndroid(game, why)
  local okInstall, install = pcall(V.require, "StadiumInstall")
  if okInstall and type(install) == "table" and type(install.status) == "table" then
    install.status.state = "failed"
    install.status.error = tostring(why or "could not import Stadium ROM")
  end
  safeRemove(PENDING_FLAG)
  safeRemove(PICKED_ROM)
  safeRemove(PICKED_STADIUM)
  setStatus("IMPORT ERROR")
  pushBuildScreen(game)
  return true, why
end

local function consumeAndroidPick(game)
  if not (love and love.filesystem and love.filesystem.getInfo
      and love.filesystem.read) then
    return false
  end
  if not love.filesystem.getInfo(PENDING_FLAG, "file") then return false end

  local source = pickedPath()
  if not source then return false end

  -- Do not consume the only copy until the game stack exists. Android may
  -- recreate the process while the system document picker is open; leaving
  -- the file in place lets game.ready finish the import safely afterwards.
  game = resolveGame(game)
  if not (game and game.stack) then return false end

  local data, err = love.filesystem.read(source)
  if type(data) ~= "string" then
    return failAndroid(game, err or "could not read selected file")
  end

  -- Reject obvious wrong picks here. StadiumRom.open performs the full
  -- normalization/validation again, including .v64 and .n64 byte order.
  if not n64Format(data) then
    return failAndroid(game, "selected file is not an N64 ROM image")
  end

  local okInstall, install = pcall(V.require, "StadiumInstall")
  if not (okInstall and type(install) == "table"
      and type(install.beginFrom) == "function") then
    return failAndroid(game, "voxel host has no Stadium importer")
  end

  -- Mobile v0.1.56: feed the picked bytes straight to the voxel host. The
  -- previous path wrote a second 32 MB copy into baseroms and required a
  -- restart, then the host read that entire copy again. Direct beginFrom is
  -- exactly the desktop import path and avoids that extra disk/memory churn.
  local okBegin, started, beginErr = pcall(install.beginFrom, data, source)
  if not okBegin then
    return failAndroid(game, started)
  end
  if not started then
    return failAndroid(game, beginErr or "Stadium ROM was rejected")
  end

  safeRemove(source)
  safeRemove(PENDING_FLAG)
  safeRemove(PICKED_ROM)
  safeRemove(PICKED_STADIUM)
  setStatus("IMPORTING")

  if not pushBuildScreen(game) then
    -- Keep a marker so game.ready / the manager update can attach the screen
    -- that drives StadiumInstall.step(). The build itself remains alive.
    pcall(love.filesystem.write, PENDING_FLAG, "build-screen\n")
  end
  return true
end

function M.poll(game)
  if cleanupStagingIfReady() then return true end

  -- Consume OUR Android SAF result before any Dramatic Shape legacy picker.
  -- On Android we deliberately do not call StadiumRomPick.poll(): the ROM
  -- staging file is enough for StadiumInstall on the next overworld boot and
  -- avoids legacy picker/import state interfering with the voxel pipeline.
  local consumed = consumeAndroidPick(game)
  local osName = love and love.system and love.system.getOS and love.system.getOS() or nil
  if osName ~= "Android" and not consumed then notifyDramaticShape(game) end
  return consumed and true or false
end

local function invokeRow(row, game)
  if type(row) ~= "table" then return false end

  -- v0.1.64-local test10:
  -- On modern Gen1Recomp, the legacy Stadium picker row may expose both
  -- activate and step.  The activate path can return successfully while doing
  -- nothing visible, which prevents the real picker action from running.
  -- Prefer step first because OptionsMenu.lua uses step for normal option-row
  -- actions when activate is absent.
  if type(row.step) == "function" then
    local ok, result = pcall(row.step, game, 1)
    if not ok then ok, result = pcall(row.step, row, game, 1) end
    if ok and result ~= false then return true end
  end

  if type(row.activate) == "function" then
    local ok, result = pcall(row.activate, game)
    if not ok then ok, result = pcall(row.activate, row, game) end
    if ok and result ~= false then return true end
  end

  return false
end

local function startAndroidPicker()
  if not (love and love.system and type(love.system.pickFile) == "function"
      and love.filesystem and type(love.filesystem.write) == "function") then
    setStatus("NO PICKER")
    return false
  end

  -- Mark ownership before opening Android's external Files/Documents activity.
  -- If Android kills and recreates the app while that activity is open, the
  -- flag survives and the next mod load can still consume picked_rom.gb.
  pcall(love.filesystem.write, PENDING_FLAG, "stadium\n")
  safeRemove(PICKED_ROM)
  safeRemove(PICKED_STADIUM)
  setStatus("PICK...")

  -- Gen1Recomp currently recognizes rom/mod/sav kinds.  "rom" opens the
  -- general Android document picker and copies the chosen file to
  -- picked_rom.gb.  The original file may be .z64/.v64/.n64; our validator
  -- above identifies its actual byte order after the picker returns.
  local ok, launched = pcall(love.system.pickFile, "rom")
  if not ok or not launched then
    safeRemove(PENDING_FLAG)
    setStatus("NO PICKER")
    return false
  end
  return true
end

function M.choose(game)
  -- IMPORTANT: on Android, bypass Dramatic Shape's legacy row completely.
  -- Its action opens the in-game "PUT STADIUM US 1.0 HERE" instruction screen
  -- seen in older builds. Gen1Recomp's love.system.pickFile instead launches
  -- Android's real Storage Access Framework / Files app.
  local osName = love and love.system and love.system.getOS and love.system.getOS() or nil
  if osName == "Android" then
    if startAndroidPicker() then return true end
    setStatus("NO ANDROID PICKER")
    return false
  end

  -- Desktop/other-platform compatibility: use Dramatic Shape's own action when
  -- available because it owns the exact Stadium validation/build pipeline.
  local row = rawRow()
  if invokeRow(row, game) then return true end

  local p = picker()
  if p then
    for _, name in ipairs({ "choose", "pick", "open", "start", "request" }) do
      local fn = p[name]
      if type(fn) == "function" then
        local ok, result = pcall(fn, game)
        if not ok then ok, result = pcall(fn, p, game) end
        if ok and result ~= false then return true end
      end
    end
  end

  return startAndroidPicker()
end

local function labelString(row)
  if type(row) ~= "table" then return "" end
  local ok, s = pcall(tostring, row.label)
  return ok and (s or "") or ""
end

local function stadiumRowIndex(out, upstreamId)
  for i, row in ipairs(out) do
    if type(row) == "table" then
      if upstreamId ~= nil and row.id == upstreamId then return i end
      if row.id == "stadium_overworld:rom_file" then return i end
      local label = labelString(row):upper()
      if label:find("STADIUM", 1, true) and label:find("ROM", 1, true) then
        return i
      end
    end
  end
  return nil
end

local function insertionIndex(out)
  -- Put it immediately before MODS whenever possible so it is easy to find,
  -- even if an older OPTIONS menu does not group render-pipeline rows.
  for i, row in ipairs(out) do
    if type(row) == "table" and row.id == "mods" then return i end
  end
  return #out + 1
end

local function valueFromSource(source, game)
  if type(source) ~= "table" then return nil end
  local value = source.value
  if type(value) == "function" then
    local ok, result = pcall(value, game)
    if not ok then ok, result = pcall(value, source, game) end
    if ok and result ~= nil then return result end
  elseif value ~= nil then
    return value
  end
  return nil
end

local function makeRow(source)
  local out = {}
  if type(source) == "table" then
    for k, v in pairs(source) do out[k] = v end
  end

  out.id = (type(source) == "table" and source.id) or "stadium_overworld:rom_file"
  out.label = text("STADIUM ROM FILE")
  out.step = nil

  out.value = function(game)
    M.poll(game)
    if M._status then return text(M._status) end
      local upstream = valueFromSource(source, game)
    if upstream ~= nil then return upstream end
    return text("CHOOSE")
  end

  -- v0.1.66-local test12:
  -- Test11 proved START -> OPTIONS calls row.activate for A/Confirm.
  -- Do not delegate through the legacy StadiumRomPick.row() because that row
  -- wraps StadiumRomPick.import() in pcall and can fail silently.  Call the
  -- import function directly so we can show/log the real result.
  local function resolveRowGame(a, b, c)
    if type(a) == "table" and a.stack then
      return a
    elseif type(b) == "table" and b.stack then
      return b
    elseif type(c) == "table" and c.stack then
      return c
    end
    return resolveGame(a)
  end

  local function writeDebug(message)
    local text = tostring(message or "")
    local f = love and love.filesystem
    if f and type(f.write) == "function" then
      pcall(f.write, "stadium_overworld_test12_error.txt", text)
    end
    pcall(function()
      if V and V.mod and V.mod.log then
        V.mod.log:warn("Stadium Test12: %s", text)
      end
    end)
  end

  local function runDirectImport(game)
    local p = picker()
    if type(p) ~= "table" then
      setStatus("NO PICKER")
      writeDebug("picker() did not return a table")
      return true
    end

    if type(p.import) ~= "function" then
      setStatus("NO IMPORT")
      writeDebug("StadiumRomPick.import is missing; available fields checked")
      return true
    end

    setStatus("OPENING...")
    local ok, result = pcall(p.import, game)

    if not ok then
      setStatus("IMPORT ERR")
      writeDebug(result)
      return true
    end

    if result then
      setStatus("IMPORTING")
    else
      -- false can mean cancelled dialog, no dialog, or import refused.
      -- Keep it visible for this diagnostic build.
      setStatus("NO PICK")
      writeDebug("StadiumRomPick.import returned false/nil")
    end

    return true
  end

  out.activate = function(a, b, c)
    return runDirectImport(resolveRowGame(a, b, c))
  end

  -- Not normally used while activate exists, but keep it for compatibility.
  out.step = function(a, b, c)
    return runDirectImport(resolveRowGame(a, b, c))
  end

  return out
end

function M.ensureRow(rows, game)
  if type(rows) ~= "table" then return rows end
  M.poll(game)
  local source = rawRow()
  local row = makeRow(source)
  local at = stadiumRowIndex(rows, source and source.id or nil)
  if at then
    rows[at] = row
  else
    table.insert(rows, insertionIndex(rows), row)
  end
  return rows
end

function M.installOptionsHook(mod)
  if M._installed then return true end
  local installedAny = false

  -- Preferred modern extension point.
  if mod and mod.hooks and type(mod.hooks.wrap) == "function" then
    local ok = pcall(function()
      mod.hooks:wrap("ui.options.rows", function(next, game, rows)
        local out = next(game, rows)
        return M.ensureRow(out, game)
      end)
    end)
    installedAny = ok or installedAny
  end

  -- Compatibility fallback: some released Gen1Recomp builds predate (or do
  -- not dispatch) ui.options.rows.  Patch OptionsMenu.new itself as well.  On
  -- current builds this only sees that the hook already inserted our row and
  -- replaces it in-place, so there is never a duplicate.
  local okMenu, OptionsMenu = pcall(require, "src.ui.OptionsMenu")
  if okMenu and type(OptionsMenu) == "table" and type(OptionsMenu.new) == "function"
      and not OptionsMenu._stadiumOverworldRomMenuPatched then
    local originalNew = OptionsMenu.new
    OptionsMenu.new = function(game, opts)
      local menu = originalNew(game, opts)
      if type(menu) == "table" and type(menu.rows) == "table" then
        M.ensureRow(menu.rows, game)
      end
      return menu
    end
    OptionsMenu._stadiumOverworldRomMenuPatched = true
    installedAny = true
  end

  M._installed = installedAny
  return installedAny
end

-- Value shown beside STADIUM ROM FILE in the per-mod options screen.
function M.value(game)
  M.poll(game)
  if M._status then return text(M._status) end
  local source = rawRow()
  local upstream = valueFromSource(source, game)
  if upstream ~= nil then return upstream end
  return text("CHOOSE")
end

-- Gen1Recomp exposes per-mod options from an options_schema, but its published
-- row types do not include a generic button/action.  Patch only the generated
-- row belonging to this mod so A/Confirm opens the ROM picker instead of merely
-- cycling a dummy choice.  No other mod's options are changed.
function M.installModManagerOptions(mod)
  if M._managerInstalled then return true end

  local okManager, ManagerState = pcall(require, "src.mods.ManagerState")
  if not okManager or type(ManagerState) ~= "table"
      or type(ManagerState.buildOptionRows) ~= "function" then
    return false
  end

  local modId = (mod and mod.id) or "STADIUM_OVERWORLD_MODELS"
  local originalBuild = ManagerState.buildOptionRows

  -- Avoid stacking wrappers if a loader hot-reloads this mod.
  if not ManagerState._stadiumOverworldRomOptionsPatched then
    ManagerState.buildOptionRows = function(self, m, schema)
      local rows = originalBuild(self, m, schema)
      if type(rows) ~= "table" or not m or m.id ~= modId then
        return rows
      end

      for _, row in ipairs(rows) do
        if type(row) == "table" and row.id == "stadiumRomFile" then
          row.label = text("STADIUM ROM FILE")
          row.value = function()
            return M.value(self.game)
          end
          row.activate = function()
            local ok = M.choose(self.game)
            if self.notify then
              self:notify(ok and "ROM PICKER OPENED" or "ROM PICKER UNAVAILABLE")
            end
            return ok
          end
          row.step = function()
            return row.activate()
          end
          break
        end
      end
      return rows
    end
    ManagerState._stadiumOverworldRomOptionsPatched = true
  end

  -- Keep polling while the Mod Manager is active. On Android the native
  -- document picker returns asynchronously; this consumes the result on the
  -- first resumed frame instead of relying on the option row being redrawn or
  -- requiring another button press.
  if type(ManagerState.update) == "function"
      and not ManagerState._stadiumOverworldRomPollPatched then
    local originalUpdate = ManagerState.update
    ManagerState.update = function(self, dt, ...)
      pcall(M.poll, self and self.game)
      return originalUpdate(self, dt, ...)
    end
    ManagerState._stadiumOverworldRomPollPatched = true
  end

  M._managerInstalled = true
  return true
end

function M.available()
  -- The picker is available even without Dramatic Shape's optional helper;
  -- Android native-pick fallback is handled by M.choose.
  return true
end

-- If Android recreated the process while the document picker was open, finish
-- staging immediately on load instead of waiting for OPTIONS to be reopened.
pcall(M.poll, nil)

return M
