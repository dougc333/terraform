import os
os.environ["IMAGEMAGICK_BINARY"] = "/opt/homebrew/bin/magick"

from moviepy import *
from moviepy import VideoFileClip, CompositeVideoClip
import moviepy.video.fx as vfx

import pandas as pd, json, io, matplotlib.pyplot as plt
from pygments import highlight
from pygments.lexers import PythonLexer
from pygments.formatters import ImageFormatter
from PIL import Image

VIDEO_SIZE=(1920,1080); FPS=30; FONT="Arial-Bold"

def render_code_to_image(code_str,title=""):
    img_bytes=highlight(code_str,PythonLexer(),ImageFormatter(font_size=32,line_numbers=True,style="monokai",image_pad=40))
    img=Image.open(io.BytesIO(img_bytes))
    if title:
        from PIL import ImageDraw,ImageFont
        try:font=ImageFont.truetype("arial.ttf",36)
        except:font=ImageFont.load_default()
        new=Image.new("RGB",(img.width,img.height+80),(40,40,40));new.paste(img,(0,80))
        ImageDraw.Draw(new).text((40,20),title,fill=(255,255,255),font=font);return new
    return img


def render_csv_to_image(csv_path,rows=10,title="",highlight_col=None,highlight_val=None):
    df=pd.read_csv(csv_path).head(rows);fig,ax=plt.subplots(figsize=(18,10));ax.axis('off')
    cell_colors=[['#5a1a1a' if highlight_col and highlight_val and df.iloc[i][highlight_col]==highlight_val else '#2b2b2b']*3 for i in range(len(df))]
    table=ax.table(cellText=df[['task_id','function','verdict']].values,colLabels=['Task ID','Function','Verdict'],loc='center',cellLoc='center',cellColours=cell_colors)
    table.auto_set_font_size(False);table.set_fontsize(28);table.scale(1.2,2.5)
    for j in range(3):table[(0,j)].set_facecolor('#1a1a2e');table[(0,j)].set_text_props(color='white',weight='bold')
    plt.title(title,fontsize=36,pad=20,color='white');fig.patch.set_facecolor('#0f0f1a')
    plt.savefig('temp_table.png',bbox_inches='tight',dpi=150,facecolor=fig.get_facecolor());plt.close();return 'temp_table.png'

def build_video(sb_path,output="output.mp4"):
    scenes=json.load(open(sb_path));clips=[];t=0
    for i,scene in enumerate(scenes):
        dur=scene["duration"];print(f"Scene {i+1}: {scene['type']}")
        if scene["type"]=="title":
            bg=ColorClip(VIDEO_SIZE,color=scene.get("background_color",[20,20,30])).with_duration(dur)
            txt=TextClip(text=scene["text"],font_size=scene.get("font_size",70),color='white',method='label',size=(1700,None)).with_position('center').with_duration(dur)
            clip=CompositeVideoClip([bg,txt])
        elif scene["type"]=="text":
            bg=ColorClip(VIDEO_SIZE,color=(15,15,25)).with_duration(dur)
            txt=TextClip(text=scene["text"],font_size=scene.get("font_size",60),color='white',method='label',size=(1700,None)).with_position(scene.get("position","center")).with_duration(dur)
            clip=CompositeVideoClip([bg,txt])
        elif scene["type"]=="code":
            render_code_to_image(scene["code"],scene.get("title","")).save("temp_code.png")
            code_clip=ImageClip("temp_code.png").with_duration(dur).resized(width=1600).with_position('center')
            bg=ColorClip(VIDEO_SIZE,color=(25,25,35)).with_duration(dur)
            clip=CompositeVideoClip([bg,code_clip])
        elif scene["type"]=="csv_table":
            table_img=render_csv_to_image(scene["csv"],scene.get("rows",5),scene.get("title",""),scene.get("highlight_col"),scene.get("highlight_val"))
            table_clip=ImageClip(table_img).with_duration(dur).resized(width=1700).with_position('center')
            bg=ColorClip(VIDEO_SIZE,color=(15,15,25)).with_duration(dur)
            clip=CompositeVideoClip([bg,table_clip])
        elif scene["type"]=="image":
            bg=ColorClip(VIDEO_SIZE,color=(10,10,20)).with_duration(dur)
            img=ImageClip(scene["src"]).with_duration(dur).resized(height=800).with_position('center')
            clip=CompositeVideoClip([bg,img])
        if i>0:clip=clip.with_effects([vfx.FadeIn(0.5)])
        clips.append(clip.with_start(t));t+=dur

    # Write final video once all clips are collected
    CompositeVideoClip(clips, size=VIDEO_SIZE).write_videofile(
            output,
            fps=FPS,
            codec='libx264',
            audio=False,
            preset="medium",
            ffmpeg_params=[
                "-pix_fmt", "yuv420p",
                "-movflags", "+faststart",
                "-b:v", "4000k",          # force 4 Mbps video bitrate
                "-maxrate", "4000k",      # cap it
                "-bufsize", "8000k"       # 2x bitrate buffer
            ]
        )

if __name__=="__main__":build_video("storyboard.json","mbpp_summary.mp4")
