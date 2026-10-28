(() => {
  if (!document.pictureInPictureEnabled) return;

  const isTop = window === window.top;

  // ---------- Finding the video ----------

  function visibleArea(video) {
    const r = video.getBoundingClientRect();
    const w = Math.min(r.right, window.innerWidth) - Math.max(r.left, 0);
    const h = Math.min(r.bottom, window.innerHeight) - Math.max(r.top, 0);
    return w > 0 && h > 0 ? w * h : 0;
  }

  const isPlaying = (video) => !video.paused && !video.ended && video.readyState > 2;

  // The playing video with the most on screen, or, failing that, the biggest one on screen.
  // Videos still loading their first frame can't go into picture in picture yet.
  function bestVideo(playingOnly) {
    let best = null;
    let bestScore = 0;
    for (const video of document.querySelectorAll("video")) {
      if (video.readyState < 1) continue;
      const playing = isPlaying(video);
      if (playingOnly && !playing) continue;
      const score = visibleArea(video) + (playing ? 1e9 : 0);
      if (score > bestScore) {
        best = video;
        bestScore = score;
      }
    }
    return best;
  }

  // ---------- Picture in picture ----------

  // Every frame gets the toolbar click. A frame acts if it has the picture-in-picture video
  // (to close it) or a playing video. If nothing's playing, the top frame takes its biggest
  // video.
  async function toggle() {
    if (document.pictureInPictureElement) {
      await document.exitPictureInPicture().catch(() => {});
      return;
    }
    const video = bestVideo(true) || (isTop ? bestVideo(false) : null);
    if (video) await open(video);
  }

  async function open(video) {
    // Some players turn picture in picture off; this asks for it anyway.
    video.disablePictureInPicture = false;
    try {
      await video.requestPictureInPicture();
    } catch (error) {
      // The browser wants a click on the page first.
      if (error.name === "NotAllowedError") offerButton(video);
      else console.warn("PiP:", error);
    }
  }

  // ---------- "Click to pop out" button, when a click on the page is needed ----------

  let host = null;
  let hideTimer = null;

  function removeButton() {
    clearTimeout(hideTimer);
    if (host) host.remove();
    host = null;
  }

  function offerButton(video) {
    removeButton();
    const r = video.getBoundingClientRect();
    host = document.createElement("pip-ui");
    host.style.cssText = "all: initial; position: fixed; inset: 0; pointer-events: none; z-index: 2147483647;";
    const shadow = host.attachShadow({ mode: "closed" });
    shadow.innerHTML = `
      <style>
        button {
          position: fixed;
          transform: translate(-50%, -50%);
          pointer-events: auto;
          padding: 8px 14px;
          font: 600 13px/1.2 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
          color: #fff;
          background: rgba(20, 20, 20, 0.85);
          border: 1px solid rgba(255, 255, 255, 0.25);
          border-radius: 8px;
          box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
          cursor: pointer;
        }
        button:hover { background: rgba(40, 40, 40, 0.95); }
      </style>
      <button>Pop out video</button>`;
    const button = shadow.querySelector("button");
    const x = Math.min(Math.max((Math.max(r.left, 0) + Math.min(r.right, window.innerWidth)) / 2, 80), window.innerWidth - 80);
    const y = Math.min(Math.max((Math.max(r.top, 0) + Math.min(r.bottom, window.innerHeight)) / 2, 24), window.innerHeight - 24);
    button.style.left = `${x}px`;
    button.style.top = `${y}px`;
    button.addEventListener("click", (e) => {
      e.preventDefault();
      e.stopPropagation();
      removeButton();
      video.requestPictureInPicture().catch((error) => console.warn("PiP:", error));
    });
    document.documentElement.appendChild(host);
    hideTimer = setTimeout(removeButton, 5000);
  }

  window.addEventListener("scroll", removeButton, true);

  // ---------- Toolbar button and keyboard shortcut ----------

  chrome.runtime.onMessage.addListener((message) => {
    if (message && message.type === "pip:toggle") toggle();
  });

  function isEditable(el) {
    if (!el || el.nodeType !== 1) return false;
    if (el.isContentEditable || el.tagName === "TEXTAREA" || el.tagName === "SELECT") return true;
    return el.tagName === "INPUT" && !["button", "checkbox", "radio", "range", "submit"].includes(el.type);
  }

  // Option+P (by key position, since Option changes the character). Left alone while typing,
  // where it types π.
  window.addEventListener(
    "keydown",
    (e) => {
      if (e.code !== "KeyP" || !e.altKey || e.metaKey || e.ctrlKey || e.shiftKey) return;
      if (isEditable(document.activeElement)) return;
      e.preventDefault();
      e.stopImmediatePropagation();
      toggle();
    },
    true,
  );
  window.addEventListener("keydown", (e) => e.key === "Escape" && removeButton(), true);
})();
