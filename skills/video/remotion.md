---
name: remotion
description: End-to-end Remotion video production — scaffold project, write script, build scenes, generate TTS voiceover, add creative polish, render, and iterate. Use when user says '/remotion', 'create a video', 'remotion project', 'make a video', 'programmatic video', or needs to build any video with code.
---

# Remotion Video Production Pipeline

Complete end-to-end workflow for building cinematic programmatic videos with Remotion. Distilled from production iterations building multi-scene showcase videos with ElevenLabs voiceover.

## Phase 1: Plan the Video

### Gather requirements
Ask the user (or determine from context):
- **Topic**: What is the video about?
- **Duration**: Target length in seconds (default: 60-120s)
- **Audience**: Who watches this? (engineers, clients, social media)
- **Tone**: Professional, cinematic, playful, dramatic?
- **Audio**: Voiceover? Background music? Sound effects?
- **Voice**: Which ElevenLabs voice? (default: Daniel `onwK4e9ZLuTAKqWW03F9` — British broadcaster)
- **Silent scenes**: Which scenes have no narration? (e.g., CinematicIntro, Outro)

### Write `SCRIPT.md`
Create a narration script with timestamps aligned to planned scenes:

```markdown
# Video Title — Narration Script

## Act 1: Introduction (0-20s)
**[0:00 - 0:05]** Opening hook text...
**[0:05 - 0:20]** Main introduction...

## Act 2: Content (20-50s)
**[0:20 - 0:35]** Key point one...
**[0:35 - 0:50]** Key point two...

## Outro (50-60s)
**[0:50 - 0:60]** Closing statement...
```

### Design the scene list
Map script segments to scene types. Use this frame math:

```
frames = seconds × fps (default 30fps)
seconds = frames ÷ 30
```

Target 8-15 scenes for a 60-120s video. Each scene should be 5-25s.

---

## Phase 2: Scaffold the Project

### Create project
```bash
mkdir ~/Code/[your-video-project] && cd ~/Code/[your-video-project]
npm init -y
npm install remotion @remotion/cli @remotion/bundler react react-dom typescript @types/react
```

### Project structure
```
src/
  index.ts           # registerRoot(RemotionRoot)
  Root.tsx            # Composition registry
  {Name}.tsx          # Main composition (Series of scenes)
  scenes/             # One file per scene
    CinematicIntro.tsx
    TitleCard.tsx
    ...
    Outro.tsx
  components/         # Reusable overlays
    ScanLines.tsx
public/
  audio/              # Voiceover, music, SFX
  screenshots/        # Captured images (optional)
SCRIPT.md             # Narration script
```

### `src/index.ts`
```tsx
import { registerRoot } from "remotion";
import { RemotionRoot } from "./Root";
registerRoot(RemotionRoot);
```

### `src/Root.tsx`
```tsx
import React from "react";
import { Composition } from "remotion";
import { MyVideo } from "./MyVideo";

export const RemotionRoot: React.FC = () => (
  <Composition
    id="MyVideo"
    component={MyVideo}
    durationInFrames={TOTAL_FRAMES}
    fps={30}
    width={1920}
    height={1080}
  />
);
```

### Main composition pattern
```tsx
import { AbsoluteFill, Audio, Sequence, Series, staticFile } from "remotion";

export const MyVideo: React.FC = () => (
  <AbsoluteFill style={{ backgroundColor: "#0A0A0A" }}>
    {/* Voiceover — offset if there's an intro before narration starts */}
    <Sequence from={INTRO_FRAMES}>
      <Audio src={staticFile("audio/voiceover.mp3")} volume={0.9} />
    </Sequence>
    <Series>
      <Series.Sequence durationInFrames={90}><CinematicIntro /></Series.Sequence>
      <Series.Sequence durationInFrames={150}><TitleCard /></Series.Sequence>
      {/* ... more scenes ... */}
      <Series.Sequence durationInFrames={480}><Outro /></Series.Sequence>
    </Series>
    <ScanLines />
  </AbsoluteFill>
);
```

**CRITICAL**: If adding an intro scene before narration begins, wrap `<Audio>` in `<Sequence from={introFrames}>` so the voiceover syncs to the visual content, not the intro.

---

## Phase 3: Build Scenes

