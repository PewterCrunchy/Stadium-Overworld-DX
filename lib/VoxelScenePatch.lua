-- Pokemon Stadium Overworld Models: compatibility-first VoxelScene patcher.
--
-- v0.1.16 deliberately avoids a frozen copy of Dramatic Shape's renderer AND
-- avoids matching whole comment-heavy functions.  It reads the VoxelScene.lua
-- that is actually installed and changes only three required structural seams:
--   1. posesOf() records the backing entity on each pose,
--   2. drawCast() asks OverworldStadium before drawing the 2D card,
--   3. render() prepares Stadium models immediately after pose capture.
--
-- Shadow integration is best-effort so an older/newer Dramatic Shape shadow
-- implementation cannot prevent the visible 3D Pokemon path from installing.
local V = ...
local M = {}

local function safeLog(mod, level, fmt, ...)
  local log = mod and mod.log
  local fn = log and log[level]
  if type(fn) == "function" then pcall(fn, log, fmt, ...) end
end

local function readInstalled(BaseV, rel)
  local owner = BaseV and BaseV.mod
  if not owner or type(owner.read) ~= "function" then
    return nil, "Dramatic Shape exported library has no owning mod read()"
  end
  local ok, source, err = pcall(owner.read, owner, rel)
  if not ok then return nil, tostring(source) end
  if type(source) ~= "string" then
    return nil, tostring(err or "read returned no source")
  end
  if source:sub(1, 3) == "\239\187\191" then source = source:sub(4) end
  -- Make structural anchors independent of checkout line endings.
  source = source:gsub("\r\n", "\n"):gsub("\r", "\n")
  return source
end

local function countPlain(s, needle)
  local n, at = 0, 1
  while true do
    local a, b = s:find(needle, at, true)
    if not a then return n end
    n, at = n + 1, b + 1
  end
end

local function replaceOnce(s, old, new, label)
  local n = countPlain(s, old)
  if n ~= 1 then
    return nil, ((n == 0 and "missing" or "ambiguous") ..
      " VoxelScene anchor: " .. tostring(label) .. " (" .. tostring(n) .. ")")
  end
  local a, b = s:find(old, 1, true)
  return s:sub(1, a - 1) .. new .. s:sub(b + 1)
end

local function insertAfterOnce(s, needle, text, label)
  local n = countPlain(s, needle)
  if n ~= 1 then
    return nil, ((n == 0 and "missing" or "ambiguous") ..
      " VoxelScene anchor: " .. tostring(label) .. " (" .. tostring(n) .. ")")
  end
  local _, b = s:find(needle, 1, true)
  return s:sub(1, b) .. text .. s:sub(b + 1)
end

