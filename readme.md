# PiP

Pops the video that's playing out into a small picture-in-picture window. On macOS that's
the system's floating video window, which stays above all your other windows, and can be
moved to any corner and resized.

## Use

- Click the PiP toolbar button, or press `Option+P` on the page.
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