### Design system (default dark terminal aesthetic)
```
Background:  #0A0A0A (near-black)
Primary:     #3B82F6 (electric blue)
Success:     #10B981 (green)
Warning:     #F59E0B (amber)
Danger:      #EF4444 (red)
Text:        #E5E7EB (light gray)
Muted:       #6B7280 (gray)
Font:        'JetBrains Mono', 'Fira Code', monospace
Grid bg:     linear-gradient(#1A1A1A 1px, transparent 1px), linear-gradient(90deg, #1A1A1A 1px, transparent 1px)
             backgroundSize: 60px 60px
```

### Scene type catalog (14 proven types)

Each scene is a React component using `useCurrentFrame()`, `interpolate()`, and `spring()` from Remotion.

#### 1. CinematicIntro (3-5s)
Black screen → blinking cursor → typewriter command → screen flash.
- Green `#10B981` cursor on pure black
- `interpolate(frame, [start, end], [0, text.length])` for typewriter
- White flash overlay at the end for transition punch
- Keep short: 90-150 frames

#### 2. TitleCard (5-8s)
Large title text fading in with glow effect.
- 72-88px title, `letterSpacing: "8px"`, blue glow via textShadow
- `spring()` for subtitle appearance
- Animated divider line growing from center
- Floating particles: 20-30 SVG circles drifting upward (deterministic positions from index, NOT Math.random)

#### 3. ArchitectureDiagram (10-20s)
Animated node graph with concentric rings.
- SVG circles with `spring()` stagger per node
- 2-3 rings at increasing radii (r1=180, r2=290, r3=380)
- Lines drawing from center to nodes via `interpolate(frame, range, [0, 1])` progress
- `displayNames` map for abbreviated labels
- **Gotcha**: Keep radii within viewport (max ring radius < height/2 - 100)

#### 4. FailureWall (15-20s)
Grid of items with animated failure/success stamps.
- CSS Grid layout (`gridTemplateColumns: repeat(N, 1fr)`)
- Red `✕` stamps appear via `spring()` with shake effect
- Camera shake: wrap content in div with `transform: translate(shakeX, shakeY)` using `sin(frame * freq) * intensity * (1 - progress)`
- Red vignette: `radial-gradient(ellipse, transparent 30%, rgba(239,68,68,intensity) 100%)`
- Survivors float upward + green glow

#### 5. BacktestResults (10-15s)
Horizontal bar chart with animated growth.
- SVG `<rect>` bars growing via `spring()` for width
- Breakeven line at a threshold value
- Status badges (LIVE/KILLED/FAILED) appearing after bars
- Bars sorted by value (highest first)

#### 6. CodeRain (8-12s)
Matrix-style falling code snippets.
- 6-8 SVG text columns at different X positions
- Each column scrolls at its own speed (parallax)
- `offsetY = ((frame * speed) % totalHeight) - totalHeight` with double-render for seamless loop
- Dark radial gradient in center so overlay text is readable
- Center: large dramatic stat text (e.g., "52,000 LINES")

#### 7. StatsTicker (8-12s)
Count-up numbers with animated progress bars.
- `Math.round(target * interpolate(frame, range, [0, 1]))` for counters
- Each stat slides in from left with stagger
- Progress bar fills below each stat
- Numbers: 72px bold with color + textShadow glow

#### 8. ChatDemo (15-20s)
Chat interface mockup with typing indicators.
- Dark chat window with rounded bubbles
- User messages (right-aligned) and bot responses (left-aligned)
- Typing indicator: 3 dots with `sin()` opacity cycle
- Side annotation panel showing context or commands
- **Fix pattern**: If chat window + side panel overlap, shrink chat width and add `marginRight`

#### 9. TerminalLogs (15-25s)
Scrolling terminal output with typewriter effect.
- macOS window chrome (3 colored dots + title bar)
- Per-line typewriter: `msg.slice(0, Math.round(charProgress))`
- Lines appear sequentially: `startFrame = i * FRAMES_PER_LINE`
- Blinking cursor at bottom
- Summary stat row below terminal
- **Gotcha**: Title at `top: 16-28` can overlap terminal. Use `fontSize: 48` or smaller for scene titles above tall terminals.

