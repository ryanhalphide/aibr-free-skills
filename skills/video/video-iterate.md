---
name: video-iterate
description: Iterative refinement loop for Remotion video projects — renders, previews key frames, identifies visual issues, fixes them, regenerates voiceover if script changed, and re-renders. Works with ANY Remotion project (auto-detects from CWD or arguments). Use when user says '/video-iterate', 'iterate video', 'refine video', 'improve video', 'fix video', 'polish video', 'video QA', or needs to debug/polish any Remotion composition.
---

# Video Iterate Skill

Iterative render-preview-fix loop for **any** Remotion video project. Auto-detects project context from the current working directory or user-provided arguments. Includes integrated voiceover generation and timing sync verification.

## Step 0: Detect Project Context

Before anything else, establish which Remotion project you're working with.

1. Check `ARGUMENTS` for a project path, name, or specific instructions
2. If none provided, detect from CWD:
   - Look for `package.json` with `remotion` in dependencies
   - If not found, check `~/Code/` subdirectories for Remotion projects
3. Read the project to extract:
   - **CompositionId**: from `src/Root.tsx` — the `id` prop on `<Composition>`
   - **durationInFrames** and **fps**: from the same `<Composition>`
   - **Main composition file**: the component imported into Root
   - **Scene list**: parse `<Series.Sequence durationInFrames={N}>` entries to build a timing table
   - **SCRIPT.md**: read narration content and identify `[No voiceover]` scenes
   - **Audio status**: check if `public/audio/voiceover.mp3` exists and its duration via `ffprobe`

Output a context summary before proceeding:
```
Project: ~/Code/{name}/
Composition: {CompositionId} ({durationInFrames} frames, {fps}fps, {seconds}s)
Scenes: {count} scenes
Audio: {exists ? duration + "s" : "MISSING"}
```

## Step 1: Read Current State

Read `SCRIPT.md` and the scene files relevant to the current iteration focus.

Build the **scene timing table** from the main composition:

| # | Scene | Frames | Start Frame | Mid Frame | Duration |
|---|-------|--------|-------------|-----------|----------|

This table drives which frames to preview in Step 3.

## Step 2: Render the Video

```bash
cd {projectDir} && npx remotion render {CompositionId} out/{output}.mp4 --timeout=60000
```

If rendering fails, check:
1. Missing imports or TypeScript errors in scene files
2. Missing static assets in `public/` (especially `audio/voiceover.mp3`)
3. Memory issues — reduce concurrency: `--concurrency=1`
4. `interpolate()` errors — guard empty strings: `Math.max(text.length, 1)`

If the audio file is missing, create a silent placeholder first:
```bash
ffmpeg -f lavfi -i anullsrc=r=44100:cl=mono -t {durationSeconds} -q:a 9 -acodec libmp3lame public/audio/voiceover.mp3 -y
```

## Step 3: Preview Key Frames

Auto-calculate preview frames from the scene timing table — use the **midpoint** of each scene.

```bash
cd {projectDir} && npx remotion still {CompositionId} --frame={midFrame} out/frame-{midFrame}.png --timeout=60000
```

Render stills for all scenes in parallel (multiple Bash calls). Then read each PNG with the Read tool to visually inspect.

## Step 4: Analyze Each Frame

For every screenshot, evaluate:

1. **Text overlaps** — Are any text elements overlapping or clipped by the viewport?
2. **Readability** — Is text large enough (≥28px), high-contrast against background?
3. **Visual quality** — Are animations mid-transition? Do charts/diagrams render correctly?
4. **Empty space** — Is the frame balanced, or are there large unused areas?
5. **Timing alignment** — Does the visual content match what the voiceover is saying at that timestamp? Cross-reference `SCRIPT.md`.

Document all findings before making changes.

## Step 5: Fix Issues

Edit scene `.tsx` files in `src/scenes/` to address identified problems. Common fixes:

