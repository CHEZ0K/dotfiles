#!/usr/bin/env python3
import os, glob, json, subprocess

prev_dir = os.path.expanduser('~/.cache/hypr/wallpaper_previews')
color_dir = os.path.join(prev_dir, 'colors_markers')
map_file = os.path.expanduser('~/.cache/hypr/wpe_map.txt')

we_common = os.path.expanduser('~/.local/share/Steam/steamapps/common/wallpaper_engine')
we_default = os.path.join(we_common, 'projects/defaultprojects')
we_workshop = os.path.expanduser('~/.local/share/Steam/steamapps/workshop/content/431960')

os.makedirs(prev_dir, exist_ok=True)
os.makedirs(color_dir, exist_ok=True)

# Known broken legacy default projects that crash linux-wallpaperengine due to obsolete 2016 format
broken_default = {'arsenal', 'demon_core', 'fantasticcar', 'neon_sunset', 'ricepod', 'dna_fragment', 'sheep', 'techno', 'audiophile', 'corsair_collection', 'corsair_o_tron'}

projects = []
if os.path.exists(we_default):
    for p in sorted(os.listdir(we_default)):
        d = os.path.join(we_default, p)
        if os.path.isdir(d) and p not in broken_default and os.path.exists(os.path.join(d, 'project.json')):
            projects.append(d)

if os.path.exists(we_workshop):
    for p in sorted(os.listdir(we_workshop)):
        d = os.path.join(we_workshop, p)
        if os.path.isdir(d) and os.path.exists(os.path.join(d, 'project.json')):
            projects.append(d)

valid_wpe = []

for proj in projects:
    pjson_path = os.path.join(proj, 'project.json')
    pdata = {}
    try:
        with open(pjson_path, 'r', encoding='utf-8', errors='ignore') as f:
            pdata = json.load(f)
    except Exception:
        continue
        
    title = pdata.get('title', os.path.basename(proj))
    ptype = str(pdata.get('type', '')).lower()
    
    videos = glob.glob(os.path.join(proj, '*.mp4')) + glob.glob(os.path.join(proj, '*.webm')) + glob.glob(os.path.join(proj, '*.mkv'))
    previews = glob.glob(os.path.join(proj, 'preview.*'))
    if not previews:
        continue
    orig_prev = previews[0]
    pname = os.path.basename(proj)
    thumb_name = f'WPE_{pname}.jpg'
    
    # 1. Direct video project
    if ptype == 'video' or (videos and ptype != 'scene'):
        vid_file = videos[0] if videos else os.path.join(proj, pdata.get('file', ''))
        if os.path.exists(vid_file):
            valid_wpe.append((thumb_name, proj, orig_prev, 'video', vid_file, title))
            continue
            
    # 2. 3D Scene project
    scene_file = os.path.join(proj, pdata.get('file', 'scene.json'))
    scene_pkg = os.path.join(proj, 'scene.pkg')
    if os.path.exists(scene_file) or os.path.exists(scene_pkg) or ptype == 'scene':
        valid_wpe.append((thumb_name, proj, orig_prev, 'scene', proj, title))
    elif videos:
        valid_wpe.append((thumb_name, proj, orig_prev, 'video', videos[0], title))

# Generate previews and color markers
valid_thumbs = set()
with open(map_file, 'w') as mf:
    for thumb_name, proj_dir, orig_prev, kind, target_path, title in valid_wpe:
        valid_thumbs.add(thumb_name)
        mf.write(f'{thumb_name}|{proj_dir}|{orig_prev}|{kind}|{target_path}|{title}\n')
        
        thumb_path = os.path.join(prev_dir, thumb_name)
        if not os.path.exists(thumb_path):
            subprocess.run(['magick', f'{orig_prev}[0]', '-filter', 'Lanczos', '-resize', 'x720', '-quality', '95', thumb_path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
        if os.path.exists(thumb_path):
            marker_pattern = os.path.join(color_dir, f'{thumb_name}_HEX_*')
            if not glob.glob(marker_pattern):
                try:
                    res = subprocess.run(
                        ['magick', thumb_path, '-modulate', '100,200', '-resize', '1x1^', '-gravity', 'center', '-extent', '1x1', '-depth', '8', '-format', '%[hex:p{0,0}]', 'info:-'],
                        capture_output=True, text=True
                    )
                    hex_val = res.stdout.strip()[:6]
                    if hex_val:
                        open(os.path.join(color_dir, f'{thumb_name}_HEX_{hex_val}'), 'w').close()
                except Exception:
                    pass

# Cleanup any broken legacy project thumbnails
for f in os.listdir(prev_dir):
    if f.startswith('WPE_') and f.endswith('.jpg') and f not in valid_thumbs:
        try:
            os.remove(os.path.join(prev_dir, f))
            for m in glob.glob(os.path.join(color_dir, f'{f}_HEX_*')):
                os.remove(m)
        except Exception:
            pass

print(f'WPE Sync done: {len(valid_wpe)} valid projects ready.')
