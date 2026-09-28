// ==UserScript==
// @name         YouTube to Terminal Lyrics Sync
// @namespace    http://tampermonkey.net/
// @version      1.0
// @description  Transmits exact video.currentTime from YouTube to yt-lyrics
// @author       chezok
// @match        https://www.youtube.com/*
// @icon         https://www.google.com/s2/favicons?sz=64&domain=youtube.com
// @grant        none
// @run-at       document-end
// ==/UserScript==

(function() {
    'use strict';

    setInterval(() => {
        const v = document.querySelector('video');
        if (!v || isNaN(v.currentTime)) return;

        fetch('http://127.0.0.1:8974/sync', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                time: v.currentTime,
                paused: v.paused,
                duration: v.duration || 0
            })
        }).catch(() => {
            // Silently ignore when terminal script is not open
        });
    }, 200);
})();
