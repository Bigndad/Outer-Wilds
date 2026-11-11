# Glyph widgets

Nothing-style (black, white dots, one red) orbit widgets, modelled on the look of
https://github.com/Nebelung-cloud/glyph-rice (GPL-3.0): the round Glyph Matrix visualiser, LED-ring gauges,
dot-matrix digits, the Cal month view and the focus timer. The QML here is written fresh for this project
(no shaders, no font files, no Quickshell imports); only the design language and palette come from glyph-rice.
If you ever share this config, keep it GPL-3.0-compatible. Nothing and Glyph are trademarks of Nothing
Technology Ltd; this is a fan project.

| file | what | data |
|---|---|---|
| GlyphMatrix | 15x15 round spectrum, bass in the middle, red centre dot while audio plays | HudData.bandsA/B |
| GlyphCpu / GlyphRam / GlyphGpu | LED ring + dot number, red at 85% | Sensors |
| GlyphClock | dot-matrix HH:mm, red colon, 60-dot seconds strip | WidgetData.now |
| GlyphSystem | cpu, ram GB, gpu temp, vram + 68 s cpu history | Sensors |
| GlyphCal | month view, Monday first, today in red, arrows / click title | WidgetData.now |
| GlyphFocus | focus timer on a draining ring, red while running | local timer |

Building blocks: GlyphCard (slot contract), GlyphDots (5x7 dot font: 0-9 : . % - degree), GlyphRing, GlyphSeg, GlyphLabel, GlyphTheme.
