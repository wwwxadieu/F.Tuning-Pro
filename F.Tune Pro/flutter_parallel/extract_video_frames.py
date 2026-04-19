from pathlib import Path
import json
import imageio.v2 as imageio
from PIL import Image

video = Path(r"C:\Users\MrBeoHP\Downloads\Phone Link\ssstwitter.com_1776537600471.mp4")
out_dir = Path(r"C:\Users\MrBeoHP\Desktop\My project\F.Tune Pro\code-review\video-frames")
out_dir.mkdir(parents=True, exist_ok=True)
reader = imageio.get_reader(str(video))
meta = reader.get_meta_data()
size = meta.get('size') or meta.get('source_size')
fps = float(meta.get('fps'))
duration = float(meta.get('duration'))
percentages = [10, 35, 65, 90]
results = []
for pct in percentages:
    t = duration * pct / 100.0
    frame_index = max(0, int(round(t * fps)))
    frame = reader.get_data(frame_index)
    img = Image.fromarray(frame)
    path = out_dir / f"frame_{pct:02d}pct.png"
    img.save(path)
    results.append({"percent": pct, "time_sec": round(t, 3), "frame_index": frame_index, "path": str(path)})
reader.close()
print(json.dumps({
    "duration_sec": duration,
    "resolution": {"width": size[0], "height": size[1]},
    "frames": results
}, indent=2))
