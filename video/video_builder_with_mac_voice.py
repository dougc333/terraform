#!/usr/bin/env python3
"""Render a storyboard and narrate every scene with OpenAI text-to-speech.

Set OPENAI_API_KEY, then run this script from the video project directory:
  python3 video_builder_with_mac_voice.py storyboard.json narrated_video.mp4
"""

import argparse
import io
import json
import os
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen

os.environ["IMAGEMAGICK_BINARY"] = "/opt/homebrew/bin/magick"

import matplotlib.pyplot as plt
import moviepy.video.fx as vfx
import pandas as pd
from moviepy import AudioFileClip, ColorClip, CompositeVideoClip, ImageClip, TextClip
from PIL import Image, ImageDraw, ImageFont
from pygments import highlight
from pygments.formatters import ImageFormatter
from pygments.lexers import PythonLexer

VIDEO_SIZE = (1920, 1080)
FPS = 30


def render_code_to_image(code, title=""):
    image_bytes = highlight(
        code,
        PythonLexer(),
        ImageFormatter(font_size=32, line_numbers=True, style="monokai", image_pad=40),
    )
    image = Image.open(io.BytesIO(image_bytes)).convert("RGB")
    if not title:
        return image

    try:
        font = ImageFont.truetype("arial.ttf", 36)
    except OSError:
        font = ImageFont.load_default()
    titled = Image.new("RGB", (image.width, image.height + 80), (40, 40, 40))
    titled.paste(image, (0, 80))
    ImageDraw.Draw(titled).text((40, 20), title, fill="white", font=font)
    return titled


def render_csv_to_image(csv_path, rows=10, title="", highlight_col=None, highlight_val=None):
    dataframe = pd.read_csv(csv_path).head(rows)
    figure, axis = plt.subplots(figsize=(18, 10))
    axis.axis("off")
    colors = [
        [
            "#5a1a1a"
            if highlight_col and highlight_val and row[highlight_col] == highlight_val
            else "#2b2b2b"
        ] * 3
        for _, row in dataframe.iterrows()
    ]
    table = axis.table(
        cellText=dataframe[["task_id", "function", "verdict"]].values,
        colLabels=["Task ID", "Function", "Verdict"],
        loc="center",
        cellLoc="center",
        cellColours=colors,
    )
    table.auto_set_font_size(False)
    table.set_fontsize(28)
    table.scale(1.2, 2.5)
    for column in range(3):
        table[(0, column)].set_facecolor("#1a1a2e")
        table[(0, column)].set_text_props(color="white", weight="bold")
    plt.title(title, fontsize=36, pad=20, color="white")
    figure.patch.set_facecolor("#0f0f1a")
    output = csv_path.parent / "temp_table.png"
    plt.savefig(output, bbox_inches="tight", dpi=150, facecolor=figure.get_facecolor())
    plt.close()
    return output


def narration_for(scene):
    """Use the authored script, then a sensible fallback for every other scene."""
    authored = scene.get("voiceover", "").strip()
    if authored:
        return authored.replace("\\n", ". ")
    if scene["type"] in {"text", "title"}:
        return scene.get("text", "")
    if scene["type"] == "code":
        return scene.get("title", "Here is the code for this example.")
    if scene["type"] == "csv_table":
        return scene.get("title", "Here is the summary table.")
    return "Here is the next example."


def make_audio(text, destination, voice, instructions, api_key):
    payload = json.dumps(
        {
            "model": "gpt-4o-mini-tts",
            "voice": voice,
            "input": text,
            "instructions": instructions,
            "response_format": "mp3",
        }
    ).encode("utf-8")
    request = Request(
        "https://api.openai.com/v1/audio/speech",
        data=payload,
        headers={
            "Authorization": f"Bearer {api_key}",
            "Content-Type": "application/json",
        },
        method="POST",
    )
    try:
        with urlopen(request) as response, destination.open("wb") as audio_file:
            audio_file.write(response.read())
    except HTTPError as error:
        raise RuntimeError(error.read().decode("utf-8", errors="replace")) from error
    if not destination.exists() or destination.stat().st_size < 8_000:
        raise RuntimeError(f"OpenAI did not generate usable audio: {destination}")


def visual_clip(scene, duration, base_dir, index):
    kind = scene["type"]
    background = ColorClip(VIDEO_SIZE, color=scene.get("background_color", [15, 15, 25])).with_duration(duration)
    if kind in {"title", "text"}:
        text = TextClip(
            text=scene["text"],
            font_size=scene.get("font_size", 60),
            color="white",
            method="label",
            size=(1700, None),
        ).with_position(scene.get("position", "center")).with_duration(duration)
        return CompositeVideoClip([background, text])
    if kind == "image":
        image = ImageClip(base_dir / scene["src"]).with_duration(duration).resized(height=800).with_position("center")
        return CompositeVideoClip([background, image])
    if kind == "code":
        path = base_dir / f"temp_code_{index:02d}.png"
        render_code_to_image(scene["code"], scene.get("title", "")).save(path)
        code = ImageClip(path).with_duration(duration).resized(width=1600).with_position("center")
        return CompositeVideoClip([background, code])
    if kind == "csv_table":
        table_path = render_csv_to_image(
            base_dir / scene["csv"],
            scene.get("rows", 5),
            scene.get("title", ""),
            scene.get("highlight_col"),
            scene.get("highlight_val"),
        )
        table = ImageClip(table_path).with_duration(duration).resized(width=1700).with_position("center")
        return CompositeVideoClip([background, table])
    raise ValueError(f"Unsupported scene type: {kind}")


def build(storyboard_path, output_path, voice, instructions):
    storyboard_path = Path(storyboard_path).resolve()
    base_dir = storyboard_path.parent
    api_key = os.environ.get("OPENAI_API_KEY")
    if not api_key:
        raise RuntimeError("Set OPENAI_API_KEY before running this script.")
    scenes = json.loads(storyboard_path.read_text())
    audio_dir = base_dir / "voiceover_audio"
    audio_dir.mkdir(exist_ok=True)

    clips = []
    start = 0.0
    for index, scene in enumerate(scenes, start=1):
        narration = narration_for(scene)
        audio_path = audio_dir / f"scene_{index:02d}.mp3"
        make_audio(narration, audio_path, voice, instructions, api_key)
        audio = AudioFileClip(audio_path)
        duration = max(float(scene["duration"]), audio.duration + 0.4)
        clip = visual_clip(scene, duration, base_dir, index).with_audio(audio)
        if index > 1:
            clip = clip.with_effects([vfx.FadeIn(0.5)])
        clips.append(clip.with_start(start))
        start += duration

    final = CompositeVideoClip(clips, size=VIDEO_SIZE).with_duration(start)
    final.write_videofile(str(output_path), fps=FPS, codec="libx264", audio_codec="aac")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("storyboard", nargs="?", default="storyboard.json")
    parser.add_argument("output", nargs="?", default="narrated_video.mp4")
    parser.add_argument("--voice", default="marin")
    parser.add_argument(
        "--instructions",
        default="Speak clearly and confidently in a calm technical presentation style.",
    )
    args = parser.parse_args()
    build(args.storyboard, args.output, args.voice, args.instructions)