#### 10. LiveScreenshots (12-20s)
Cycling panels showing real data.
- `panelIndex = Math.floor(frame / FRAMES_PER_PANEL)`
- Crossfade between panels: `interpolate(panelFrame, [0, 15, end-12, end], [0, 1, 1, 0])`
- Ken Burns: `transform: scale(interpolate(panelFrame, [0, end], [1.0, 1.04]))`
- Indicator dots at bottom showing active panel
- **Gotcha**: Empty strings in data cause `interpolate()` crash — guard: `Math.max(text.length, 1)`

#### 11. GrowthTimeline (15-20s)
Horizontal milestone timeline.
- SVG line drawing left→right via `interpolate(frame, range, [0, 1]) * width`
- Milestone nodes appear via `spring()` when line reaches their position
- Alternating above/below labels (isAbove = i % 2 === 0)
- Pulsing glow on final node
- **Gotcha**: Computationally expensive — needs `--timeout=60000` on render

#### 12. DataFlow (10-15s)
Pipeline boxes with animated arrows between them.
- SVG boxes with labels + sublabels
- Arrows grow between boxes with `interpolate()` progress
- Animated dots travel along arrows after they're drawn
- Log section below pipeline

#### 13. Outro (10-16s)
Text reveal with dramatic counter effect.
- Counter 0→N rapidly counting (frames 0-25), then "explodes" (scale 2x + fade)
- Main text fades in after counter
- `spring()` for text scale-up
- Divider line growing from center
- `fadeToBlack` overlay on final 45 frames

#### 14. ScanLines (component overlay)
Subtle CRT scan-line effect across all scenes.
```tsx
// src/components/ScanLines.tsx
const offsetY = (frame * 2.5) % 4;
<div style={{
  position: "absolute", inset: 0, pointerEvents: "none",
  backgroundImage: "repeating-linear-gradient(0deg, transparent, transparent 2px, rgba(0,0,0,0.22) 2px, rgba(0,0,0,0.22) 4px)",
  backgroundSize: "100% 4px", backgroundPositionY: `${offsetY}px`,
  opacity: 0.025, zIndex: 9999,
}} />
```

### Common animation patterns
```tsx
// Fade in
const opacity = interpolate(frame, [start, start + 20], [0, 1], { extrapolateRight: "clamp" });

// Slide up
const y = interpolate(frame, [start, start + 20], [30, 0], { extrapolateRight: "clamp" });

// Spring pop-in
const scale = spring({ frame: frame - start, fps, config: { damping: 14, stiffness: 120 } });

// Count up
const count = Math.round(interpolate(frame, [start, end], [0, target], { extrapolateRight: "clamp" }));

// Typewriter
const chars = Math.round(interpolate(frame, [start, start + text.length * 0.5], [0, text.length], { extrapolateRight: "clamp" }));
const displayed = text.slice(0, chars);

// Glow pulse
const glow = interpolate(Math.sin((frame / fps) * Math.PI * 1.2), [-1, 1], [0.5, 1.0]);
```

---

## Phase 4: Voiceover (ElevenLabs TTS Pipeline)

Voiceover is generated from SCRIPT.md using the ElevenLabs Python SDK. This is a critical sync step — the audio duration determines the video's total frame count.

### Voice Registry

Always use the **voice ID** (not the display name) when calling the generate script. Using the name causes a 404 error.

| Name    | Voice ID                  | Style                        | Best For                   |
|---------|---------------------------|------------------------------|----------------------------|
| Daniel  | `onwK4e9ZLuTAKqWW03F9`   | British broadcaster          | Professional, authoritative|
| George  | `JBFqnCBsd6RMkjVDRZzb`   | British storyteller          | Warm, narrative            |
| Rachel  | `21m00Tcm4TlvDq8ikWAM`   | American professional female | Client-facing, friendly    |

### Step 1: Write the Script with Silent Markers

In SCRIPT.md, mark scenes that have no narration with `**[No voiceover]**`. The generate script strips all markdown formatting, headers, and timestamp markers — only the narration text becomes speech.

```markdown
## Intro (0:00 - 0:03)
**[No voiceover — keystrokes only]**

## Title (0:03 - 0:08)
**[0:03 - 0:08]**
This is the narration text that will be spoken.

## Outro (1:40 - 1:45)
**[No voiceover — logo and silence]**
```