local POSES = [====[local function posesOf(state, spriteColors)
  -- Claim Wilds' emergency 2D bodies before its overlay gets a chance to draw
  -- a second copy.  This function is non-throwing in v0.1.16.
  OverworldStadium.safeClaimWilds(state)

  -- v0.1.79-local test31:
  -- DRAMALESS_SHAPE v2.x uses the reusable poseBuf/poseSlot renderer.  The
  -- older Stadium patch replaced posesOf() with a fresh local `posed = {}`
  -- table, which let the structural patch install but disrupted the v2
  -- overworld renderer.  Preserve v2's poseBuf/n/poseSlot behavior while
  -- adding Stadium's entity metadata and rescue handling.
  local colors = spriteColors(state.map)
  local n, me = 0, nil

  for gi, g in ipairs(state.ghosts or {}) do
    local npc = g and g.npc
    if npc and type(npc.pose) == "function" then
      local sprite, vx, vy, facing, phase, flip = npc:pose()
      local ghostMap = g.map or state.map

      n = n + 1
      local p = poseSlot(n)

      p.sprite = sprite
      p.px = (vx or npc.px or 0) + (g.ox or 0)
      p.py = (npc.py or vy or 0) + (g.oy or 0)
      p.facing, p.phase, p.flip = facing, phase, flip
      p.gh = groundAt(ghostMap, npc.cellX, npc.cellY)
      p.lift = (npc.py or vy or 0) - (vy or npc.py or 0)
      p.colors = spriteColors(ghostMap)
      p.entity = npc
      p.entityIndex = gi
      p.mapId = ghostMap and ghostMap.id
    end
  end

  for ei, e in ipairs(state.entities or {}) do
    -- Dramatic/Dramaless normally omits the player during Fly because the
    -- engine's 2D Fly overlay draws it separately. Followers EX can turn the
    -- PLAYER entity itself into a Pokemon; in that case keep it in the Stadium
    -- cast even while flyAnim is active. Ordinary human players still follow
    -- the stock skip rule, avoiding a duplicate trainer.
    local playerPokemonDuringFly = e == state.player and type(e) == "table"
      and (e._pokepcAsPokemon == true or e._pokepcControlSpecies ~= nil
           or e.pokepcControlSpecies ~= nil)

    if not (state.flyAnim and e == state.player and not playerPokemonDuringFly) then
      local okPose, sprite, vx, vy, facing, phase, flip = false, nil, nil, nil, nil, nil, nil

      if type(e.pose) == "function" then
        okPose, sprite, vx, vy, facing, phase, flip = pcall(e.pose, e)
      end

      if (not okPose or sprite == nil) and OverworldStadium.canRescuePose(e) then
        if type(e.getWorldSprite) == "function" then
          local okSprite, got = pcall(e.getWorldSprite, e)
          if okSprite and got then sprite = got end
        end

        sprite = sprite or e.sprite
        vx = vx or e.px or 0
        vy = vy or e.py or 0
        facing = facing or e.facing or "down"
        phase = phase or e.phase or 0
        flip = flip == true or e.stepFlip == true or e.flip == true
        okPose = true
      end

      -- Preserve Dramatic/Dramaless' normal behavior for an ordinary
      -- non-Pokemon whose pose() genuinely failed. Stadium compatibility must
      -- not hide a renderer bug elsewhere in the world.
      if not okPose then
        error(sprite or "entity pose failed", 0)
      end

      local px = vx or e.px or 0
      local py = e.py or vy or 0
      local cellX, cellY = e.cellX, e.cellY

      if type(cellX) ~= "number" then cellX = math.floor(px / 16) end
      if type(cellY) ~= "number" then cellY = math.floor(py / 16) end

      local okGround, gh = pcall(groundAt, state.map, cellX, cellY)
      if not okGround then gh = 0 end

      n = n + 1
      local p = poseSlot(n)

      p.sprite = sprite
      p.px = px
      p.py = py
      p.facing, p.phase, p.flip = facing, phase, flip
      p.gh = gh
      p.lift = py - (vy or py)
      p.colors = colors
      p.entity = e
      p.entityIndex = ei
      p.mapId = state.map and state.map.id

      if e == state.player then
        me = p
        me.isPlayer = true
      end
    end
  end

  for i = n + 1, #poseBuf do poseBuf[i] = nil end
  return poseBuf, me
end]====]

-- Find the actual posesOf function by its declaration and its own return. This
-- survives comment changes and additions around the function across releases.
local function patchPoses(source)
  local start = source:find("local function posesOf", 1, true)
  if not start then return nil, "missing VoxelScene posesOf()" end

  -- v0.1.78-local test27:
  -- DRAMALESS_SHAPE v2.x rewrote posesOf() to use poseBuf/n instead of the
  -- older local posed table.  The old patcher only recognized:
  --   return posed, me
  -- so it failed with "could not locate end of VoxelScene posesOf()".
  -- Accept both old and new endings.
  local endings = {
    "  return posed, me\nend",
    "return posed, me\nend",
    "  return poseBuf, me\nend",
    "return poseBuf, me\nend",
    "  return poseBuf, me, n\nend",
    "return poseBuf, me, n\nend",
  }

  local bestA, bestB
  for _, ending in ipairs(endings) do
    local a, b = source:find(ending, start, true)
    if a and (not bestA or a < bestA) then
      bestA, bestB = a, b
    end
  end

  if bestA then
    return source:sub(1, start - 1) .. POSES .. source:sub(bestB + 1)
  end

  -- Last-resort DRAMALESS v2 fallback:
  -- In the v2 renderer, posesOf() sits immediately before the glint constants.
  -- If the exact return line changes again, cut from the posesOf declaration
  -- to the next stable VoxelScene section marker.
  local markers = {
    "\nVoxelScene.GLINT_RATE",
    "\nfunction VoxelScene.glintStep",
    "\nVoxelScene.drawWater",
    "\nfunction VoxelScene.render",
  }

  local nextA
  for _, marker in ipairs(markers) do
    local a = source:find(marker, start, true)
    if a and (not nextA or a < nextA) then nextA = a end
  end

  if nextA then
    return source:sub(1, start - 1) .. POSES .. source:sub(nextA)
  end

  return nil, "could not locate end of VoxelScene posesOf()"
