# PiP

Pops the video that's playing out into a small picture-in-picture window. On macOS that's
the system's floating video window, which stays above all your other windows, and can be
moved to any corner and resized. On Omarchy, drag it and let go: it snaps to the nearest
corner of the window under it (see [Omarchy](#omarchy)).

## Use

- Click the PiP toolbar button, or press `Option+P` on the page (`Alt+P` on Linux).
- Do it again to put the video back.

It picks the playing video with the most on screen, or, if nothing's playing, the biggest
video on screen. Videos inside frames (such as embedded YouTube players) work from the
toolbar button. `Option+P` works in the frame you last clicked.

If the browser wants a click on the page first, a **Pop out video** button shows over the
video for a few seconds. Click it to pop the video out.

## Install

### Chrome

1. Open `chrome://extensions`.
2. Turn on **Developer mode**.
3. Click **Load unpacked** and pick this folder.

### WebAppWrap

Install it from this folder in WebAppWrap's Extensions. The apps need a WebAppWrap build
that turns on picture in picture for its web views; earlier builds say the video doesn't
support it.

## Omarchy

On Wayland the compositor, not the browser, decides where windows go, so the snapping is a
Hyprland Lua module, [`omarchy/pip-snap.lua`](omarchy/pip-snap.lua), not part of the
extension. It works for any picture-in-picture window, whatever opened it.

Drag the PiP window (by itself, or with `Super` + drag) and let go: it moves to the nearest
corner of the window it was dropped on, 16px in. Dropped where there's no window, it goes to
the nearest corner of the screen. Clicks that don't move it (play, pause) leave it alone.

Install (needs Hyprland 0.56+ with Omarchy's Lua config):

```sh
cp omarchy/pip-snap.lua ~/.config/hypr/pip-snap.lua
echo 'require("hypr.pip-snap")' >> ~/.config/hypr/hyprland.lua
hyprctl reload && hyprctl configerrors
```

Copy it again after changing it here. It relies on Omarchy tagging PiP windows `pip`
(`$OMARCHY_PATH/default/hypr/apps/pip.lua`), which also floats and pins them.
