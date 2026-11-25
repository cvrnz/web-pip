-- Snap picture-in-picture windows to a corner of the window under them.
--
-- Drag a PiP window (by itself, or with SUPER + drag) and let go: it slides into
-- the nearest corner of the window it was dropped on. Dropped where there's no
-- window, it snaps to the nearest corner of the screen.
--
-- Hyprland, not the browser, decides where windows go on Wayland, so this lives
-- in the Hyprland config rather than in the extension. PiP windows are the ones
-- Omarchy tags "pip" (default/hypr/apps/pip.lua), which already float and pin them.
--
-- Install: copy to ~/.config/hypr/pip-snap.lua and add require("hypr.pip-snap")
-- to ~/.config/hypr/hyprland.lua.

local MARGIN = 16 -- gap between the PiP and the corner it snaps to

-- Where each PiP window was last left, so a click that didn't move it (play,
-- pause, the close button) doesn't snap it.
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

-- The window under the point (x, y) on the monitor's visible workspace. Floating
-- windows sit above tiled ones, so they win; between two of a kind, the smaller.
local function window_under(monitor, pip, x, y)
  local workspace = monitor.active_special_workspace or monitor.active_workspace
  if not workspace then
    return nil
  end
  local best, best_floating, best_area
  for _, w in ipairs(workspace:get_windows() or {}) do
    if w.address ~= pip.address and w.mapped and not w.hidden and not is_pip(w) then
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
  end
  return best
end

local function snap(pip)
  local b = box(pip)
  local cx, cy = b.x + b.w / 2, b.y + b.h / 2
  local monitor = hl.get_monitor_at(cx, cy) or pip.monitor
  if not monitor then
    return
  end

  local target = window_under(monitor, pip, cx, cy) or screen_box(monitor)
  local left = cx < target.x + target.w / 2
  local top = cy < target.y + target.h / 2
  local x = left and target.x + MARGIN or target.x + target.w - b.w - MARGIN
  local y = top and target.y + MARGIN or target.y + target.h - b.h - MARGIN

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

local function on_release()
  -- Not hl.get_windows({ tag = "pip" }): the filter wants the exact tag, and a
  -- rule-set tag is "pip*".
  for _, pip in ipairs(hl.get_windows() or {}) do
    if pip.mapped and pip.floating and is_pip(pip) then
      local last = placed[pip.address]
      local at = pip.at
      local cursor = hl.get_cursor_pos()
      local under_cursor = cursor and contains(box(pip), cursor.x, cursor.y)
      -- A PiP we haven't seen placed (its title, and so its tag, can arrive after
      -- it opens) snaps when it's the one let go of.
      if (last and (last.x ~= at.x or last.y ~= at.y)) or (not last and under_cursor) then
        snap(pip)
      end
    end
  end
end

-- Remember where a PiP opened, so the first drag counts as a move.
hl.on("window.open", function(window)
  hl.timer(function()
    if window and window.mapped and is_pip(window) then
      placed[window.address] = { x = window.at.x, y = window.at.y }
    end
  end, { timeout = 250, type = "oneshot" })
end)

hl.on("window.destroy", function(window)
  if window then
    placed[window.address] = nil
  end
end)

-- Every left-button release, passed through to the app as usual. The move lands
-- a moment after the drag ends, so look one loop later.
hl.bind("mouse:272", function()
  hl.timer(on_release, { timeout = 1, type = "oneshot" })
end, { release = true, non_consuming = true, ignore_mods = true, description = "Snap PiP to corner" })
