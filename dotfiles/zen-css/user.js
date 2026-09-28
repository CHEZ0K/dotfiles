// ==========================================
// ZEN BROWSER ULTRA PERFORMANCE & RAM OPTIMIZATION
// ==========================================

// --- MEMORY & CACHE LIMITS ---
user_pref("browser.cache.memory.enable", true);
user_pref("browser.cache.memory.capacity", 32768); // 32 MB max memory cache
user_pref("browser.cache.disk.enable", true);
user_pref("browser.cache.disk.capacity", 256000); // 256 MB disk cache
user_pref("browser.sessionhistory.max_total_viewers", 1); // Max 1 page in bfcache per tab
user_pref("browser.sessionhistory.max_entries", 5);
user_pref("image.mem.decode_bytes_at_a_time", 32768);
user_pref("javascript.options.mem.compacting", true);
user_pref("javascript.options.mem.gc_frequency", 300);

// --- PROCESS LIMITS & SITE ISOLATION (Single content proc saves ~500 MB) ---
user_pref("fission.autostart", false);
user_pref("dom.ipc.processCount", 1);
user_pref("dom.ipc.processCount.webIsolated", 1);
user_pref("browser.tabs.remote.separatePrivilegedContentProcess", false);

// --- TAB UNLOADING & SUSPENSION (Unloads inactive tabs) ---
user_pref("browser.tabs.unloadOnLowMemory", true);
user_pref("browser.tabs.min_inactive_duration_before_unload", 60000);
user_pref("browser.low_commit_space_threshold_percent", 35);
user_pref("zen.tabs.unload.enabled", true);

// --- CPU OPTIMIZATION & BACKGROUND THROTTLING ---
user_pref("dom.timeout.enable_budget_timer_throttling", true);
user_pref("dom.min_background_timeout_value", 1000); // Background tabs throttled to 1s
user_pref("dom.timeout.background_budget_ms", 10);
user_pref("dom.timeout.background_throttling_max_budget", 100);
user_pref("media.block-autoplay-until-in-foreground", true);

// --- HARDWARE ACCELERATION (VA-API & WebRender on AMDGPU) ---
user_pref("gfx.webrender.all", true);
user_pref("widget.dmabuf.force-enabled", true);
user_pref("media.ffmpeg.vaapi.enabled", true);
user_pref("media.rdd-ffmpeg.enabled", true);
user_pref("media.rdd-process.enabled", true);
user_pref("layers.acceleration.force-enabled", true);

// --- DISABLE LOCAL AI & INFERENCE (Saves 350+ MB RAM) ---
user_pref("browser.ml.enable", false);
user_pref("browser.translation.inference.enable", false);
user_pref("browser.translation.enable", false);

// --- DISABLE UNNECESSARY BACKGROUND SERVICES & LEAKS ---
user_pref("accessibility.force_disabled", 1);
user_pref("toolkit.telemetry.enabled", false);
user_pref("toolkit.telemetry.unified", false);
user_pref("datareporting.healthreport.uploadEnabled", false);
user_pref("datareporting.policy.dataSubmissionEnabled", false);
user_pref("browser.ping-centre.telemetry", false);
user_pref("experiments.supported", false);
user_pref("network.prefetch-next", false);
user_pref("network.dns.disablePrefetch", true);
user_pref("network.http.speculative-parallel-limit", 0);

user_pref("toolkit.startup.max_resumed_crashes", -1);
