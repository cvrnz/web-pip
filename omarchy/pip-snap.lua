-- Snap picture-in-picture windows to a corner of the window under them.
--
-- A new PiP window opens in the top-right corner of the browser window it came
-- from. Drag it (by itself, or with SUPER + drag) and let go: it slides into the
-- nearest corner of the window it was dropped on. Dropped where there's no
-- window, it snaps to the nearest corner of the screen.
--
-- Hyprland, not the browser, decides where windows go on Wayland, so this lives
-- in the Hyprland config rather than in the extension. PiP windows are the ones
-- Omarchy tags "pip" (default/hypr/apps/pip.lua), which already float and pin them.
--
-- Install: copy to ~/.config/hypr/pip-snap.lua and add require("hypr.pip-snap")
-- to ~/.config/hypr/bindings.lua (or hyprland.lua).

local MARGIN = 16 -- gap between the PiP and the corner it snaps to

-- Where each PiP window was last left, by address, so a click that didn't move
-- it (play, pause, the close button) doesn't snap it. A PiP not in here hasn't
-- been placed yet.
local placed = {}

local function box(window)
  return { x = window.at.x, y = window.at.y, w = window.size.x, h = window.size.y }
end

local function contains(b, x, y)
  return x >= b.x and x < b.x + b.w and y >= b.y and y < b.y + b.h
end

local function is_pip(window)
  for _, tag in ipairs(window.tags or {}) do
    if tag:gsub("%*$", "") == "pip" then
      return true
    end
  end
  return false
end

-- Not hl.get_windows({ tag = "pip" }): the filter wants the exact tag, and a
-- rule-set tag is "pip*".
local function pips()
  local list = {}
  for _, w in ipairs(hl.get_windows() or {}) do
    if w.address and w.mapped and w.floating and is_pip(w) then
      list[#list + 1] = w
    end
  end
  return list
end

-- The monitor's usable area (minus the bar), in layout coordinates.
local function screen_box(monitor)
  local w = math.floor(monitor.width / monitor.scale)
  local h = math.floor(monitor.height / monitor.scale)
  if (monitor.transform or 0) % 2 == 1 then
    w, h = h, w
  end
  local r = monitor.reserved or {}
  return {
    x = monitor.x + (r.left or 0),
    y = monitor.y + (r.top or 0),
    w = w - (r.left or 0) - (r.right or 0),
    h = h - (r.top or 0) - (r.bottom or 0),
  }
end

local function visible_windows(monitor, pip)
  local workspace = monitor.active_special_workspace or monitor.active_workspace
  local list = {}
  if not workspace then
    return list
  end
  for _, w in ipairs(workspace:get_windows() or {}) do
    if w.address ~= pip.address and w.mapped and not w.hidden and not is_pip(w) then
      list[#list + 1] = w
    end
  end
  return list
end

-- The window under the point (x, y) on the monitor's visible workspace. Floating
-- windows sit above tiled ones, so they win; between two of a kind, the smaller.
local function window_under(monitor, pip, x, y)
  local best, best_floating, best_area
  for _, w in ipairs(visible_windows(monitor, pip)) do
    local b = box(w)
    if contains(b, x, y) then
      local area = b.w * b.h
      local better = not best
        or (w.floating and not best_floating)
        or (w.floating == best_floating and area < best_area)
      if better then
        best, best_floating, best_area = b, w.floating, area
      end
    end
  end
  return best
end

-- The browser window a new PiP came from: a window of the same process on the
-- visible workspace, the most recently focused if there are several.
local function browser_window(monitor, pip)
  local best
  for _, w in ipairs(visible_windows(monitor, pip)) do
    if w.pid == pip.pid and (not best or w.focus_history_id < best.focus_history_id) then
      best = w
    end
  end
  return best and box(best)
end

-- Move the PiP into a corner of target, clamped to the screen. corner is
-- { left = bool, top = bool }.
local function move_to_corner(pip, monitor, target, corner)
  local b = box(pip)
  local x = corner.left and target.x + MARGIN or target.x + target.w - b.w - MARGIN
  local y = corner.top and target.y + MARGIN or target.y + target.h - b.h - MARGIN

  -- Keep it on screen when the target window is smaller than the PiP.
  local screen = screen_box(monitor)
  x = math.max(screen.x, math.min(x, screen.x + screen.w - b.w))
  y = math.max(screen.y, math.min(y, screen.y + screen.h - b.h))
  x, y = math.floor(x), math.floor(y)

  placed[pip.address] = { x = x, y = y }
  if x ~= b.x or y ~= b.y then
    hl.dispatch(hl.dsp.window.move({ x = x, y = y, window = "address:" .. pip.address }))
  end
end

-- After a drag: the nearest corner of the window it was dropped on.
local function snap(pip)
  local b = box(pip)
  local cx, cy = b.x + b.w / 2, b.y + b.h / 2
  local monitor = hl.get_monitor_at(cx, cy) or pip.monitor
  if not monitor then
    return
  end
  local target = window_under(monitor, pip, cx, cy) or screen_box(monitor)
  move_to_corner(pip, monitor, target, {
    left = cx < target.x + target.w / 2,
    top = cy < target.y + target.h / 2,
  })
end

-- A new PiP: the top-right corner of its browser window.
local function place_new(pip)
  local monitor = pip.monitor or hl.get_active_monitor()
  if not monitor then
    return
  end
  local target = browser_window(monitor, pip) or screen_box(monitor)
  move_to_corner(pip, monitor, target, { left = false, top = true })
end

-- Place any PiP that hasn't been placed yet. Its title, and so its tag, can
-- arrive after it opens, so this runs on open, title and rule changes, a moment
-- later so the window rule's own size and position have landed first.
local function place_unplaced()
  hl.timer(function()
    for _, pip in ipairs(pips()) do
      if not placed[pip.address] then
        place_new(pip)
      end
    end
  end, { timeout = 50, type = "oneshot" })
end

hl.on("window.open", place_unplaced)
hl.on("window.title", place_unplaced)
hl.on("window.update_rules", place_unplaced)

-- A closed window no longer has an address, so forget whichever PiPs are gone.
hl.on("window.destroy", function()
  local live = {}
  for _, w in ipairs(hl.get_windows() or {}) do
    if w.address then
      live[w.address] = true
    end
  end
  for address in pairs(placed) do
    if not live[address] then
      placed[address] = nil
    end
  end
end)

local function on_release()
  for _, pip in ipairs(pips()) do
    local last = placed[pip.address]
    if last and (last.x ~= pip.at.x or last.y ~= pip.at.y) then
      snap(pip)
    end
  end
end

-- Every left-button release, passed through to the app as usual. The move lands
-- a moment after the drag ends, so look one loop later.
hl.bind("mouse:272", function()
  hl.timer(on_release, { timeout = 1, type = "oneshot" })
end, { release = true, non_consuming = true, ignore_mods = true, description = "Snap PiP to corner" })
