from pathlib import Path

from PIL import Image

SRC = Path(
    r"C:\Users\User\.cursor\projects\c-Users-User-Documents-Codex-2026-08-02-referenced-chatgpt-conversation-this-is-an\assets\vantage_control_icon_1024.png"
)
RES = Path(
    r"C:\Users\User\Documents\Codex\2026-08-02\referenced-chatgpt-conversation-this-is-an\vantage-control-android\android\app\src\main\res"
)
BRAND = Path(
    r"C:\Users\User\Documents\Codex\2026-08-02\referenced-chatgpt-conversation-this-is-an\vantage-control-android\assets\branding"
)


def main() -> None:
    BRAND.mkdir(parents=True, exist_ok=True)
    img = Image.open(SRC).convert("RGBA")
    w, h = img.size
    side = min(w, h)
    img = img.crop(((w - side) // 2, (h - side) // 2, (w + side) // 2, (h + side) // 2))
    img.save(BRAND / "app_icon_1024.png")

    sizes = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in sizes.items():
        d = RES / folder
        d.mkdir(parents=True, exist_ok=True)
        out = img.resize((size, size), Image.Resampling.LANCZOS)
        out.save(d / "ic_launcher.png")
        print(folder, size)

    fg_sizes = {
        "mipmap-mdpi": 108,
        "mipmap-hdpi": 162,
        "mipmap-xhdpi": 216,
        "mipmap-xxhdpi": 324,
        "mipmap-xxxhdpi": 432,
    }
    for folder, size in fg_sizes.items():
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        inner_s = int(size * 0.72)
        inner = img.resize((inner_s, inner_s), Image.Resampling.LANCZOS)
        canvas.paste(inner, ((size - inner_s) // 2, (size - inner_s) // 2), inner)
        (RES / folder).mkdir(parents=True, exist_ok=True)
        canvas.save(RES / folder / "ic_launcher_foreground.png")

    ico_path = BRAND / "VantageControl.ico"
    img.save(
        ico_path,
        format="ICO",
        sizes=[(16, 16), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
    )
    print("wrote", ico_path)


if __name__ == "__main__":
    main()
