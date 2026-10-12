"""Generate Windows/macOS icons from the original SVG using Pillow.

The SVG deliberately uses vector primitives supported by this small renderer.
No system font, external artwork, screenshot, or downloaded image is involved.
Run with a Python interpreter containing Pillow.
"""

from pathlib import Path
import struct
import xml.etree.ElementTree as ET

from PIL import Image, ImageColor, ImageDraw


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "assets" / "branding" / "app_icon.svg"


def render(size):
    tree = ET.parse(SOURCE).getroot()
    view = [float(part) for part in tree.attrib["viewBox"].split()]
    factor = size * 4 / view[2]
    canvas = Image.new("RGBA", (size * 4, size * 4))

    for shape in tree:
        tag = shape.tag.rsplit("}", 1)[-1]
        if tag in ("title", "desc"):
            continue
        attrs = shape.attrib
        layer = Image.new("RGBA", canvas.size)
        draw = ImageDraw.Draw(layer)

        def number(name, default=0):
            return float(attrs.get(name, default)) * factor

        def color(name):
            value = attrs.get(name, "none")
            if value == "none":
                return None
            red, green, blue, alpha = ImageColor.getcolor(value, "RGBA")
            return red, green, blue, round(alpha * float(attrs.get("opacity", 1)))

        fill = color("fill")
        stroke = color("stroke")
        width = max(1, round(number("stroke-width", 1)))
        if tag == "rect":
            x, y = number("x"), number("y")
            bounds = (x, y, x + number("width"), y + number("height"))
            draw.rounded_rectangle(bounds, number("rx"), fill, stroke, width)
        elif tag == "circle":
            x, y, radius = number("cx"), number("cy"), number("r")
            draw.ellipse((x - radius, y - radius, x + radius, y + radius), fill, stroke, width)
        elif tag in ("line", "polyline"):
            points = (
                [(number("x1"), number("y1")), (number("x2"), number("y2"))]
                if tag == "line"
                else [tuple(float(v) * factor for v in point.split(","))
                      for point in attrs["points"].split()]
            )
            draw.line(points, fill=stroke, width=width, joint="curve")
            if attrs.get("stroke-linecap") == "round":
                radius = width / 2
                for x, y in points:
                    draw.ellipse((x - radius, y - radius, x + radius, y + radius), stroke)
        else:
            raise ValueError(f"Unsupported SVG primitive: {tag}")
        canvas = Image.alpha_composite(canvas, layer)

    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def main():
    windows = ROOT / "windows" / "runner" / "resources" / "app_icon.ico"
    windows.parent.mkdir(parents=True, exist_ok=True)
    ico_sizes = (16, 20, 24, 32, 40, 48, 64, 128, 256)
    render(256).save(windows, format="ICO", sizes=[(s, s) for s in ico_sizes])
    macos = ROOT / "macos" / "Runner" / "Assets.xcassets" / "AppIcon.appiconset"
    macos.mkdir(parents=True, exist_ok=True)
    for size in (16, 32, 64, 128, 256, 512, 1024):
        render(size).save(macos / f"app_icon_{size}.png")
    render(256).save(SOURCE.with_name("app_icon_preview.png"))

    # Validate the generated container and all output dimensions before delivery.
    data = windows.read_bytes()
    reserved, kind, count = struct.unpack_from("<HHH", data)
    assert (reserved, kind, count) == (0, 1, len(ico_sizes))
    actual = []
    for index in range(count):
        width, height = struct.unpack_from("BB", data, 6 + index * 16)
        actual.append((width or 256, height or 256))
    assert actual == [(s, s) for s in ico_sizes], actual
    for size in (16, 32, 64, 128, 256, 512, 1024):
        with Image.open(macos / f"app_icon_{size}.png") as image:
            assert image.size == (size, size) and image.mode == "RGBA"
            assert image.getpixel((0, 0))[3] == 0
    print(f"Generated Windows ICO sizes {ico_sizes} and seven macOS PNG sizes from {SOURCE.name}.")


if __name__ == "__main__":
    main()
