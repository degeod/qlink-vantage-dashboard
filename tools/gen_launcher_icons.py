from PIL import Image
from pathlib import Path

src = Path(
    r"C:\Users\User\.cursor\projects\c-Users-User-Documents-Codex-2026-08-02-referenced-chatgpt-conversation-this-is-an\assets\c__Users_User_AppData_Roaming_Cursor_User_workspaceStorage_empty-window_images_vantage_ico-09e872e4-5e38-4788-8c2c-cf8665fac307.png"
)
res = Path(
    r"C:\Users\User\Documents\Codex\2026-08-02\referenced-chatgpt-conversation-this-is-an\vantage-control-android\android\app\src\main\res"
)
brand = Path(
    r"C:\Users\User\Documents\Codex\2026-08-02\referenced-chatgpt-conversation-this-is-an\vantage-control-android\assets\branding"
)
brand.mkdir(parents=True, exist_ok=True)

img = Image.open(src).convert("RGBA")
img.save(brand / "vantage_app_icon.png", "PNG")

legacy = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}
adaptive = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}


def resize_cover(im: Image.Image, size: int) -> Image.Image:
    return im.resize((size, size), Image.Resampling.LANCZOS)


for folder, size in legacy.items():
    out_dir = res / folder
    out_dir.mkdir(parents=True, exist_ok=True)
    icon = resize_cover(img, size)
    icon.save(out_dir / "ic_launcher.png", "PNG")
    icon.save(out_dir / "ic_launcher_round.png", "PNG")

for folder, size in adaptive.items():
    out_dir = res / folder
    fg = resize_cover(img, size)
    fg.save(out_dir / "ic_launcher_foreground.png", "PNG")

print("ok", img.size)
