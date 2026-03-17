#!/usr/bin/env python3
"""
Generate an image using Google's Nano Banana (Gemini Image Generation) API.

Usage:
    python generate_image.py --prompt "your prompt" --output path/to/output.jpg [--aspect-ratio 3:4] [--model pro] [--resolution 2K]

Environment:
    GEMINI_API_KEY - Required. Your Google AI Studio API key.
"""

import argparse
import base64
import json
import os
import pathlib
import sys
import urllib.request
import urllib.error

# Load .env from the skill directory (sibling to scripts/)
_SKILL_DIR = pathlib.Path(__file__).resolve().parent.parent
_ENV_FILE = _SKILL_DIR / ".env"
if _ENV_FILE.exists():
    for line in _ENV_FILE.read_text().splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            key, _, value = line.partition("=")
            key = key.strip()
            value = value.strip().strip("\"'")
            if key and key not in os.environ:
                os.environ[key] = value

MODELS = {
    "standard": "gemini-2.5-flash-image",
    # Flash and Pro model IDs are placeholders for future Google releases.
    # As of 2026-03, only "standard" is confirmed working.
    "flash": "gemini-2.5-flash-image",  # fallback to standard until a faster tier ships
    "pro": "gemini-2.5-flash-image",    # fallback to standard until a pro tier ships
}

VALID_ASPECT_RATIOS = [
    "1:1", "1:4", "1:8", "2:3", "3:2", "3:4",
    "4:1", "4:3", "4:5", "5:4", "8:1", "9:16", "16:9", "21:9",
]

VALID_RESOLUTIONS = ["512", "1K", "2K", "4K"]


def generate_image(prompt: str, output_path: str, aspect_ratio: str = "3:4",
                   model_key: str = "standard", resolution: str = "2K") -> dict:
    """Call Nano Banana API and save the resulting image."""

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("Error: GEMINI_API_KEY environment variable is not set.", file=sys.stderr)
        print("Get a key at https://aistudio.google.com/apikey", file=sys.stderr)
        sys.exit(1)

    model_id = MODELS.get(model_key, model_key)
    if aspect_ratio not in VALID_ASPECT_RATIOS:
        print(f"Warning: '{aspect_ratio}' may not be supported. Valid: {VALID_ASPECT_RATIOS}", file=sys.stderr)

    url = f"https://generativelanguage.googleapis.com/v1beta/models/{model_id}:generateContent"

    payload = {
        "contents": [
            {
                "parts": [
                    {"text": prompt}
                ]
            }
        ],
        "generationConfig": {
            "responseModalities": ["TEXT", "IMAGE"],
            "imageConfig": {
                "aspectRatio": aspect_ratio,
            }
        }
    }

    if resolution != "2K":
        payload["generationConfig"]["imageConfig"]["resolution"] = resolution

    body = json.dumps(payload).encode("utf-8")

    req = urllib.request.Request(
        f"{url}?key={api_key}",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )

    print(f"Generating image with {model_id}...")
    print(f"  Aspect ratio: {aspect_ratio}")
    print(f"  Resolution: {resolution}")
    print(f"  Output: {output_path}")

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            result = json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if e.fp else "No details"
        print(f"API Error {e.code}: {error_body}", file=sys.stderr)
        sys.exit(1)
    except urllib.error.URLError as e:
        print(f"Network error: {e.reason}", file=sys.stderr)
        sys.exit(1)

    # Extract image from response
    candidates = result.get("candidates", [])
    if not candidates:
        print("Error: No candidates in response.", file=sys.stderr)
        print(json.dumps(result, indent=2), file=sys.stderr)
        sys.exit(1)

    image_data = None
    text_response = None

    for candidate in candidates:
        content = candidate.get("content", {})
        for part in content.get("parts", []):
            if "inlineData" in part:
                image_data = part["inlineData"]
            elif "text" in part:
                text_response = part["text"]

    if not image_data:
        print("Error: No image data in response.", file=sys.stderr)
        if text_response:
            print(f"Model response: {text_response}", file=sys.stderr)
        print(json.dumps(result, indent=2)[:2000], file=sys.stderr)
        sys.exit(1)

    # Decode and save
    raw = base64.b64decode(image_data["data"])
    mime = image_data.get("mimeType", "image/png")

    # Adjust file extension to match actual mime type (API returns PNG)
    ext_map = {"image/png": ".png", "image/jpeg": ".jpg", "image/webp": ".webp"}
    actual_ext = ext_map.get(mime, ".png")
    out = pathlib.Path(output_path)
    if out.suffix.lower() in (".jpg", ".jpeg", ".png", ".webp") and out.suffix.lower() != actual_ext:
        output_path = str(out.with_suffix(actual_ext))
        print(f"  Note: API returned {mime}, saving as {actual_ext} instead of {out.suffix}")

    os.makedirs(os.path.dirname(os.path.abspath(output_path)), exist_ok=True)

    with open(output_path, "wb") as f:
        f.write(raw)

    size_kb = len(raw) / 1024
    print(f"Saved {size_kb:.0f}KB image ({mime}) to {output_path}")

    if text_response:
        print(f"Model note: {text_response}")

    return {
        "output_path": output_path,
        "size_bytes": len(raw),
        "mime_type": mime,
        "model": model_id,
        "text_response": text_response,
    }


def main():
    parser = argparse.ArgumentParser(description="Generate images with Nano Banana (Gemini Image API)")
    parser.add_argument("--prompt", required=True, help="The image generation prompt")
    parser.add_argument("--output", required=True, help="Output file path (e.g., public/images/products/monk.jpg)")
    parser.add_argument("--aspect-ratio", default="3:4", help=f"Aspect ratio. Valid: {VALID_ASPECT_RATIOS}")
    parser.add_argument("--model", default="standard", choices=list(MODELS.keys()),
                        help="Model tier: standard (2.5 Flash), flash (3.1 Flash), pro (3 Pro)")
    parser.add_argument("--resolution", default="2K", choices=VALID_RESOLUTIONS, help="Output resolution")

    args = parser.parse_args()
    generate_image(args.prompt, args.output, args.aspect_ratio, args.model, args.resolution)


if __name__ == "__main__":
    main()