end

-- Replace only the character loop inside drawCast, leaving every terrain,
-- figure, grass, glass and reflection detail from the installed DS untouched.
local function patchCastLoop(source)
  -- Newer Dramatic Shape releases route character drawing through drawCast().
  -- Patch that seam when present.
  local fn = source:find("local function drawCast", 1, true)
  if fn then
    local a = source:find("  local hideMe = FirstPerson.hidePlayer()", fn, true)
    if not a then
      a = source:find("local hideMe = FirstPerson.hidePlayer()", fn, true)
    end
    if not a then return nil, "missing drawCast player-hide seam" end

    local glass = source:find("  Voxel3D.glass(true)", a, true)
    if not glass then glass = source:find("Voxel3D.glass(true)", a, true) end
    if not glass then return nil, "missing drawCast glass restore seam" end

    local block = [====[  local hideMe = FirstPerson.hidePlayer()
  for _, p in ipairs(posed) do
    if not (p.isPlayer and hideMe) and not OverworldStadium.safeShouldHidePose(p) then
      -- safeDraw never throws. Returning false means this one entity uses
      -- Dramatic Shape's original 2D card for this frame.
      local stadiumDidDraw = OverworldStadium.safeDraw(p)

      if stadiumDidDraw then
        -- v0.1.90-local test51:
        -- Keep DRAMALESS v2's character-card render state intact after drawing
        -- a Stadium model. drawCast() expects character cards to be drawn with
        -- glass/seams disabled until the figure pass restores them later.
        -- Do NOT reset global LOVE shader/blend state here; Test47 showed that
        -- was too invasive.
        pcall(Voxel3D.glass, false)
        pcall(Voxel3D.seams, false)
      end

      if not stadiumDidDraw and p.sprite then
        drawEntity(p.sprite, p.px, p.py, viewFacing(p), p.phase, p.flip, p.gh,
                   p.colors, p.lift)
      end
    end
  end
]====]
    return source:sub(1, a - 1) .. block .. source:sub(glass), "drawCast"
  end

  -- Older/derived forks (notably the 1.0.x renderer family) have no
  -- drawCast() helper. Their final character pass lives directly inside
  -- VoxelScene.render(). Replace ONLY that exact final loop; shadow/signature
  -- loops remain untouched. This keeps the same fork's terrain/camera code.
  local variants = {
[====[  for _, p in ipairs(posed) do
    drawEntity(p.sprite, p.px, p.py, p.facing, p.phase, p.flip, p.gh,
               p.colors, p.lift)
  end
]====],
[====[  for _, p in ipairs(posed) do
    drawEntity(p.sprite, p.px, p.py, p.facing, p.phase, p.flip, p.gh, p.colors, p.lift)
  end
]====],
  }

  local old
  for _, candidate in ipairs(variants) do
    if countPlain(source, candidate) == 1 then
      old = candidate
      break
    end
  end
  if not old then
    return nil, "missing both modern drawCast seam and legacy render character loop"
  end

  local block = [====[  for _, p in ipairs(posed) do
    if not OverworldStadium.safeShouldHidePose(p) then
      if not OverworldStadium.safeDraw(p) and p.sprite then
        drawEntity(p.sprite, p.px, p.py, p.facing, p.phase, p.flip, p.gh,
                   p.colors, p.lift)
      end
    end
  end
]====]
  local a, b = source:find(old, 1, true)
  return source:sub(1, a - 1) .. block .. source:sub(b + 1), "legacy-render"
end

local function patchPrepare(source)
  local needle = "  local posed, me = posesOf(state, spriteColors)"
  local n = countPlain(source, needle)
  if n ~= 1 then
    needle = "local posed, me = posesOf(state, spriteColors)"
    n = countPlain(source, needle)
  end
  if n ~= 1 then return nil, "missing/ambiguous render pose-capture seam" end
  local _, b = source:find(needle, 1, true)
  local insertion = [====[
  -- Skin Stadium overworld models once.  Main eye, reflection and shadow
  -- passes consume the prepared geometry.  This call is deliberately safe.
  OverworldStadium.safePrepare(posed)]====]
  return source:sub(1, b) .. insertion .. source:sub(b + 1)
end

