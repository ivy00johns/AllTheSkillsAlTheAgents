---
name: nano-banana
version: 1.0.0
description: >
  Generate images using Google's Nano Banana (Gemini Image Generation) API and save them to the project. Use this skill
  whenever the user asks to generate images, create product photos, make hero banners, generate lifestyle shots, produce
  visual content, or mentions "Nano Banana", "generate an image", "we need a photo of", "create a product shot", "make
  a banner", or wants to batch-generate images. Also trigger for any AI image generation task using Gemini models, even
  if they just say "let's do images", "generate the rest", or "make me a picture of". This is the go-to skill for any
  image generation workflow.
requires_claude_code: true
---

# Nano Banana Image Generation

Generate images using Google's Gemini Image Generation API and save them directly into the project.

## How It Works

Nano Banana is Google's native image generation built into Gemini models. It accepts text prompts and returns high-quality photorealistic images. The API returns base64-encoded image data which gets decoded and saved to disk.

### Model

The bundled script uses `gemini-2.5-flash-image` — Google's current image generation model. It handles product photos, hero banners, lifestyle shots, and detail close-ups well at ~$0.04/image.

> **Note:** The script also accepts `--model flash` and `--model pro` for future model tiers as Google releases them. If those fail, fall back to `standard`.

### Supported Aspect Ratios

- **3:4** — Product cards / catalog grid (768x1024px)
- **16:9** — Hero / banner (1920x1080px)
- **1:1** — Detail / texture close-ups (1024x1024px)
- **4:5** — Lifestyle / editorial (1080x1350px)
- Also: 1:4, 1:8, 2:3, 3:2, 4:1, 4:3, 5:4, 8:1, 9:16, 21:9

## Setup

The script requires a `GEMINI_API_KEY` environment variable. It reads from the AllTheSkillsAllTheAgents root `.env` file automatically. If not set, direct the user to:

1. Get a key at https://aistudio.google.com/apikey
2. Add it to the repo root `.env` (see `.env.example` for the template)

## Generating Images

### Step 1: Identify What to Generate

When the user asks for image generation, figure out exactly what's needed:

- **Single image**: The user describes what they want. Help them refine the prompt if needed.
- **Batch of images**: If the project has a prompts document or image manifest, check it for pending items.
- **Custom image**: Help the user craft a detailed prompt (see Prompt Crafting below).

### Step 2: Find and Run the Script

The script lives alongside this SKILL.md. Locate it by searching for `nano-banana/scripts/generate_image.py`:

```bash
# Find the script path (follows symlinks)
find -L ~/.claude/skills -name "generate_image.py" -path "*/nano-banana/*" 2>/dev/null | head -1
```

Then run it:

```bash
python3 <script-path>/generate_image.py \
  --prompt "the full prompt text" \
  --output "path/to/output.png" \
  --aspect-ratio "3:4" \
  --model standard \
  --resolution 2K
```

**Parameters:**
- `--prompt` — The full prompt text (quote it carefully in the shell)
- `--output` — Where to save the file (use `.png` — the API returns PNG data)
- `--aspect-ratio` — Match the intended use (default: 3:4)
- `--model` — `standard` (default), `flash`, or `pro`
- `--resolution` — `512`, `1K`, `2K` (default), or `4K`

**For batch generation**, run images sequentially — the API has rate limits so avoid parallel calls.

### Step 3: Verify and Report

After generation:

1. **Check the file exists** and has reasonable size (images are typically 1-2MB)
2. **Let the user review** — mention the file path so they can open it
3. **Update any project tracking** if the project maintains an image manifest or prompts doc

### Step 4: Handle Issues

- **API key missing**: Guide user to https://aistudio.google.com/apikey
- **Rate limited**: Wait a moment and retry, or suggest the user try again shortly
- **Bad output**: Re-run with a tweaked prompt. Common fixes:
  - Add "Photorealistic" if output looks illustrated
  - Be more specific about lighting, materials, and setting
  - Try a different aspect ratio if composition feels off
- **Model error / timeout**: Fall back to `--model standard` which is the most reliable

## Prompt Crafting

Good prompts make the difference between generic and stunning output. When helping users write prompts:

**Structure**: Open with shot type and subject, then add material/texture details, setting, lighting, and composition notes.

**Example — Product shot:**
> Create a photorealistic editorial product photograph of a leather messenger bag laid on an aged oak table. The bag is made from full-grain vegetable-tanned leather with visible patina and hand-stitched details. Warm side lighting from a tall window casts soft directional shadows. Shot on a medium format camera with natural lighting. No AI artifacts. Photorealistic. Clean composition, suitable for e-commerce product grid.

**Example — Hero banner:**
> A dramatic wide-angle photograph of a mountain trail at golden hour. Warm amber sunlight cuts through pine trees, casting long shadows across the rocky path. Atmospheric fog in the valley below creates depth. Cinematic composition, editorial quality. Photorealistic.

**Prompt modifiers** (append as needed):
- Higher realism: "Shot on a medium format camera with natural lighting. No AI artifacts. Photorealistic."
- Product catalog: "Clean composition, suitable for e-commerce product grid."
- Style consistency: "Maintain the same [describe lighting], [describe surface], and [describe photography style]."

The key elements that improve output quality:
- **Specific materials** (full-grain leather, rough-woven wool, brushed brass) rather than generic descriptions
- **Lighting direction** (side lighting, golden hour, warm torchlight) rather than just "good lighting"
- **Setting details** that ground the image (aged oak table, stone courtyard, misty forest)
- **Photography framing** (medium format, editorial, cinematic) to set the visual quality bar
