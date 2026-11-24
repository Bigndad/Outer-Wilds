pragma Singleton
import QtQuick

// =====================================================================
//  WidgetConfig: the ONE place that decides which widgets exist, which planet
//  each one orbits, and how big / fast / far / tilted it is.
//
//   * WidgetLayer.baseDefs (widgets/WidgetLayer.qml) stays the DEFAULT table and registers itself here.
//   * The settings panel edits `overrides` (and adds / removes `extras`); nothing else writes them.
//   * WidgetLayer asks liveDefs() for the merged, enabled list and follows `revision`.
//   * Saving: this file never touches the disk. It emits saveRequested(text) (debounced) and
//     WidgetConfigStore.qml (the only file that imports Quickshell.Io) writes widgets.json.
//
//  No Quickshell import on purpose, so this loads in plain `qml` on the Mint laptop too.
// =====================================================================
QtObject {
    id: root

    // ---------------- what the panel can offer ----------------
    readonly property var planets: [
        { id: "sun",             name: "The Sun" },
        { id: "sun_station",     name: "Sun Station" },
        { id: "ash_twin",        name: "Ash Twin" },
        { id: "ember_twin",      name: "Ember Twin" },
        { id: "timber_hearth",   name: "Timber Hearth" },
        { id: "attlerock",       name: "Attlerock" },
        { id: "brittle_hollow",  name: "Brittle Hollow" },
        { id: "hollows_lantern", name: "Hollow's Lantern" },
        { id: "giants_deep",     name: "Giant's Deep" },
        { id: "dark_bramble",    name: "Dark Bramble" },
        { id: "interloper",      name: "The Interloper" },
        { id: "quantum_moon",    name: "Quantum Moon" }
    ]

    // Every widget file that can be placed. `source` is relative to widgets/ (same as WidgetLayer defs).
    // designW = the file's width in px at ui = 1 (used to keep the on-screen size sensible when a slot's widget type is swapped).
    // title   = card title override for widgets that take one (blank = the widget's own).
    readonly property var builtinCatalog: [
        { source: "ClockWidget.qml",             name: "Clock",                 group: "Outer Wilds",    designW: 300,
          settings: [
              { key: "hour24",       type: "toggle", label: "24-hour clock",  default: true },
              { key: "showSeconds",  type: "toggle", label: "Show seconds",   default: true },
              { key: "showDate",     type: "toggle", label: "Show date",      default: true },
              { key: "dateFormat",   type: "text",   label: "Date format",    default: "dddd, d MMMM yyyy" },
              { key: "timeColor",    type: "color",  label: "Time colour",    default: "#E6D5B8" },
              { key: "secondsColor", type: "color",  label: "Seconds colour", default: "#D4AF37" },
              { key: "font",         type: "font",   label: "Font",           default: "monospace" }
          ] },
        { source: "LoopWidget.qml",              name: "Loop timer",            group: "Outer Wilds",    designW: 276,
          settings: [
              { key: "mode",        type: "choice", label: "Display mode",  choices: [{ value: "countdown", label: "Countdown" }, { value: "elapsed", label: "Elapsed" }, { value: "percent", label: "Percent" }], default: "countdown" },
              { key: "warnSec",     type: "number", label: "Warn before nova", min: 0, max: 600, step: 10, unit: "s", default: 90 },
              { key: "showBar",     type: "toggle", label: "Show progress bar", default: true },
              { key: "showSubtext", type: "toggle", label: "Show elapsed / total", default: true },
              { key: "barColor",    type: "color",  label: "Bar colour",    default: "#D4AF37" },
              { key: "warnColor",   type: "color",  label: "Warning colour", default: "#FF7A45" },
              { key: "font",        type: "font",   label: "Font",          default: "monospace" }
          ] },
        { source: "UptimeWidget.qml",            name: "Uptime",                group: "Outer Wilds",    designW: 236,
          settings: [
              { key: "prefix",      type: "text",   label: "Prefix label",  default: "" },
              { key: "showSeconds", type: "toggle", label: "Show seconds",  default: false },
              { key: "textSize",    type: "number", label: "Text size",     min: 12, max: 40, step: 1, unit: "px", default: 24 },
              { key: "textColor",   type: "color",  label: "Text colour",   default: "#E6D5B8" },
              { key: "font",        type: "font",   label: "Font",          default: "monospace" }
          ] },
        { source: "DateWorldWidget.qml",         name: "Date / world clocks",   group: "Outer Wilds",    designW: 276,
          settings: [
              { key: "showWeek",        type: "toggle", label: "Show ISO week",     default: true },
              { key: "showDayOfYear",   type: "toggle", label: "Show day of year",  default: true },
              { key: "showMonth",       type: "toggle", label: "Show month / year", default: true },
              { key: "showWorldClocks", type: "toggle", label: "Show world clocks", default: true },
              { key: "customZones",     type: "text",   label: "Zones (LBL:min, ...)", default: "" },
              { key: "accentColor",     type: "color",  label: "Accent colour",     default: "#D4AF37" },
              { key: "font",            type: "font",   label: "Font",              default: "monospace" }
          ] },
        { source: "WorkspacesWidget.qml",        name: "Workspaces",            group: "Outer Wilds",  designW: 300,
          settings: [
              { key: "columns",       type: "number", label: "Columns",          min: 1, max: 10, step: 1, default: 5 },
              { key: "shape",         type: "choice", label: "Pill shape",       choices: [{ value: "circle", label: "Circle" }, { value: "rounded", label: "Rounded" }, { value: "square", label: "Square" }], default: "circle" },
              { key: "pillSize",      type: "number", label: "Pill size",        min: 24, max: 56, step: 2, unit: "px", default: 40 },
              { key: "hideEmpty",     type: "toggle", label: "Hide empty",       default: false },
              { key: "activeColor",   type: "color",  label: "Active colour",    default: "#D4AF37" },
              { key: "occupiedColor", type: "color",  label: "Occupied colour",  default: "#E6D5B8" }
          ] },
        { source: "NotesWidget.qml",             name: "Notes",                 group: "Outer Wilds",  designW: 280,
          settings: [
              { key: "placeholder", type: "text",   label: "Placeholder",     default: "quick notes..." },
              { key: "fontSize",    type: "number", label: "Font size",       min: 9, max: 24, step: 1, unit: "px", default: 14 },
              { key: "textColor",   type: "color",  label: "Text colour",     default: "#E6D5B8" },
              { key: "font",        type: "font",   label: "Font",            default: "monospace" },
              { key: "showFooter",  type: "toggle", label: "Show footer",     default: true },
              { key: "countMode",   type: "choice", label: "Counter",         choices: [{ value: "chars", label: "Characters" }, { value: "words", label: "Words" }], default: "chars" }
          ] },
        { source: "RumorWidget.qml",             name: "Ship log (rumors)",     group: "Outer Wilds",  designW: 250,
          settings: [
              { key: "showGlyph",    type: "toggle", label: "Show rumor glyph", default: true },
              { key: "showTicker",   type: "toggle", label: "Show latest bar",  default: true },
              { key: "scrollTicker", type: "toggle", label: "Scroll long text", default: true },
              { key: "flashOnNew",   type: "toggle", label: "Flash on arrival", default: true },
              { key: "showKeyHint",  type: "toggle", label: "Show key hint",    default: true },
              { key: "accentColor",  type: "color",  label: "Accent colour",    default: "#D4AF37" }
          ] },
        { source: "MapWidget.qml",               name: "Map (small)",           group: "Outer Wilds",  designW: 250,
          settings: [
              { key: "showAxis",          type: "toggle", label: "Show axis line",     default: true },
              { key: "showSelectionRing", type: "toggle", label: "Show selection ring", default: true },
              { key: "showPlanetName",    type: "toggle", label: "Show planet name",   default: true },
              { key: "showKeyHint",       type: "toggle", label: "Show key hint",      default: true },
              { key: "ringColor",         type: "color",  label: "Ring colour",        default: "#D4AF37" }
          ] },
        { source: "AppLauncherWidget.qml",       name: "App launcher (small)",  group: "Outer Wilds",  designW: 250,
          settings: [
              { key: "cols",           type: "number", label: "Columns",          min: 3, max: 8, step: 1, default: 6 },
              { key: "rows",           type: "number", label: "Rows",             min: 1, max: 4, step: 1, default: 2 },
              { key: "showEmptySlots", type: "toggle", label: "Show empty slots", default: true },
              { key: "showFooter",     type: "toggle", label: "Show footer",      default: true },
              { key: "tileRadius",     type: "number", label: "Tile radius",      min: 0, max: 12, step: 1, unit: "px", default: 3 },
              { key: "tileColor",      type: "color",  label: "Tile fill",        default: "#26E6D5B8" }
          ] },
        { source: "SignalscopeWidget.qml",       name: "Signalscope",           group: "Outer Wilds",  designW: 250,
          settings: [
              { key: "showCount",   type: "toggle", label: "Show signal count", default: true },
              { key: "showStatus",  type: "toggle", label: "Show lock status",  default: true },
              { key: "showButton",  type: "toggle", label: "Show equip button", default: true },
              { key: "equipLabel",  type: "text",   label: "Equip label",       default: "EQUIP" },
              { key: "stowLabel",   type: "text",   label: "Stow label",        default: "STOW" },
              { key: "accentColor", type: "color",  label: "Accent colour",     default: "#D4AF37" }
          ] },
        { source: "WeatherWidget.qml",           name: "Weather",               group: "Outer Wilds", designW: 280, title: "WEATHER",
          settings: [
              { key: "lat",         type: "number", label: "Latitude",          min: -90, max: 90, step: 0.01, default: 18.91 },
              { key: "lon",         type: "number", label: "Longitude",         min: -180, max: 180, step: 0.01, default: 72.81 },
              { key: "unit",        type: "choice", label: "Temperature unit",  choices: [{ value: "C", label: "°C" }, { value: "F", label: "°F" }], default: "C" },
              { key: "windUnit",    type: "choice", label: "Wind unit",         choices: ["km/h", "m/s", "mph"], default: "km/h" },
              { key: "showWind",    type: "toggle", label: "Show wind",         default: true },
              { key: "refreshMin",  type: "number", label: "Refresh interval",  min: 5, max: 120, step: 5, unit: "min", default: 15 },
              { key: "accentColor", type: "color",  label: "Accent colour",     default: "#FF6347" }
          ] },
        { source: "BlankWidget.qml",             name: "Blank placeholder",     group: "Outer Wilds",   designW: 240,
          settings: [
              { key: "label",     type: "text",   label: "Main text",   default: "NO ROLE ASSIGNED" },
              { key: "sublabel",  type: "text",   label: "Subtext",     default: "" },
              { key: "textSize",  type: "number", label: "Text size",   min: 8, max: 36, step: 1, unit: "px", default: 12 },
              { key: "align",     type: "choice", label: "Alignment",   choices: [{ value: "left", label: "Left" }, { value: "center", label: "Center" }, { value: "right", label: "Right" }], default: "center" },
              { key: "textColor", type: "color",  label: "Text colour", default: "#8A7F66" },
              { key: "font",      type: "font",   label: "Font",        default: "monospace" }
          ] },
        { source: "WallpaperCard.qml",           name: "Wallpaper switcher",    group: "Outer Wilds",   designW: 260, title: "WALLPAPER",
          settings: [
              { key: "fillMode",     type: "choice", label: "Image fit",        choices: [{ value: "crop", label: "Fill / Crop" }, { value: "fit", label: "Fit inside" }], default: "crop" },
              { key: "showFilename", type: "toggle", label: "Show filename",    default: true },
              { key: "imageRadius",  type: "number", label: "Image radius",     min: 0, max: 16, step: 1, unit: "px", default: 0 },
              { key: "pollSec",      type: "number", label: "Refresh interval", min: 1, max: 30, step: 1, unit: "s", default: 4 }
          ] },
        { source: "ScreentimeCard.qml",          name: "Screen time",           group: "Outer Wilds",   designW: 260, title: "SCREEN TIME",
          settings: [
              { key: "maxApps",   type: "number", label: "Apps shown",       min: 1, max: 5, step: 1, default: 3 },
              { key: "showBars",  type: "toggle", label: "Show usage bars",  default: true },
              { key: "barColor",  type: "color",  label: "Bar colour",       default: "#D4AF37" },
              { key: "headerTag", type: "text",   label: "Header tag",       default: "TODAY" },
              { key: "pollSec",   type: "number", label: "Refresh interval", min: 1, max: 30, step: 1, unit: "s", default: 3 }
          ] },
        { source: "serp/SunClock.qml",           name: "Dial clock", group: "Serpantinum",    designW: 220,
          settings: [
              { key: "showSeconds", type: "toggle", label: "Show second hand", default: true },
              { key: "dialHex",     type: "color",  label: "Dial colour",      default: "" },
              { key: "hourHex",     type: "color",  label: "Hour hand colour", default: "" },
              { key: "minuteHex",   type: "color",  label: "Minute hand colour", default: "" },
              { key: "secondHex",   type: "color",  label: "Second hand colour", default: "" }
          ] },
        { source: "serp/AshTwinBattery.qml",     name: "Battery (round)",       group: "Serpantinum",  designW: 220, title: "BATTERY",
          settings: [
              { key: "sineWaveMode",  type: "choice", label: "Wave ring",     choices: [{ value: "auto", label: "Auto" }, { value: "on", label: "On" }, { value: "off", label: "Off" }], default: "auto" },
              { key: "lineThickness", type: "number", label: "Ring thickness", min: 3, max: 18, step: 1, unit: "px", default: 8 },
              { key: "lowWarn",       type: "number", label: "Low warning",   min: 5, max: 50, step: 5, unit: "%", default: 20 }
          ] },
        { source: "serp/EmberTwinBattery.qml",   name: "Battery (small)",       group: "Serpantinum",  designW: 160, title: "BATTERY",
          settings: [
              { key: "showTime", type: "toggle", label: "Show remaining time", default: true },
              { key: "lowWarn",  type: "number", label: "Low warning",         min: 5, max: 50, step: 5, unit: "%", default: 20 }
          ] },
        { source: "serp/GiantsDeepWeather.qml",  name: "Weather (full)",        group: "Serpantinum", designW: 360, title: "WEATHER",
          settings: [
              { key: "showFeelsLike", type: "toggle", label: "Show feels like", default: true },
              { key: "showForecast",  type: "toggle", label: "Show hourly strip", default: true },
              { key: "maxForecast",   type: "number", label: "Forecast hours",  min: 2, max: 4, step: 1, default: 4 },
              { key: "accentHex",     type: "color",  label: "Icon accent",     default: "" }
          ] },
        { source: "serp/EmberTwinMusic.qml",     name: "Music player",          group: "Serpantinum",   designW: 340,
          settings: [
              { key: "optArt",    type: "toggle", label: "Show album art",  default: true },
              { key: "optArtist", type: "toggle", label: "Show artist",     default: true },
              { key: "optTime",   type: "toggle", label: "Show seek bar",   default: true },
              { key: "optBars",   type: "toggle", label: "Show visualizer", default: true }
          ] },
        { source: "serp/EmberTwinLyrics.qml",    name: "Music + lyrics",        group: "Serpantinum",   designW: 340,
          settings: [
              { key: "lyricsAlignment", type: "choice", label: "Alignment",      choices: [{ value: "left", label: "Left" }, { value: "center", label: "Center" }, { value: "right", label: "Right" }], default: "left" },
              { key: "showArtBg",       type: "toggle", label: "Blurred art bg", default: true }
          ] },
        { source: "serp/DarkBrambleVisualiser.qml", name: "Visualiser",         group: "Serpantinum",   designW: 360, title: "VISUALISER",
          settings: [
              { key: "barSpacing",     type: "number", label: "Bar spacing",    min: 1, max: 14, step: 1, unit: "px", default: 4 },
              { key: "minBarWidth",    type: "number", label: "Min bar width",  min: 2, max: 20, step: 1, unit: "px", default: 6 },
              { key: "edgeFadeOpt",    type: "toggle", label: "Edge fade",      default: true },
              { key: "barCount",       type: "number", label: "Wave points",    min: 16, max: 128, step: 8, default: 64 },
              { key: "riseSpeed",      type: "number", label: "Wave rise",      min: 0.05, max: 1.0, step: 0.05, default: 0.25 },
              { key: "fallSpeed",      type: "number", label: "Wave fall",      min: 0.05, max: 1.0, step: 0.05, default: 0.12 }
          ] },
        { source: "serp/DarkBrambleDisc.qml",    name: "Disc player",           group: "Serpantinum",   designW: 210,
          settings: [
              { key: "continuousMode", type: "choice", label: "Ring wave",    choices: [{ value: "auto", label: "Auto" }, { value: "on", label: "Continuous" }, { value: "off", label: "Bars" }], default: "auto" },
              { key: "barCount",       type: "number", label: "Bar count",    min: 24, max: 120, step: 8, default: 64 },
              { key: "spinDisc",       type: "toggle", label: "Spin vinyl",   default: true },
              { key: "showGrooves",    type: "toggle", label: "Vinyl grooves", default: true }
          ] },
        { source: "serp/DarkBrambleLyrics.qml",  name: "Lyrics",                group: "Serpantinum",   designW: 340,
          settings: [
              { key: "lyricsLines",     type: "number", label: "Context lines",  min: 0, max: 4, step: 1, default: 1 },
              { key: "lyricsAlignment", type: "choice", label: "Alignment",      choices: [{ value: "left", label: "Left" }, { value: "center", label: "Center" }, { value: "right", label: "Right" }], default: "left" },
              { key: "showNoLyrics",    type: "toggle", label: "Show idle text", default: true }
          ] },
        { source: "serp/SunStationCpu.qml",      name: "CPU",                   group: "Serpantinum",   designW: 200, title: "CPU",
          settings: [
              { key: "sineWaveMode",  type: "choice", label: "Wave ring",      choices: [{ value: "auto", label: "Auto" }, { value: "on", label: "On" }, { value: "off", label: "Off" }], default: "auto" },
              { key: "lineThickness", type: "number", label: "Ring thickness", min: 3, max: 18, step: 1, unit: "px", default: 8 },
              { key: "accentHex",     type: "color",  label: "Accent colour",  default: "" }
          ] },
        { source: "serp/BrittleHollowRam.qml",   name: "RAM",                   group: "Serpantinum",   designW: 220, title: "RAM",
          settings: [
              { key: "accentHex", type: "color", label: "Fill colour", default: "" }
          ] },
        { source: "serp/BrittleHollowDisk.qml",  name: "Disk",                  group: "Serpantinum",   designW: 220, title: "DISK",
          settings: [
              { key: "accentHex", type: "color", label: "Fill colour", default: "" }
          ] },
        { source: "serp/HollowsLanternTemp.qml", name: "Temperature",           group: "Serpantinum",   designW: 200, title: "TEMP",
          settings: [
              { key: "sineWaveMode",  type: "choice", label: "Wave ring",      choices: [{ value: "auto", label: "Auto" }, { value: "on", label: "On" }, { value: "off", label: "Off" }], default: "auto" },
              { key: "lineThickness", type: "number", label: "Ring thickness", min: 3, max: 18, step: 1, unit: "px", default: 8 },
              { key: "accentHex",     type: "color",  label: "Accent colour",  default: "" }
          ] },
        { source: "serp/AshTwinTimer.qml",       name: "Focus timer (Pomodoro)", group: "Serpantinum",  designW: 240, title: "FOCUS" },
        { source: "serp/GiantsDeepTimer.qml",    name: "Timer",                 group: "Serpantinum",   designW: 240, title: "TIMER" },
        { source: "serp/GiantsDeepStopwatch.qml", name: "Stopwatch",            group: "Serpantinum",   designW: 240, title: "STOPWATCH" },
        { source: "serp/QuantumMoonWeather.qml", name: "Weather (round)",       group: "Serpantinum",   designW: 220, title: "WEATHER",
          settings: [
              { key: "pillAngle", type: "number", label: "Pill tilt",   min: 0, max: 90, step: 5, unit: "°", default: 45 },
              { key: "accentHex", type: "color",  label: "Icon accent", default: "" }
          ] },
        { source: "glyph/GlyphMatrix.qml", name: "Glyph Matrix (spectrum)", group: "Glyph", designW: 220,
          settings: [
              { key: "sensitivity",     type: "number", label: "Sensitivity",    min: 0.4, max: 2.5, step: 0.1, default: 1.0 },
              { key: "dotSize",         type: "number", label: "Dot size",       min: 5, max: 11, step: 0.5, unit: "px", default: 9 },
              { key: "showCenterHeart", type: "toggle", label: "Red center dot", default: true },
              { key: "dotColor",        type: "color",  label: "Dot colour",     default: "" },
              { key: "heartColor",      type: "color",  label: "Center colour",  default: "" }
          ] },
        { source: "glyph/GlyphClock.qml", name: "Glyph clock", group: "Glyph", designW: 280,
          settings: [
              { key: "hour24",         type: "toggle", label: "24-hour clock",  default: true },
              { key: "showDate",       type: "toggle", label: "Show date row",  default: true },
              { key: "showSecondsBar", type: "toggle", label: "Seconds bar",    default: true },
              { key: "blinkColon",     type: "toggle", label: "Blink colon",    default: false },
              { key: "dotColor",       type: "color",  label: "Digit colour",   default: "" },
              { key: "colonColor",     type: "color",  label: "Colon colour",   default: "" }
          ] },
        { source: "glyph/GlyphCal.qml", name: "Glyph calendar", group: "Glyph", designW: 320,
          settings: [
              { key: "sundayFirst", type: "toggle", label: "Week starts Sunday", default: false },
              { key: "showYear",    type: "toggle", label: "Show year",          default: true },
              { key: "todayColor",  type: "color",  label: "Today dot colour",   default: "" }
          ] },
        { source: "glyph/GlyphFocus.qml", name: "Glyph focus timer", group: "Glyph", designW: 240,
          settings: [
              { key: "defaultMin",  type: "number", label: "Session length", min: 5, max: 120, step: 5, unit: "min", default: 25 },
              { key: "stepMin",     type: "number", label: "+/- step",       min: 1, max: 15, step: 1, unit: "min", default: 5 },
              { key: "ringDots",    type: "number", label: "Ring LEDs",      min: 24, max: 72, step: 4, default: 60 },
              { key: "activeColor", type: "color",  label: "Active colour",  default: "" }
          ] },
        { source: "glyph/GlyphCpu.qml", name: "Glyph CPU ring", group: "Glyph", designW: 200,
          settings: [
              { key: "warnAt",      type: "number", label: "Warning above",  min: 50, max: 100, step: 5, unit: "%", default: 85 },
              { key: "ringDots",    type: "number", label: "Ring LEDs",      min: 20, max: 60, step: 4, default: 44 },
              { key: "dotSize",     type: "number", label: "Dot size",       min: 4, max: 10, step: 0.5, unit: "px", default: 7 },
              { key: "customLabel", type: "text",   label: "Custom label",   default: "" },
              { key: "ringColor",   type: "color",  label: "Normal colour",  default: "" },
              { key: "warnColor",   type: "color",  label: "Warning colour", default: "" }
          ] },
        { source: "glyph/GlyphRam.qml", name: "Glyph RAM ring", group: "Glyph", designW: 200,
          settings: [
              { key: "warnAt",      type: "number", label: "Warning above",  min: 50, max: 100, step: 5, unit: "%", default: 85 },
              { key: "ringDots",    type: "number", label: "Ring LEDs",      min: 20, max: 60, step: 4, default: 44 },
              { key: "dotSize",     type: "number", label: "Dot size",       min: 4, max: 10, step: 0.5, unit: "px", default: 7 },
              { key: "customLabel", type: "text",   label: "Custom label",   default: "" },
              { key: "ringColor",   type: "color",  label: "Normal colour",  default: "" },
              { key: "warnColor",   type: "color",  label: "Warning colour", default: "" }
          ] },
        { source: "glyph/GlyphGpu.qml", name: "Glyph GPU ring", group: "Glyph", designW: 200,
          settings: [
              { key: "warnAt",      type: "number", label: "Warning above",  min: 50, max: 100, step: 5, unit: "%", default: 85 },
              { key: "ringDots",    type: "number", label: "Ring LEDs",      min: 20, max: 60, step: 4, default: 44 },
              { key: "dotSize",     type: "number", label: "Dot size",       min: 4, max: 10, step: 0.5, unit: "px", default: 7 },
              { key: "customLabel", type: "text",   label: "Custom label",   default: "" },
              { key: "ringColor",   type: "color",  label: "Normal colour",  default: "" },
              { key: "warnColor",   type: "color",  label: "Warning colour", default: "" }
          ] },
        { source: "glyph/GlyphSystem.qml", name: "Glyph system", group: "Glyph", designW: 440,
          settings: [
              { key: "showGraph", type: "toggle", label: "Show CPU graph",   default: true },
              { key: "pollSec",   type: "number", label: "History interval", min: 1, max: 10, step: 1, unit: "s", default: 2 },
              { key: "tempUnit",  type: "choice", label: "GPU temp unit",    choices: [{ value: "C", label: "°C" }, { value: "F", label: "°F" }], default: "C" },
              { key: "dotColor",  type: "color",  label: "Dot colour",       default: "" }
          ] },
        { source: "glyph/GlyphDate.qml", name: "Glyph date", group: "Glyph", designW: 220,
          settings: [
              { key: "sundayFirst",  type: "toggle", label: "Week starts Sunday", default: false },
              { key: "showYear",     type: "toggle", label: "Show year",          default: true },
              { key: "showWeekdays", type: "toggle", label: "Show weekday strip", default: true },
              { key: "dotColor",     type: "color",  label: "Day colour",         default: "" },
              { key: "accentColor",  type: "color",  label: "Today dot colour",   default: "" }
          ] },
        { source: "glyph/GlyphWeather.qml", name: "Glyph weather", group: "Glyph", designW: 220,
          settings: [
              { key: "unit",      type: "choice", label: "Temperature unit", choices: [{ value: "C", label: "°C" }, { value: "F", label: "°F" }], default: "C" },
              { key: "showRange", type: "toggle", label: "Show low / high",  default: true },
              { key: "showIcon",  type: "toggle", label: "Show dot icon",    default: true },
              { key: "dotColor",  type: "color",  label: "Dot colour",       default: "" }
          ] },
        { source: "glyph/GlyphDisk.qml", name: "Glyph disk ring", group: "Glyph", designW: 200,
          settings: [
              { key: "diskIndex",   type: "number", label: "Disk index",     min: 0, max: 5, step: 1, default: 0 },
              { key: "warnAt",      type: "number", label: "Warning above",  min: 50, max: 100, step: 5, unit: "%", default: 90 },
              { key: "ringDots",    type: "number", label: "Ring LEDs",      min: 20, max: 60, step: 4, default: 44 },
              { key: "dotSize",     type: "number", label: "Dot size",       min: 4, max: 10, step: 0.5, unit: "px", default: 7 },
              { key: "customLabel", type: "text",   label: "Custom label",   default: "" },
              { key: "ringColor",   type: "color",  label: "Normal colour",  default: "" },
              { key: "warnColor",   type: "color",  label: "Warning colour", default: "" }
          ] },
        { source: "glyph/GlyphBattery.qml", name: "Glyph battery ring", group: "Glyph", designW: 200,
          settings: [
              { key: "lowAt",       type: "number", label: "Low warning",    min: 5, max: 50, step: 5, unit: "%", default: 15 },
              { key: "ringDots",    type: "number", label: "Ring LEDs",      min: 20, max: 60, step: 4, default: 44 },
              { key: "dotSize",     type: "number", label: "Dot size",       min: 4, max: 10, step: 0.5, unit: "px", default: 7 },
              { key: "customLabel", type: "text",   label: "Custom label",   default: "" },
              { key: "ringColor",   type: "color",  label: "Normal colour",  default: "" },
              { key: "warnColor",   type: "color",  label: "Low colour",     default: "" }
          ] },
        { source: "glyph/GlyphVolume.qml", name: "Glyph volume ring", group: "Glyph", designW: 200,
          settings: [
              { key: "stepPct",     type: "number", label: "Scroll step",    min: 1, max: 20, step: 1, unit: "%", default: 5 },
              { key: "ringDots",    type: "number", label: "Ring LEDs",      min: 20, max: 60, step: 4, default: 44 },
              { key: "dotSize",     type: "number", label: "Dot size",       min: 4, max: 10, step: 0.5, unit: "px", default: 7 },
              { key: "customLabel", type: "text",   label: "Custom label",   default: "" },
              { key: "ringColor",   type: "color",  label: "Normal colour",  default: "" },
              { key: "warnColor",   type: "color",  label: "Muted colour",   default: "" }
          ] },
        { source: "glyph/GlyphPlayer.qml", name: "Glyph now playing", group: "Glyph", designW: 340,
          settings: [
              { key: "spinDisc",     type: "toggle", label: "Spin dot disc",  default: true },
              { key: "spinSpeed",    type: "number", label: "Spin speed",     min: 1, max: 10, step: 1, default: 3 },
              { key: "showControls", type: "toggle", label: "Show controls",  default: true },
              { key: "accentColor",  type: "color",  label: "Center colour",  default: "" }
          ] },
        { source: "glyph/GlyphHello.qml", name: "Glyph greeting", group: "Glyph", designW: 300,
          settings: [
              { key: "customGreeting", type: "text",   label: "Custom text",    default: "" },
              { key: "showDate",       type: "toggle", label: "Show date",      default: true },
              { key: "showUnread",     type: "toggle", label: "Show unread",    default: true },
              { key: "accentColor",    type: "color",  label: "Dot colour",     default: "" }
          ] },
        { source: "glyph/GlyphCat.qml", name: "Glyph cat", group: "Glyph", designW: 220,
          settings: [
              { key: "blinkSec",  type: "number", label: "Blink interval", min: 1, max: 10, step: 0.5, unit: "s", default: 3.2 },
              { key: "alwaysWag", type: "toggle", label: "Always wag tail", default: false },
              { key: "catColor",  type: "color",  label: "Cat colour",     default: "" },
              { key: "noseColor", type: "color",  label: "Nose colour",    default: "" }
          ] },
        { source: "lucid/SunClock.qml", name: "Dial clock", group: "Lucid", designW: 220,
          settings: [
              { key: "seconds",  type: "toggle", label: "Show seconds", default: false },
              { key: "showDate", type: "toggle", label: "Show date",    default: true },
              { key: "dot",      type: "toggle", label: "Center dot",   default: true }
          ] },
        { source: "lucid/BrittleHollowCalendar.qml", name: "Calendar", group: "Lucid", designW: 340,
          settings: [
              { key: "showMonthName", type: "toggle", label: "Show month name", default: true }
          ] },
        { source: "lucid/GiantsDeepWeather.qml", name: "Weather", group: "Lucid", designW: 300 },
        { source: "lucid/EmberTwinBattery.qml", name: "Battery (small)", group: "Lucid", designW: 170,
          settings: [
              { key: "showTime", type: "toggle", label: "Show remaining time", default: true },
              { key: "warnLow",  type: "toggle", label: "Low battery warning", default: true }
          ] },
        { source: "lucid/AshTwinBattery.qml", name: "Battery (round)", group: "Lucid", designW: 260,
          settings: [
              { key: "showTime", type: "toggle", label: "Show remaining time", default: true },
              { key: "warnLow",  type: "toggle", label: "Low battery warning", default: true }
          ] },
        { source: "lucid/DarkBrambleVisualiser.qml", name: "Visualiser", group: "Lucid", designW: 360,
          settings: [
              { key: "flip",     type: "toggle", label: "Flip vertically", default: false },
              { key: "rounded",  type: "toggle", label: "Rounded bars",    default: true },
              { key: "frost",    type: "toggle", label: "Frosted fill",    default: false },
              { key: "idleFade", type: "toggle", label: "Fade when idle",  default: false }
          ] },
        { source: "serp/AnserinClockDigital.qml", name: "Digital clock (Anserin)", group: "Time", designW: 250,
          settings: [
              { key: "showDate",     type: "toggle", label: "Show date badge", default: true },
              { key: "accentHex",    type: "color",  label: "Minute colour",   default: "" },
              { key: "textHex",      type: "color",  label: "Hour colour",     default: "" },
              { key: "fontOverride", type: "font",   label: "Font",            default: "" }
          ] },
        { source: "serp/AnserinClockMaterial.qml", name: "Material clock (Anserin)", group: "Time", designW: 220,
          settings: [
              { key: "colorAHex", type: "color", label: "Primary digit colour",   default: "" },
              { key: "colorBHex", type: "color", label: "Secondary digit colour", default: "" }
          ] },
        { source: "serp/AnserinClockMinimal.qml", name: "Minimal clock (Anserin)", group: "Time", designW: 250,
          settings: [
              { key: "showShadow",   type: "toggle", label: "Drop shadow", default: true },
              { key: "textHex",      type: "color",  label: "Text colour", default: "" },
              { key: "fontOverride", type: "font",   label: "Font",        default: "" }
          ] },
        { source: "serp/AnserinClockLockscreen.qml", name: "Lock-screen clock (Anserin)", group: "Time", designW: 300,
          settings: [
              { key: "showDate",     type: "toggle", label: "Show date",     default: true },
              { key: "hourHex",      type: "color",  label: "Hour colour",   default: "" },
              { key: "minuteHex",    type: "color",  label: "Minute colour", default: "" },
              { key: "dateHex",      type: "color",  label: "Date colour",   default: "" },
              { key: "fontOverride", type: "font",   label: "Font",          default: "" }
          ] },
        { source: "serp/AnserinClockStretched.qml", name: "Stretched clock (Anserin)", group: "Time", designW: 420,
          settings: [
              { key: "digitOpacity", type: "number", label: "Digit opacity", min: 0.2, max: 1.0, step: 0.05, default: 0.78 },
              { key: "textHex",      type: "color",  label: "Digit colour",  default: "" }
          ] },
        { source: "serp/AnserinUser.qml", name: "User card (Anserin)", group: "Other", designW: 260, title: "USER" },
        { source: "serp/AnserinGithub.qml", name: "GitHub contributions", group: "Other", designW: 540, title: "GITHUB",
          settings: [
              { key: "customUser", type: "text",  label: "GitHub username", default: "" },
              { key: "accentHex",  type: "color", label: "Heatmap colour",  default: "" }
          ] },
        { source: "serp/AnserinImageRounded.qml", name: "Picture, rounded", group: "Other", designW: 300,
          settings: [
              { key: "imagePath", type: "file",   label: "Image file path", default: "" },
              { key: "cropImage", type: "toggle", label: "Fill / crop",     default: false }
          ] },
        { source: "serp/AnserinImageRect.qml", name: "Picture, square corners", group: "Other", designW: 300,
          settings: [
              { key: "imagePath", type: "file",   label: "Image file path", default: "" },
              { key: "cropImage", type: "toggle", label: "Fill / crop",     default: false }
          ] },
        { source: "serp/AnserinImageRound.qml", name: "Picture, round", group: "Other", designW: 200,
          settings: [
              { key: "imagePath", type: "file",   label: "Image file path", default: "" },
              { key: "cropImage", type: "toggle", label: "Fill / crop",     default: true }
          ] },
        { source: "serp/AnserinText.qml", name: "Text", group: "Other", designW: 320,
          settings: [
              { key: "textContent", type: "text",   label: "Text",        default: "" },
              { key: "fontFamily",  type: "font",   label: "Font",        default: "" },
              { key: "textHex",     type: "color",  label: "Text colour", default: "" },
              { key: "align",       type: "choice", label: "Alignment",   choices: [{ value: "left", label: "Left" }, { value: "center", label: "Center" }, { value: "right", label: "Right" }], default: "center" },
              { key: "showShadow",  type: "toggle", label: "Drop shadow", default: true }
          ] },
        { source: "serp/AnserinNetworkCard.qml", name: "Network (small)", group: "Other", designW: 240, title: "NETWORK" },
        { source: "serp/AnserinBubbleCard.qml", name: "Processes (small)", group: "Other", designW: 240, title: "PROCESSES" }
    ]

    // Drop-in widgets: every widgets/user/<name>/widget.json found by WidgetConfigStore (see WIDGETS.md).
    // Same entry shape as builtinCatalog, plus `default` (size / orbit / show) and `settings` (the schema the panel draws).
    // Shared options applied automatically to every widget in a pack (merged after widget-specific settings)
    readonly property var groupSettings: ({
        "Glyph": [
            { key: "bgOpacity",    type: "number", label: "Card fill opacity", min: 0.0, max: 1.0, step: 0.05, default: 1.0 },
            { key: "borderWidth",  type: "number", label: "Border width",      min: 0, max: 4, step: 1, unit: "px", default: 1 },
            { key: "contentScale", type: "number", label: "Inner scale",       min: 0.7, max: 1.3, step: 0.05, default: 1.0 },
            { key: "showBrackets", type: "toggle", label: "Outer Wilds brackets", default: false }
        ],
        "Lucid": [
            { key: "frameMode",    type: "choice", label: "Frame style",       choices: [{ value: "auto", label: "Auto" }, { value: "card", label: "Force card" }, { value: "bare", label: "Bare" }], default: "auto" },
            { key: "borderWidth",  type: "number", label: "Border width",      min: 0, max: 4, step: 1, unit: "px", default: 1 },
            { key: "contentScale", type: "number", label: "Inner scale",       min: 0.7, max: 1.3, step: 0.05, default: 1.0 }
        ],
        "Serpantinum": [
            { key: "frameMode",    type: "choice", label: "Outer frame",       choices: [{ value: "auto", label: "Auto" }, { value: "card", label: "Force card" }, { value: "none", label: "None" }], default: "auto" },
            { key: "bracketMode",  type: "choice", label: "Corner brackets",   choices: [{ value: "auto", label: "Auto" }, { value: "on", label: "Always on" }, { value: "off", label: "Off" }], default: "auto" },
            { key: "borderWidth",  type: "number", label: "Frame border",      min: 0, max: 4, step: 1, unit: "px", default: 1 },
            { key: "framePad",     type: "number", label: "Frame padding",     min: 0, max: 24, step: 2, unit: "px", default: 0 },
            { key: "contentScale", type: "number", label: "Inner scale",       min: 0.7, max: 1.3, step: 0.05, default: 1.0 }
        ],
        "Time": [
            { key: "frameMode",    type: "choice", label: "Outer frame",       choices: [{ value: "auto", label: "Auto" }, { value: "card", label: "Force card" }, { value: "none", label: "None" }], default: "auto" },
            { key: "bracketMode",  type: "choice", label: "Corner brackets",   choices: [{ value: "auto", label: "Auto" }, { value: "on", label: "Always on" }, { value: "off", label: "Off" }], default: "auto" },
            { key: "borderWidth",  type: "number", label: "Frame border",      min: 0, max: 4, step: 1, unit: "px", default: 1 },
            { key: "framePad",     type: "number", label: "Frame padding",     min: 0, max: 24, step: 2, unit: "px", default: 0 },
            { key: "contentScale", type: "number", label: "Inner scale",       min: 0.7, max: 1.3, step: 0.05, default: 1.0 }
        ],
        "Other": [
            { key: "frameMode",    type: "choice", label: "Outer frame",       choices: [{ value: "auto", label: "Auto" }, { value: "card", label: "Force card" }, { value: "none", label: "None" }], default: "auto" },
            { key: "bracketMode",  type: "choice", label: "Corner brackets",   choices: [{ value: "auto", label: "Auto" }, { value: "on", label: "Always on" }, { value: "off", label: "Off" }], default: "auto" },
            { key: "borderWidth",  type: "number", label: "Frame border",      min: 0, max: 4, step: 1, unit: "px", default: 1 },
            { key: "framePad",     type: "number", label: "Frame padding",     min: 0, max: 24, step: 2, unit: "px", default: 0 },
            { key: "contentScale", type: "number", label: "Inner scale",       min: 0.7, max: 1.3, step: 0.05, default: 1.0 }
        ]
    })

    function settingsSchema(source) {
        const c = catalogEntry(source);
        if (!c) return [];
        const own = Array.isArray(c.settings) ? c.settings : [];
        const grp = (c.group && Array.isArray(groupSettings[c.group])) ? groupSettings[c.group] : [];
        if (grp.length === 0) return own;
        if (own.length === 0) return grp;
        const seen = {}, out = [];
        for (let i = 0; i < own.length; i++) { seen[own[i].key] = true; out.push(own[i]); }
        for (let i = 0; i < grp.length; i++) if (!seen[grp[i].key]) out.push(grp[i]);
        return out;
    }

    property var userCatalog: []
    property var catalog: builtinCatalog.concat(userCatalog)
    function setUserCatalog(list) { userCatalog = list; _bump(false); }

    // ---------------- state ----------------
    property var defaults: []        // registered by WidgetLayer (its baseDefs)
    property var extras: []          // widgets added from the panel (complete defs, ids "x1", "x2", ...)
    property var overrides: ({})     // id -> { host, enabled, size, speed, k, tilt, node, show, source }
    property real globalSpeed: 1.0   // multiplies every orbit (WidgetLayer.speedScale)
    property string previewId: ""    // the widget being edited: shown even if its planet is not in focus
    property bool panelOpen: false   // the settings panel window (SettingsWindow) follows this; the map's "Edit Widgets" button sets it
    property int revision: 0         // bumped on EVERY change (WidgetLayer / panel follow this)
    property bool loaded: false
    property var keyOverrides: ({})          // action id -> key sequence (Keybinds.qml); only the CHANGED keys are stored
    property bool showLoopPanel: true        // the bottom-right LOOP / SPEED panel (CameraRig)
    property bool shrinkFar: true            // widgets get much smaller when the planet is far away (WidgetSlot)
    property int bakeW: 1024                 // planet bake texture width: 512, 1024, or 2048 (PlanetShader)
    property bool showHud: true              // SatelliteHUD overlay (CameraRig)
    property bool showOrbits: true           // orbital path lines (CameraRig)
    property bool showLabels: true           // planet name / distance labels (PlanetShader)
    property bool showReticles: true         // hover and lock reticles (CameraRig)
    property int fpsIdle: 30                 // idle frame cap: 15, 30, 60, or 0 = off (CameraRig)
    property int fpsActive: 0                // active frame cap: 30, 60, 90, 120, or 0 = monitor rate (CameraRig)
    property bool spaceDrift: true           // 6-DOF space drift enabled (CameraRig)
    property real driftCruise: 80.0          // drift coasting speed (CameraRig)
    property real lockOrbitK: 6.5            // planet lock-on orbit distance multiplier (CameraRig)
    property real lookSens: 1.0              // mouse look/orbit sensitivity multiplier (CameraRig)
    property real defaultTimeScale: 1.0      // default loop speed multiplier (CameraRig)
    property real hudOpacity: 1.0            // SatelliteHUD opacity (0.1..1.0)
    property real hudScale: 1.0              // SatelliteHUD scale (0.5..1.5)
    property real orbitOpacity: 1.0          // orbit path opacity (0.1..1.0)
    property real orbitWidth: 1.2            // orbit line thickness in px (0.5..4.0)
    property real labelSize: 1.0             // planet label font multiplier (0.6..2.0)
    property real labelDist: 1500            // max distance to show unselected labels
    property real reticleOpacity: 1.0        // hover/lock reticle opacity (0.1..1.0)
    property real reticleWidth: 1.0          // reticle stroke multiplier (0.5..3.0)
    property real loopPanelOpacity: 1.0      // bottom-right loop panel opacity (0.2..1.0)
    property real loopPanelScale: 1.0        // bottom-right loop panel scale (0.6..1.5)
    property real widgetOpacity: 1.0         // global widget opacity multiplier (0.2..1.0)
    property real widgetRadius: 6.0          // global card corner radius in px (0..24)
    property string widgetAccent: "#D4AF37"  // global card bracket/accent colour
    property bool widgetHoldOnHover: true    // pause widget orbit while hovered
    property bool widgetBrackets: true       // show corner brackets on WidgetCards
    // ---- pack-wide theme overrides (blank = pack default) ----
    property string glyphBg: ""
    property string glyphBorder: ""
    property string glyphOff: ""
    property string glyphFg: ""
    property string glyphAccent: ""
    property string glyphFont: ""
    property string lucidBg: ""
    property string lucidText: ""
    property string lucidAccent: ""
    property string lucidFont: ""
    property string serpSurface: ""
    property string serpText: ""
    property string serpAccent: ""
    property real serpOpacity: 0.92
    property real serpRadius: 8
    property string serpFont: ""
    // ---- pinning ----
    property var pinnedIds: ({})
    property int pinnedCount: 0
    property var pinnedHosts: ({})
    property bool pinDimEnabled: true
    property string pinDimScope: "planet"
    property real pinDimOpacity: 0.25
    property real pinScale: 1.2
    property string pinOutlineColor: "#D4AF37"
    // ---- Satellite HUD individual options ----
    property bool hudShowGauges: true
    property bool hudShowAstronaut: true
    property bool hudShowGaugeLabels: true
    property real hudGaugeScale: 1.0
    property bool hudShowGlobe: true
    property bool hudShowGlobeStand: true
    property real hudGlobeScale: 1.0
    property string hudGlobeColor: "#6FEAEE"
    property bool hudShowThrust: true
    property bool hudShowSpeed: true
    property real hudThrustScale: 1.0
    property string hudThrustColor: "#C6F6F1"
    property bool hudShowPrompts: true
    property string hudTextColor: "#F2EBDD"
    property string hudFont: "monospace"
    // ---- named layout presets ----
    property var presets: ({})

    readonly property var uiDefaults: ({
        globalSpeed: 1.0,
        showHud: true, hudOpacity: 1.0, hudScale: 1.0,
        hudShowGauges: true, hudShowAstronaut: true, hudShowGaugeLabels: true, hudGaugeScale: 1.0,
        hudShowGlobe: true, hudShowGlobeStand: true, hudGlobeScale: 1.0, hudGlobeColor: "#6FEAEE",
        hudShowThrust: true, hudShowSpeed: true, hudThrustScale: 1.0, hudThrustColor: "#C6F6F1",
        hudShowPrompts: true, hudTextColor: "#F2EBDD", hudFont: "monospace",
        showLoopPanel: true, loopPanelOpacity: 1.0, loopPanelScale: 1.0,
        showOrbits: true, orbitOpacity: 1.0, orbitWidth: 1.2,
        showLabels: true, labelSize: 1.0, labelDist: 1500,
        showReticles: true, reticleOpacity: 1.0, reticleWidth: 1.0,
        shrinkFar: true, bakeW: 1024, fpsIdle: 30, fpsActive: 0,
        spaceDrift: true, driftCruise: 80.0, lockOrbitK: 6.5, lookSens: 1.0, defaultTimeScale: 1.0,
        widgetOpacity: 1.0, widgetRadius: 6.0, widgetAccent: "#D4AF37",
        widgetHoldOnHover: true, widgetBrackets: true,
        pinDimEnabled: true, pinDimScope: "planet", pinDimOpacity: 0.25, pinScale: 1.2, pinOutlineColor: "#D4AF37",
        glyphBg: "", glyphBorder: "", glyphOff: "", glyphFg: "", glyphAccent: "", glyphFont: "",
        lucidBg: "", lucidText: "", lucidAccent: "", lucidFont: "",
        serpSurface: "", serpText: "", serpAccent: "", serpOpacity: 0.92, serpRadius: 8, serpFont: ""
    })
    property string focusPlanet: ""          // the planet the camera is targeting / locked on ("" = none); set by KeyHost
    property string panelTab: "widgets"      // settings panel tab: widgets | keys | options
    property bool capturingKeys: false       // the panel is recording a key: HyprIpc parks Hyprland's own binds so Super+... reaches it

    signal saveRequested(string text)
    signal launcherRequested()               // the small app-launcher widget was clicked: LauncherWindow opens the big one

    property string _lastText: ""
    property bool _quiet: false
    property Timer _saveTimer: Timer {
        interval: 350
        onTriggered: {
            const t = root.serialize();
            root._lastText = t;
            root.saveRequested(t);
        }
    }

    // ---------------- helpers ----------------
    function _clone(o) { return JSON.parse(JSON.stringify(o)); }

    function catalogEntry(source) {
        for (let i = 0; i < catalog.length; i++) if (catalog[i].source === source) return catalog[i];
        return null;
    }

    function planetName(id) {
        for (let i = 0; i < planets.length; i++) if (planets[i].id === id) return planets[i].name;
        return id;
    }

    function planetColor(id) {
        const map = {
            sun: "#FFB347", sun_station: "#E8883A", ash_twin: "#D4B483", ember_twin: "#C96A42",
            timber_hearth: "#63A375", attlerock: "#9A9A9A", brittle_hollow: "#6E85B7",
            hollows_lantern: "#E85D3F", giants_deep: "#55B399", dark_bramble: "#7D9B84",
            interloper: "#A7D8E8", quantum_moon: "#C5B4E3"
        };
        return map[id] || "#D4AF37";
    }

    function widgetName(def) {
        const c = catalogEntry(def.source);
        if (def.source === "BlankWidget.qml" && def.title) return def.title;
        return c ? c.name : def.source;
    }

    function _rebuildPinnedHosts() {
        const hosts = {};
        const list = _baseList();
        for (let i = 0; i < list.length; i++) {
            const id = list[i].def.id;
            if (pinnedIds[id] !== true) continue;
            const ov = overrides[id];
            if (ov && (ov.removed === true || ov.enabled === false)) continue;
            const h = (ov && ov.host !== undefined) ? ov.host : list[i].def.host;
            hosts[h] = true;
        }
        pinnedHosts = hosts;
    }

    function _bump(save) {
        _rebuildPinnedHosts();
        revision++;
        if (save && !_quiet) _saveTimer.restart();
    }

    // ---------------- merge ----------------
    // base def + this id's overrides -> the def the slot actually uses (a fresh object each call).
    // the widget's option values: schema defaults, then this id's saved overrides (a widget reads them as `cfg.key`)
    function _cfgFor(source, ov) {
        const cfg = {}, sch = settingsSchema(source);
        for (let i = 0; i < sch.length; i++) cfg[sch[i].key] = sch[i].default;
        if (ov && ov.settings) for (const k in ov.settings) cfg[k] = ov.settings[k];
        return cfg;
    }
    function _resolveOne(base, ov, isExtra) {
        const d = _resolveCore(base, ov, isExtra);
        d.cfg = _cfgFor(d.source, ov);
        return d;
    }
    function _resolveCore(base, ov, isExtra) {
        const d = _clone(base);
        d.baseHost = base.host;
        d.baseSource = base.source;
        d._extra = isExtra === true;
        d._base = { host: base.host, speed: base.orbit.speed, k: base.orbit.k, tilt: base.orbit.tilt, node: base.orbit.node || 0,
                    show: base.show, source: base.source };
        d.enabled = true;
        d.removed = false;
        d.size = 1;
        d.opacity = 1.0;
        d.holdOnHover = true;
        d.cardBg = "";
        d.cardAccent = "";
        d.cardBorder = "";
        d.cardRadius = -1;
        d.showBrackets = true;
        d.customTitle = "";
        if (!ov) return d;

        if (ov.host !== undefined) d.host = ov.host;
        if (ov.enabled !== undefined) d.enabled = ov.enabled;
        if (ov.removed !== undefined) d.removed = ov.removed;
        if (ov.show !== undefined) d.show = ov.show;
        if (ov.speed !== undefined) d.orbit.speed = ov.speed;
        if (ov.k !== undefined) d.orbit.k = ov.k;
        if (ov.tilt !== undefined) d.orbit.tilt = ov.tilt;
        if (ov.node !== undefined) d.orbit.node = ov.node;
        if (ov.opacity !== undefined) d.opacity = ov.opacity;
        if (ov.holdOnHover !== undefined) d.holdOnHover = ov.holdOnHover;
        if (ov.cardBg !== undefined) d.cardBg = ov.cardBg;
        if (ov.cardAccent !== undefined) d.cardAccent = ov.cardAccent;
        if (ov.cardBorder !== undefined) d.cardBorder = ov.cardBorder;
        if (ov.cardRadius !== undefined) d.cardRadius = ov.cardRadius;
        if (ov.showBrackets !== undefined) d.showBrackets = ov.showBrackets;
        if (ov.customTitle !== undefined) d.customTitle = ov.customTitle;

        if (ov.source !== undefined && ov.source !== base.source) {
            // another widget type in the same slot: its own title, and a width that keeps the on-screen size similar
            const oldC = catalogEntry(base.source), newC = catalogEntry(ov.source);
            d.source = ov.source;
            if (newC && newC.title !== undefined) d.title = newC.title; else delete d.title;
            if (oldC && newC && oldC.designW > 0 && d.worldW !== undefined) d.worldW = d.worldW * newC.designW / oldC.designW;
        }

        if (ov.size !== undefined && ov.size > 0) {
            // uniform scale: the width AND both clamps, otherwise the clamp would cancel the change at most zoom levels
            const m = ov.size;
            if (d.worldW !== undefined) d.worldW *= m;
            if (d.worldWk !== undefined) d.worldWk *= m;
            d.minUi = (d.minUi !== undefined ? d.minUi : 0.4) * m;
            d.maxUi = (d.maxUi !== undefined ? d.maxUi : 1.5) * m;
        }
        d.size = (ov.size !== undefined && ov.size > 0) ? ov.size : 1;
        return d;
    }

    function _baseList() {
        const out = [];
        for (let i = 0; i < defaults.length; i++) out.push({ def: defaults[i], extra: false });
        for (let j = 0; j < extras.length; j++) out.push({ def: extras[j], extra: true });
        return out;
    }

    // all widgets that are still ON a planet, including switched-off ones (the panel lists these); removed ones are not here
    function entries() {
        revision;   // binding dependency
        const list = _baseList(), out = [];
        for (let i = 0; i < list.length; i++) {
            const e = _resolveOne(list[i].def, overrides[list[i].def.id], list[i].extra);
            if (!e.removed) out.push(e);
        }
        return out;
    }

    // default widgets that were removed from their planet (the picker offers them for restoring)
    function removedEntries() {
        revision;
        const out = [];
        for (let i = 0; i < defaults.length; i++) {
            const e = _resolveOne(defaults[i], overrides[defaults[i].id], false);
            if (e.removed) out.push(e);
        }
        return out;
    }

    // enabled widgets only (the layer builds slots for these)
    function liveDefs() {
        const all = entries(), out = [];
        for (let i = 0; i < all.length; i++) if (all[i].enabled !== false) out.push(all[i]);
        return out;
    }

    // one widget, resolved on its own (cheap: the panel rows call this)
    function entry(id) {
        revision;   // binding dependency
        const list = _baseList();
        for (let i = 0; i < list.length; i++)
            if (list[i].def.id === id) return _resolveOne(list[i].def, overrides[id], list[i].extra);
        return null;
    }

    function registerDefaults(defs) {
        if (JSON.stringify(defs) === JSON.stringify(defaults)) return;
        defaults = _clone(defs);
        _bump(false);
    }

    // ---------------- edits (all called by the panel) ----------------
    function _baseFor(id) {
        for (let i = 0; i < defaults.length; i++) if (defaults[i].id === id) return defaults[i];
        for (let j = 0; j < extras.length; j++) if (extras[j].id === id) return extras[j];
        return null;
    }

    function _same(a, b) { return typeof a === "number" && typeof b === "number" ? Math.abs(a - b) < 1e-6 : a === b; }

    // field: host | enabled | removed | size | speed | k | tilt | node | show | source
    function setField(id, field, value) {
        const base = _baseFor(id);
        if (!base) return;
        // the only things refused are the ones that break the scene: NaN/Infinity, a size <= 0, a negative orbit radius
        if (typeof value === "number") {
            if (!isFinite(value)) return;
            if (field === "size" && !(value > 0)) return;
            if (field === "k" && value < 0) value = 0;
            if (field === "opacity") value = Math.max(0.05, Math.min(1.0, value));
            if (field === "cardRadius" && value < -1) value = -1;
        }
        const baseVal = { host: base.host, enabled: true, removed: false, size: 1, speed: base.orbit.speed, k: base.orbit.k, tilt: base.orbit.tilt,
                          node: base.orbit.node || 0, show: base.show, source: base.source,
                          opacity: 1.0, holdOnHover: true, cardBg: "", cardAccent: "", cardBorder: "",
                          cardRadius: -1, showBrackets: true, customTitle: "" }[field];
        const o = _clone(overrides);
        if (!o[id]) o[id] = {};
        if (_same(value, baseVal)) delete o[id][field]; else o[id][field] = value;
        if (Object.keys(o[id]).length === 0) delete o[id];
        overrides = o;
        _bump(true);
    }

    function setGlobalSpeed(v) { if (!isFinite(v) || v < 0) return; globalSpeed = v; _bump(true); }

    // one widget option (schema key) -> saved under overrides[id].settings; a value equal to the default is dropped
    function setSetting(id, key, value) {
        const base = _baseFor(id);
        if (!base) return;
        const src = (overrides[id] && overrides[id].source !== undefined) ? overrides[id].source : base.source;
        const sch = settingsSchema(src);
        let def;
        for (let i = 0; i < sch.length; i++) if (sch[i].key === key) def = sch[i].default;
        const o = _clone(overrides);
        if (!o[id]) o[id] = {};
        const st = o[id].settings ? o[id].settings : {};
        if (JSON.stringify(value) === JSON.stringify(def)) delete st[key]; else st[key] = value;
        if (Object.keys(st).length === 0) delete o[id].settings; else o[id].settings = st;
        if (Object.keys(o[id]).length === 0) delete o[id];
        overrides = o;
        _bump(true);
    }

    function resetWidget(id) {
        if (!overrides[id]) return;
        const o = _clone(overrides);
        delete o[id];
        overrides = o;
        _bump(true);
    }

    function fieldIsModified(id, field) {
        revision;
        return !!(overrides[id] && overrides[id][field] !== undefined);
    }

    function resetField(id, field) {
        if (!overrides[id] || overrides[id][field] === undefined) return;
        const o = _clone(overrides);
        delete o[id][field];
        if (Object.keys(o[id]).length === 0) delete o[id];
        overrides = o;
        _bump(true);
    }

    function settingIsModified(id, key) {
        revision;
        return !!(overrides[id] && overrides[id].settings && overrides[id].settings[key] !== undefined);
    }

    function resetSetting(id, key) {
        if (!overrides[id] || !overrides[id].settings || overrides[id].settings[key] === undefined) return;
        const o = _clone(overrides);
        delete o[id].settings[key];
        if (Object.keys(o[id].settings).length === 0) delete o[id].settings;
        if (Object.keys(o[id]).length === 0) delete o[id];
        overrides = o;
        _bump(true);
    }

    function isPinned(id) { revision; return pinnedIds[id] === true; }
    function _recountPins(m) {
        let n = 0;
        for (const k in m) if (m[k] === true) n++;
        return n;
    }
    function setPinned(id, v) {
        const m = _clone(pinnedIds);
        if (v) m[id] = true; else delete m[id];
        pinnedIds = m;
        pinnedCount = _recountPins(m);
        _bump(true);
    }
    function togglePin(id) { setPinned(id, pinnedIds[id] !== true); }
    function unpinAll() {
        if (pinnedCount === 0) return;
        pinnedIds = ({});
        pinnedCount = 0;
        _bump(true);
    }

    function resetAll() {
        overrides = ({});
        extras = [];
        pinnedIds = ({});
        pinnedCount = 0;
        globalSpeed = 1.0;
        previewId = "";
        _bump(true);
    }

    // new widget from the catalog; returns its id
    function addWidget(source, host) {
        const c = catalogEntry(source);
        let n = 1;
        const taken = {};
        for (let i = 0; i < extras.length; i++) taken[extras[i].id] = true;
        while (taken["x" + n]) n++;
        const id = "x" + n;
        // spread new widgets over different planes so they do not sit on top of each other
        const seed = (n * 2.399963) % (Math.PI * 2);
        const def = {
            id: id, host: host, source: source, show: "focus",
            worldWk: 1.25, minUi: 0.5, maxUi: 1.4,
            orbit: { k: 2.0, add: 40, tilt: Math.sin(seed * 1.7) * 0.9, node: seed % 3.0, phase: seed, speed: 0.2 }
        };
        if (c && c.title !== undefined) def.title = c.title;
        if (c && c.default && typeof c.default === "object") {      // a drop-in widget's own defaults (host is always the one asked for)
            const m = c.default;
            for (const k of ["show", "worldW", "worldWk", "minUi", "maxUi"]) if (m[k] !== undefined) def[k] = m[k];
            if (m.worldW !== undefined && m.worldWk === undefined) delete def.worldWk;
            if (m.orbit) for (const k in m.orbit) def.orbit[k] = m.orbit[k];
        }
        const e = extras.slice();
        e.push(def);
        extras = e;
        previewId = id;
        _bump(true);
        return id;
    }

    // Takes a widget OFF its planet for good (it is not just switched off).
    //  * a widget added from the panel is deleted;
    //  * a default widget is marked `removed`: gone from the planet and the list, but still offered by the picker
    //    ("restore" with its original planet / orbit), because the picker lists the whole catalog.
    function removeWidget(id) {
        let isExtra = false;
        for (let i = 0; i < extras.length; i++) if (extras[i].id === id) isExtra = true;
        const o = _clone(overrides);
        if (isExtra) {
            const e = [];
            for (let i = 0; i < extras.length; i++) if (extras[i].id !== id) e.push(extras[i]);
            extras = e;
            delete o[id];
        } else {
            if (!_baseFor(id)) return;
            o[id] = { removed: true };          // other edits are dropped: restoring brings back the original
        }
        overrides = o;
        if (pinnedIds[id]) { const pm = _clone(pinnedIds); delete pm[id]; pinnedIds = pm; pinnedCount = _recountPins(pm); }
        if (previewId === id) previewId = "";
        _bump(true);
    }

    function restoreWidget(id) {
        if (!overrides[id] || !overrides[id].removed) return;
        const o = _clone(overrides);
        delete o[id];
        overrides = o;
        previewId = id;
        _bump(true);
    }

    // removes every switched-off widget from its planet; returns how many
    function removeDisabled() {
        const all = entries();
        let n = 0;
        for (let i = 0; i < all.length; i++) if (all[i].enabled === false) { removeWidget(all[i].id); n++; }
        return n;
    }

    // removes EVERY widget from its planet (the picker still lists them all; "RESET ALL WIDGETS" brings the defaults back); returns how many
    function removeAll() {
        const all = entries();
        let n = 0;
        for (let i = 0; i < all.length; i++) { removeWidget(all[i].id); n++; }
        return n;
    }

    function disabledCount() {
        const all = entries();
        let n = 0;
        for (let i = 0; i < all.length; i++) if (all[i].enabled === false) n++;
        return n;
    }

    // the planet an enabled widget of this file sits on ("" = none); used to open the launcher / map "where the widget is"
    function planetOfSource(source) {
        const all = entries();
        for (let i = 0; i < all.length; i++) if (all[i].source === source && all[i].enabled !== false) return all[i].host;
        return "";
    }

    // ---------------- keys / options ----------------
    function setKey(action, seq) {
        const o = _clone(keyOverrides);
        o[action] = seq;
        keyOverrides = o;
        _bump(true);
    }
    function resetKey(action) {
        if (keyOverrides[action] === undefined) return;
        const o = _clone(keyOverrides);
        delete o[action];
        keyOverrides = o;
        _bump(true);
    }
    function resetKeys() { keyOverrides = ({}); _bump(true); }
    function setShrinkFar(v) { if (shrinkFar === v) return; shrinkFar = v; _bump(true); }
    function setShowLoopPanel(v) { if (showLoopPanel === v) return; showLoopPanel = v; _bump(true); }
    function setBakeW(v) { const n = Number(v); if (n !== 512 && n !== 1024 && n !== 2048) return; if (bakeW === n) return; bakeW = n; _bump(true); }
    function setShowHud(v) { if (showHud === v) return; showHud = v; _bump(true); }
    function setShowOrbits(v) { if (showOrbits === v) return; showOrbits = v; _bump(true); }
    function setShowLabels(v) { if (showLabels === v) return; showLabels = v; _bump(true); }
    function setShowReticles(v) { if (showReticles === v) return; showReticles = v; _bump(true); }
    function setFpsIdle(v) { const n = Number(v); if (n !== 0 && n !== 15 && n !== 30 && n !== 60) return; if (fpsIdle === n) return; fpsIdle = n; _bump(true); }
    function setHudOpacity(v) { const n = Math.max(0.1, Math.min(1.0, Number(v))); if (!isFinite(n) || hudOpacity === n) return; hudOpacity = n; _bump(true); }
    function setHudScale(v) { const n = Math.max(0.5, Math.min(1.5, Number(v))); if (!isFinite(n) || hudScale === n) return; hudScale = n; _bump(true); }
    function setOrbitOpacity(v) { const n = Math.max(0.1, Math.min(1.0, Number(v))); if (!isFinite(n) || orbitOpacity === n) return; orbitOpacity = n; _bump(true); }
    function setOrbitWidth(v) { const n = Math.max(0.4, Math.min(4.0, Number(v))); if (!isFinite(n) || orbitWidth === n) return; orbitWidth = n; _bump(true); }
    function setLabelSize(v) { const n = Math.max(0.6, Math.min(2.0, Number(v))); if (!isFinite(n) || labelSize === n) return; labelSize = n; _bump(true); }
    function setLabelDist(v) { const n = Math.max(400, Math.min(8000, Number(v))); if (!isFinite(n) || labelDist === n) return; labelDist = n; _bump(true); }
    function setReticleOpacity(v) { const n = Math.max(0.1, Math.min(1.0, Number(v))); if (!isFinite(n) || reticleOpacity === n) return; reticleOpacity = n; _bump(true); }
    function setReticleWidth(v) { const n = Math.max(0.5, Math.min(3.0, Number(v))); if (!isFinite(n) || reticleWidth === n) return; reticleWidth = n; _bump(true); }
    function setLoopPanelOpacity(v) { const n = Math.max(0.2, Math.min(1.0, Number(v))); if (!isFinite(n) || loopPanelOpacity === n) return; loopPanelOpacity = n; _bump(true); }
    function setLoopPanelScale(v) { const n = Math.max(0.6, Math.min(1.5, Number(v))); if (!isFinite(n) || loopPanelScale === n) return; loopPanelScale = n; _bump(true); }
    function setWidgetOpacity(v) { const n = Math.max(0.2, Math.min(1.0, Number(v))); if (!isFinite(n) || widgetOpacity === n) return; widgetOpacity = n; _bump(true); }
    function setWidgetRadius(v) { const n = Math.max(0, Math.min(24, Number(v))); if (!isFinite(n) || widgetRadius === n) return; widgetRadius = n; _bump(true); }
    function setWidgetAccent(v) { const s = String(v || "").trim() || "#D4AF37"; if (widgetAccent === s) return; widgetAccent = s; _bump(true); }
    function setWidgetHoldOnHover(v) { if (widgetHoldOnHover === v) return; widgetHoldOnHover = v; _bump(true); }
    function setWidgetBrackets(v) { if (widgetBrackets === v) return; widgetBrackets = v; _bump(true); }
    function setPackTheme(key, val) {
        if (key === "serpOpacity") { const n = Math.max(0.1, Math.min(1.0, Number(val))); if (!isFinite(n) || serpOpacity === n) return; serpOpacity = n; _bump(true); return; }
        if (key === "serpRadius") { const n = Math.max(0, Math.min(28, Number(val))); if (!isFinite(n) || serpRadius === n) return; serpRadius = n; _bump(true); return; }
        const s = String(val || "").trim();
        if (root[key] === undefined || root[key] === s) return;
        root[key] = s;
        _bump(true);
    }
    function resetPackThemes() {
        glyphBg = ""; glyphBorder = ""; glyphOff = ""; glyphFg = ""; glyphAccent = ""; glyphFont = "";
        lucidBg = ""; lucidText = ""; lucidAccent = ""; lucidFont = "";
        serpSurface = ""; serpText = ""; serpAccent = ""; serpOpacity = 0.92; serpRadius = 8; serpFont = "";
        _bump(true);
    }

    function setUiOpt(key, val) {
        if (uiDefaults[key] === undefined) return;
        let v = val;
        if (typeof uiDefaults[key] === "number") {
            v = Number(val);
            if (!isFinite(v)) return;
            if (key === "pinDimOpacity") v = Math.max(0.05, Math.min(1.0, v));
            else if (key === "pinScale") v = Math.max(1.0, Math.min(2.5, v));
            else if (key === "pinDimScope") { if (v !== "planet" && v !== "everywhere") return; }
            else if (key === "fpsActive") { v = Math.round(v); if (v !== 0 && v !== 30 && v !== 60 && v !== 90 && v !== 120) return; }
            else if (key === "driftCruise") v = Math.max(10, v);
            else if (key === "lockOrbitK") v = Math.max(2.2, v);
            else if (key === "lookSens") v = Math.max(0.1, v);
            else if (key === "defaultTimeScale") v = Math.max(0.1, v);
            else if (key === "hudGaugeScale" || key === "hudGlobeScale" || key === "hudThrustScale") v = Math.max(0.5, Math.min(1.8, v));
        } else if (typeof uiDefaults[key] === "boolean") {
            v = val === true;
        } else {
            v = String(val || "").trim();
        }
        if (_same(root[key], v)) return;
        root[key] = v;
        _bump(true);
    }

    function isUiModified(key) {
        revision;
        if (uiDefaults[key] === undefined) return false;
        return !_same(root[key], uiDefaults[key]);
    }

    function resetUiOption(key) {
        if (uiDefaults[key] === undefined) return;
        if (_same(root[key], uiDefaults[key])) return;
        root[key] = uiDefaults[key];
        _bump(true);
    }

    function _uiDict() {
        return {
            loopPanel: showLoopPanel, shrinkFar: shrinkFar, bakeW: bakeW, hud: showHud, orbits: showOrbits,
            labels: showLabels, reticles: showReticles, fpsIdle: fpsIdle, fpsActive: fpsActive,
            spaceDrift: spaceDrift, driftCruise: driftCruise, lockOrbitK: lockOrbitK, lookSens: lookSens, defaultTimeScale: defaultTimeScale, hudOpacity: hudOpacity, hudScale: hudScale,
            hudShowGauges: hudShowGauges, hudShowAstronaut: hudShowAstronaut, hudShowGaugeLabels: hudShowGaugeLabels,
            hudGaugeScale: hudGaugeScale, hudShowGlobe: hudShowGlobe, hudShowGlobeStand: hudShowGlobeStand,
            hudGlobeScale: hudGlobeScale, hudGlobeColor: hudGlobeColor, hudShowThrust: hudShowThrust,
            hudShowSpeed: hudShowSpeed, hudThrustScale: hudThrustScale, hudThrustColor: hudThrustColor,
            hudShowPrompts: hudShowPrompts, hudTextColor: hudTextColor, hudFont: hudFont,
            orbitOpacity: orbitOpacity, orbitWidth: orbitWidth, labelSize: labelSize, labelDist: labelDist,
            reticleOpacity: reticleOpacity, reticleWidth: reticleWidth, loopPanelOpacity: loopPanelOpacity,
            loopPanelScale: loopPanelScale, widgetOpacity: widgetOpacity, widgetRadius: widgetRadius,
            widgetAccent: widgetAccent, widgetHoldOnHover: widgetHoldOnHover, widgetBrackets: widgetBrackets,
            pinDimEnabled: pinDimEnabled, pinDimScope: pinDimScope, pinDimOpacity: pinDimOpacity, pinScale: pinScale, pinOutlineColor: pinOutlineColor,
            glyphBg: glyphBg, glyphBorder: glyphBorder, glyphOff: glyphOff, glyphFg: glyphFg,
            glyphAccent: glyphAccent, glyphFont: glyphFont, lucidBg: lucidBg, lucidText: lucidText,
            lucidAccent: lucidAccent, lucidFont: lucidFont, serpSurface: serpSurface, serpText: serpText,
            serpAccent: serpAccent, serpOpacity: serpOpacity, serpRadius: serpRadius, serpFont: serpFont
        };
    }

    function _applyUiDict(u) {
        if (!u || typeof u !== "object") return;
        showLoopPanel = u.loopPanel !== false;
        shrinkFar = u.shrinkFar !== false;
        const bw = Number(u.bakeW);
        bakeW = (bw === 512 || bw === 1024 || bw === 2048) ? bw : 1024;
        showHud = u.hud !== false;
        showOrbits = u.orbits !== false;
        showLabels = u.labels !== false;
        showReticles = u.reticles !== false;
        const fi = u.fpsIdle !== undefined ? Number(u.fpsIdle) : 30;
        fpsIdle = (fi === 0 || fi === 15 || fi === 30 || fi === 60) ? fi : 30;
        const fa = u.fpsActive !== undefined ? Number(u.fpsActive) : 0;
        fpsActive = (fa === 0 || fa === 30 || fa === 60 || fa === 90 || fa === 120) ? fa : 0;
        spaceDrift = u.spaceDrift !== false;
        driftCruise = typeof u.driftCruise === 'number' && u.driftCruise >= 10 ? u.driftCruise : 80.0;
        lockOrbitK = typeof u.lockOrbitK === 'number' && u.lockOrbitK >= 2.2 ? u.lockOrbitK : 6.5;
        lookSens = typeof u.lookSens === 'number' && u.lookSens >= 0.1 ? u.lookSens : 1.0;
        defaultTimeScale = typeof u.defaultTimeScale === 'number' && u.defaultTimeScale >= 0.1 ? u.defaultTimeScale : 1.0;
        hudOpacity = typeof u.hudOpacity === "number" ? u.hudOpacity : 1.0;
        hudScale = typeof u.hudScale === "number" ? u.hudScale : 1.0;
        hudShowGauges = u.hudShowGauges !== false;
        hudShowAstronaut = u.hudShowAstronaut !== false;
        hudShowGaugeLabels = u.hudShowGaugeLabels !== false;
        hudGaugeScale = typeof u.hudGaugeScale === "number" ? u.hudGaugeScale : 1.0;
        hudShowGlobe = u.hudShowGlobe !== false;
        hudShowGlobeStand = u.hudShowGlobeStand !== false;
        hudGlobeScale = typeof u.hudGlobeScale === "number" ? u.hudGlobeScale : 1.0;
        hudGlobeColor = typeof u.hudGlobeColor === "string" && u.hudGlobeColor !== "" ? u.hudGlobeColor : "#6FEAEE";
        hudShowThrust = u.hudShowThrust !== false;
        hudShowSpeed = u.hudShowSpeed !== false;
        hudThrustScale = typeof u.hudThrustScale === "number" ? u.hudThrustScale : 1.0;
        hudThrustColor = typeof u.hudThrustColor === "string" && u.hudThrustColor !== "" ? u.hudThrustColor : "#C6F6F1";
        hudShowPrompts = u.hudShowPrompts !== false;
        hudTextColor = typeof u.hudTextColor === "string" && u.hudTextColor !== "" ? u.hudTextColor : "#F2EBDD";
        hudFont = typeof u.hudFont === "string" && u.hudFont !== "" ? u.hudFont : "monospace";
        orbitOpacity = typeof u.orbitOpacity === "number" ? u.orbitOpacity : 1.0;
        orbitWidth = typeof u.orbitWidth === "number" ? u.orbitWidth : 1.2;
        labelSize = typeof u.labelSize === "number" ? u.labelSize : 1.0;
        labelDist = typeof u.labelDist === "number" ? u.labelDist : 1500;
        reticleOpacity = typeof u.reticleOpacity === "number" ? u.reticleOpacity : 1.0;
        reticleWidth = typeof u.reticleWidth === "number" ? u.reticleWidth : 1.0;
        loopPanelOpacity = typeof u.loopPanelOpacity === "number" ? u.loopPanelOpacity : 1.0;
        loopPanelScale = typeof u.loopPanelScale === "number" ? u.loopPanelScale : 1.0;
        widgetOpacity = typeof u.widgetOpacity === "number" ? u.widgetOpacity : 1.0;
        widgetRadius = typeof u.widgetRadius === "number" ? u.widgetRadius : 6.0;
        widgetAccent = typeof u.widgetAccent === "string" && u.widgetAccent !== "" ? u.widgetAccent : "#D4AF37";
        widgetHoldOnHover = u.widgetHoldOnHover !== false;
        widgetBrackets = u.widgetBrackets !== false;
        pinDimEnabled = u.pinDimEnabled !== false;
        pinDimScope = u.pinDimScope === "everywhere" ? "everywhere" : "planet";
        pinDimOpacity = typeof u.pinDimOpacity === "number" ? u.pinDimOpacity : 0.25;
        pinScale = typeof u.pinScale === "number" ? u.pinScale : 1.2;
        pinOutlineColor = typeof u.pinOutlineColor === "string" && u.pinOutlineColor !== "" ? u.pinOutlineColor : "#D4AF37";
        glyphBg = typeof u.glyphBg === "string" ? u.glyphBg : "";
        glyphBorder = typeof u.glyphBorder === "string" ? u.glyphBorder : "";
        glyphOff = typeof u.glyphOff === "string" ? u.glyphOff : "";
        glyphFg = typeof u.glyphFg === "string" ? u.glyphFg : "";
        glyphAccent = typeof u.glyphAccent === "string" ? u.glyphAccent : "";
        glyphFont = typeof u.glyphFont === "string" ? u.glyphFont : "";
        lucidBg = typeof u.lucidBg === "string" ? u.lucidBg : "";
        lucidText = typeof u.lucidText === "string" ? u.lucidText : "";
        lucidAccent = typeof u.lucidAccent === "string" ? u.lucidAccent : "";
        lucidFont = typeof u.lucidFont === "string" ? u.lucidFont : "";
        serpSurface = typeof u.serpSurface === "string" ? u.serpSurface : "";
        serpText = typeof u.serpText === "string" ? u.serpText : "";
        serpAccent = typeof u.serpAccent === "string" ? u.serpAccent : "";
        serpOpacity = typeof u.serpOpacity === "number" ? u.serpOpacity : 0.92;
        serpRadius = typeof u.serpRadius === "number" ? u.serpRadius : 8;
        serpFont = typeof u.serpFont === "string" ? u.serpFont : "";
    }

    function presetNames() {
        revision;
        return Object.keys(presets || {}).sort();
    }

    function _makeSnapshot() {
        return {
            globalSpeed: globalSpeed,
            overrides: _clone(overrides),
            extras: _clone(extras),
            pinned: _clone(pinnedIds),
            ui: _uiDict()
        };
    }

    function _applySnapshot(snap) {
        if (!snap || typeof snap !== "object") return;
        overrides = (snap.overrides && typeof snap.overrides === "object") ? _clone(snap.overrides) : ({});
        extras = Array.isArray(snap.extras) ? _clone(snap.extras) : [];
        globalSpeed = typeof snap.globalSpeed === "number" ? snap.globalSpeed : 1.0;
        pinnedIds = (snap.pinned && typeof snap.pinned === "object") ? _clone(snap.pinned) : ({});
        pinnedCount = _recountPins(pinnedIds);
        if (snap.ui && typeof snap.ui === "object") _applyUiDict(snap.ui);
        previewId = "";
        _bump(true);
    }

    function savePreset(name) {
        const clean = String(name || "").trim();
        if (!clean) return false;
        const p = _clone(presets || {});
        p[clean] = _makeSnapshot();
        presets = p;
        _bump(true);
        return true;
    }

    function loadPreset(name) {
        if (!presets || !presets[name]) return false;
        _applySnapshot(presets[name]);
        return true;
    }

    function deletePreset(name) {
        if (!presets || !presets[name]) return false;
        const p = _clone(presets);
        delete p[name];
        presets = p;
        _bump(true);
        return true;
    }

    function exportPresetJson(name) {
        const clean = String(name || "").trim();
        const data = (clean && presets && presets[clean]) ? _clone(presets[clean]) : _makeSnapshot();
        return JSON.stringify({ format: "outerwilds-preset", version: 1, name: clean || "current-layout", data: data }, null, 2);
    }

    function importPresetJson(text, fallbackName) {
        let obj = null;
        try { obj = JSON.parse(String(text || "")); } catch (e) { return { ok: false, error: "Invalid JSON: " + e }; }
        if (!obj || typeof obj !== "object") return { ok: false, error: "JSON root must be an object." };
        const data = (obj.format === "outerwilds-preset" && obj.data && typeof obj.data === "object") ? obj.data : obj;
        if (data.overrides === undefined && data.extras === undefined && data.ui === undefined)
            return { ok: false, error: "File does not look like an Outer Wilds preset." };
        const name = String(obj.name || fallbackName || "Imported").trim() || "Imported";
        const p = _clone(presets || {});
        p[name] = {
            globalSpeed: typeof data.globalSpeed === "number" ? data.globalSpeed : 1.0,
            overrides: (data.overrides && typeof data.overrides === "object") ? _clone(data.overrides) : ({}),
            extras: Array.isArray(data.extras) ? _clone(data.extras) : [],
            pinned: (data.pinned && typeof data.pinned === "object") ? _clone(data.pinned) : ({}),
            ui: (data.ui && typeof data.ui === "object") ? _clone(data.ui) : ({})
        };
        presets = p;
        _applySnapshot(p[name]);
        return { ok: true, name: name };
    }

    // ---------------- persistence ----------------
    function serialize() {
        return JSON.stringify({
            version: 1, globalSpeed: globalSpeed, overrides: overrides, extras: extras,
            pinned: pinnedIds, presets: presets, keys: keyOverrides, ui: _uiDict()
        }, null, 2);
    }

    // called by WidgetConfigStore after reading widgets.json ("" = no file yet)
    function load(text) {
        if (text === _lastText && loaded) return;     // our own write coming back through the file watcher
        _lastText = text;
        let obj = null;
        try { obj = text && text.trim() !== "" ? JSON.parse(text) : null; } catch (e) { console.warn("widgets.json is not valid JSON, ignoring it: " + e); }
        _quiet = true;
        overrides = (obj && obj.overrides && typeof obj.overrides === "object") ? obj.overrides : ({});
        extras = (obj && Array.isArray(obj.extras)) ? obj.extras : [];
        globalSpeed = (obj && typeof obj.globalSpeed === "number") ? obj.globalSpeed : 1.0;
        keyOverrides = (obj && obj.keys && typeof obj.keys === "object") ? obj.keys : ({});
        pinnedIds = (obj && obj.pinned && typeof obj.pinned === "object") ? obj.pinned : ({});
        pinnedCount = _recountPins(pinnedIds);
        presets = (obj && obj.presets && typeof obj.presets === "object") ? obj.presets : ({});
        _applyUiDict((obj && obj.ui) ? obj.ui : {});
        loaded = true;
        _bump(false);
        _quiet = false;
    }
}