- **Text overlap**: Adjust `fontSize`, `lineHeight`, `padding`, or container `maxWidth`
- **Readability**: Increase font size, add text shadow or background overlay
- **Empty space**: Adjust layout, add visual elements, increase content density
- **Timing mismatch**: Adjust frame counts in the main composition or reorder content within a scene
- **Animation glitches**: Check `interpolate()` ranges, spring configs, `useCurrentFrame()` usage
- **Grid/list cut off**: Reduce cell padding/gap, adjust vertical centering transform

Preserve the project's design system tokens (colors, fonts, grid style).

## Step 6: Voiceover Sync Check

This step runs on **every iteration**, not just when the script changes.

### If SCRIPT.md was modified this iteration:

1. **Regenerate the voiceover**:
```bash
ELEVENLABS_API_KEY={key} python3 generate.py \
  --file {projectDir}/SCRIPT.md \
  --output {projectDir}/public/audio/voiceover.mp3 \
  --voice "{voiceId}" \
  --model "eleven_multilingual_v2"
```

Voice ID reference (always use the ID, not the name):
| Name    | Voice ID                  | Style                    |
|---------|---------------------------|--------------------------|
| Daniel  | `onwK4e9ZLuTAKqWW03F9`   | British broadcaster      |
| George  | `JBFqnCBsd6RMkjVDRZzb`   | British storyteller      |
| Rachel  | `21m00Tcm4TlvDq8ikWAM`   | American professional    |

2. **Measure new duration**:
```bash
ffprobe -i {projectDir}/public/audio/voiceover.mp3 -show_entries format=duration -v quiet -of csv="p=0"
```

3. **Update composition if needed**: If audio duration changed significantly (>3s difference), recalculate `durationInFrames` in `Root.tsx`:
```
silentIntroFrames + Math.ceil(audioDuration * fps) + paddingFrames (90-180)
```

### Always verify (even if script didn't change):

- Audio duration vs composition duration: audio should end ≥2s before video ends
- Audio `<Sequence from={N}>` offset matches the sum of silent intro scene frames
- No 0-byte audio files (quota exhaustion leaves empty files — delete and regenerate)
- Cross-reference SCRIPT.md timestamps with scene midpoints for alignment

## Step 7: Re-render and Verify

```bash
cd {projectDir} && npx remotion render {CompositionId} out/{output}.mp4 --timeout=60000
```

Re-capture only the frames that had issues to confirm fixes. If new issues appear, loop back to Step 4.

Open the final video for user review:
```bash
open {projectDir}/out/{output}.mp4
```

## Quick Commands

```bash
# Full render
cd {projectDir} && npx remotion render {CompositionId} out/{output}.mp4 --timeout=60000

# Single frame preview
cd {projectDir} && npx remotion still {CompositionId} --frame={N} out/frame-{N}.png --timeout=60000

# Start Remotion Studio for live preview
cd {projectDir} && npx remotion studio

# Low-memory render
cd {projectDir} && npx remotion render {CompositionId} out/{output}.mp4 --timeout=60000 --concurrency=1

# Check audio duration
ffprobe -i {projectDir}/public/audio/voiceover.mp3 -show_entries format=duration -v quiet -of csv="p=0"

# Regenerate voiceover
ELEVENLABS_API_KEY={key} python3 generate.py \
  --file {projectDir}/SCRIPT.md --output {projectDir}/public/audio/voiceover.mp3 \
  --voice "onwK4e9ZLuTAKqWW03F9" --model "eleven_multilingual_v2"
```

## Checklist Per Iteration

- [ ] Detect project context (composition, scenes, audio)
- [ ] Read SCRIPT.md and relevant scene files
- [ ] Render video successfully (exit code 0)
- [ ] Capture and review key frames at scene midpoints
- [ ] Document all visual issues found
- [ ] Fix issues in scene TSX files
- [ ] Voiceover sync check (regen if script changed, verify timing always)
- [ ] Re-render and verify fixes
- [ ] Open final video for user review
- [ ] Final render clean with no regressions