local function patchShadowBestEffort(source)
  -- Do not make these anchors prerequisites for visible overworld models.
  -- Different Dramatic Shape releases have changed the shadow implementation
  -- several times.  If this seam exists, add real model geometry to the SUN
  -- pass; otherwise the normal DS sprite shadow remains as a harmless fallback.
  local fn = source:find("local function castShadows", 1, true)
  if not fn then return source, false end
  local a, b = source:find("  ShadowMap.sprites(false)", fn, true)
  if not a then a, b = source:find("ShadowMap.sprites(false)", fn, true) end
  if not a then return source, false end
  local insert = [====[
  -- Stadium overworld geometry is outside the sprite-card flag.
  for _, p in ipairs(posed or {}) do
    if p.stadiumMon then OverworldStadium.safeCast(p, ShadowMap) end
  end]====]
  return source:sub(1, b) .. insert .. source:sub(b + 1), true
end

function M.install(ds, BaseV, namespace, Stadium)
  local scene = BaseV and BaseV.require and BaseV.require("VoxelScene")
  if type(scene) ~= "table" or type(scene.render) ~= "function" then
    return false, "Dramatic Shape VoxelScene is unavailable"
  end
  if scene._stadiumOverworldStructuralPatch then return true end

  local source, err = readInstalled(BaseV, "lib/VoxelScene.lua")
  if not source then return false, err end

  -- Required bridge and table identity. These are tiny, stable declarations.
  source, err = insertAfterOnce(source,
    'local Pokedex = V.require("Pokedex")',
    '\nlocal OverworldStadium = assert(V.OverworldStadium, "STADIUM_OVERWORLD_MODELS: Stadium bridge missing")',
    "Pokedex module bridge")
  if not source then
    -- Some DS revisions do not require Pokedex from VoxelScene. Put the bridge
    -- immediately after the namespace line instead.
    local originalSource = readInstalled(BaseV, "lib/VoxelScene.lua")
    source = originalSource
    source, err = insertAfterOnce(source, "local V = ...",
      '\nlocal OverworldStadium = assert(V.OverworldStadium, "STADIUM_OVERWORLD_MODELS: Stadium bridge missing")',
      "namespace module bridge")
    if not source then return false, err end
  end

  source, err = replaceOnce(source, "local VoxelScene = {}",
    'local VoxelScene = assert(V.OriginalVoxelScene, "STADIUM_OVERWORLD_MODELS: original VoxelScene missing")',
    "VoxelScene table")
  if not source then return false, err end

  source, err = patchPoses(source)
  if not source then return false, err end
  local castPatchMode
  source, castPatchMode = patchCastLoop(source)
  if not source then return false, castPatchMode end
  source, err = patchPrepare(source)
  if not source then return false, err end

  local shadowIntegrated
  source, shadowIntegrated = patchShadowBestEffort(source)

  -- We intentionally do NOT replace scene.render with a global pcall/fallback
  -- anymore.  Every Stadium operation inserted above is non-throwing, so one
  -- broken model falls back to its own sprite instead of disabling every 3D
  -- Pokemon for the rest of the boot.
  namespace.OriginalVoxelScene = scene
  local chunk, compileErr = load(source,
    "@" .. tostring((BaseV and BaseV.path) or "DRAMATIC_SHAPE") ..
    "/lib/VoxelScene.lua+stadium-overworld-v16")
  if not chunk then
    return false, "patched VoxelScene did not compile: " .. tostring(compileErr)
  end

  local original = {
    render = scene.render,
    prefetch = scene.prefetch,
    invalidate = scene.invalidate,
  }
  local ok, returned = pcall(chunk, namespace)
  if not ok then
    scene.render, scene.prefetch, scene.invalidate =
      original.render, original.prefetch, original.invalidate
    return false, "patched VoxelScene failed to initialize: " .. tostring(returned)
  end
  if returned ~= scene or type(scene.render) ~= "function" then
    scene.render, scene.prefetch, scene.invalidate =
      original.render, original.prefetch, original.invalidate
    return false, "patched VoxelScene did not preserve table identity"
  end

  scene._stadiumOverworldStructuralPatch = true
  scene._stadiumOverworldDynamicPatch = true
  scene._stadiumOverworldOwnsWildFilter = true
  -- Wilds uses this as the guard around its emergency-2D filter. We claim a
  -- valid Stadium body ourselves, so letting that outer filter run would hide
  -- the entity before posesOf() can see it.
  scene._owwildRenderWrapped = true

  M.shadowIntegrated = shadowIntegrated and true or false
  safeLog(namespace.mod, "info",
    "Stadium overworld structural renderer installed (layout: %s, 3D shadow seam: %s)",
    tostring(castPatchMode or "unknown"), tostring(M.shadowIntegrated))
  return true
end

return M