### Step 2: Generate the Voiceover

```bash
ELEVENLABS_API_KEY=<key> python3 generate.py \
  --file SCRIPT.md \
  --output public/audio/voiceover.mp3 \
  --voice "onwK4e9ZLuTAKqWW03F9" \
  --model "eleven_multilingual_v2"
```

After generation, verify the file is not empty:
```bash
ls -la public/audio/voiceover.mp3  # Should be >10KB — 0 bytes means quota exhausted
```

### Step 3: Measure Duration and Auto-Sync

```bash
ffprobe -i public/audio/voiceover.mp3 -show_entries format=duration -v quiet -of csv="p=0"
```

Calculate the video's total frame count:
```
silentIntroFrames = sum of durationInFrames for all scenes before narration starts
audioDurationFrames = Math.ceil(audioDurationSeconds * fps)
paddingFrames = 90-180 (for fade-to-black at end)
totalFrames = silentIntroFrames + audioDurationFrames + paddingFrames
```

Then:
1. Update `durationInFrames` in `Root.tsx` to match `totalFrames`
2. Wrap `<Audio>` in `<Sequence from={silentIntroFrames}>` so the voiceover starts after any silent intro
3. Ensure the last scene's fade-to-black fits within `paddingFrames`

### Step 4: Timing Verification

Before rendering, verify these invariants:
- Audio duration ≤ (totalFrames - silentIntroFrames - paddingFrames) / fps
- Audio ends ≥ 2 seconds before video ends (room for fade-to-black)
- Silent scenes (`[No voiceover]`) don't have narration text leaking into them
- The `<Sequence from={N}>` offset matches the actual silent intro duration

---

## Phase 5: Creative Polish

Apply after scenes are working but before final render:
- **ScanLines**: Add `<ScanLines />` as last child in main AbsoluteFill
- **Particles**: Deterministic floating dots in TitleCard (seed from index, not Math.random)
- **Camera shake**: Impact scenes — `sin(frame * freq) * intensity * decay`
- **Counter explosion**: Outro dramatic count-up → explosion → text reveal
- **Ken Burns**: Subtle zoom `scale(1.0 → 1.04)` on screenshot/image panels

---

## Phase 6: Render & QA

### Render
```bash
cd ~/Code/[your-video-project] && npx remotion render {CompositionId} out/video.mp4 --timeout=60000
```

### Visual QA via stills
Render frames at scene midpoints and inspect with Read tool:
```bash
npx remotion still {CompositionId} --frame={N} out/frame-{N}.png --timeout=60000
```

Check each frame for:
1. Text overlaps or clipping
2. Readability (font size ≥ 28px, high contrast)
3. Animation correctness
4. Empty space / balance
5. Voiceover alignment with visual content

### Fix loop
Edit scene TSX → re-render → re-check stills → repeat until clean. Use `/video-iterate` skill for structured iteration.

---

## Gotchas & Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Render timeout | Complex scene (many springs) | `--timeout=60000` |
| `inputRange must be strictly monotonically increasing` | `interpolate()` with zero-length range | Guard: `Math.max(value, 1)` |
| Audio plays during intro | Audio not offset | `<Sequence from={introFrames}><Audio /></Sequence>` |
| Text overlap | Element positioned too close to neighbor | Reduce fontSize, increase top/padding, shrink container |
| Side panel overlaps main content | Container too wide | Shrink main content, add marginRight |
| Frame 0 is blank | Animations start at frame 0 with opacity 0 | Normal — first visible frame is ~frame 15-30 |
| `registerRoot` missing | index.ts only exports, doesn't register | Add `registerRoot(RemotionRoot)` |
| Memory crash on render | Too many concurrent workers | `--concurrency=1` |
| Voice not found (404) | Using voice name instead of voice ID | Always use voice ID from the Voice Registry |
| Empty/0-byte MP3 | ElevenLabs API quota exhausted or bad key | Delete the 0-byte file, get fresh key, regenerate |
| Audio too long for video | Script narration exceeds scene durations | Trim script text, increase scene frames, or pick a faster voice |
| Audio desync after intro | Audio not offset for silent intro scenes | `<Sequence from={introFrames}><Audio /></Sequence>` |
