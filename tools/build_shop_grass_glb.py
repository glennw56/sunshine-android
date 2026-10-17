#!/usr/bin/env python3
"""Author a Godot Y-up shop-only GLB from the bakery elevation refs.

Shop building on a simple grass field. No neighbor, trees, cars, or extra porches.
"""

from __future__ import annotations

import json
import math
import struct
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/models/sunshine_shop_grass.glb"
LOGO = ROOT / "assets/branding/sunshine-logo-disc.png"
FONT = ROOT / "assets/fonts/Nunito-Variable.ttf"

# Building: street facade faces +Z. Player stands on grass looking −Z.
CX = 0.0
HALF_W = 5.05
Z_FRONT = -1.05
Z_BACK = -8.55
FLOOR_Y = 0.42
EAVE_Y = 3.58
RIDGE_Y = 5.15
PARAPET_Y = 6.72
WALL = 0.30


def _u32(n: int) -> bytes:
    return struct.pack("<I", n)


def _pad4(data: bytes) -> bytes:
    return data + b"\x00" * ((4 - (len(data) % 4)) % 4)


def _cube() -> tuple[list[float], list[float], list[float], list[int]]:
    # Unit cube −0.5..0.5, one quad per face, UVs 0–1.
    faces = [
        ((-0.5, -0.5, 0.5), (0.5, -0.5, 0.5), (0.5, 0.5, 0.5), (-0.5, 0.5, 0.5), (0, 0, 1)),
        ((0.5, -0.5, -0.5), (-0.5, -0.5, -0.5), (-0.5, 0.5, -0.5), (0.5, 0.5, -0.5), (0, 0, -1)),
        ((-0.5, -0.5, -0.5), (-0.5, -0.5, 0.5), (-0.5, 0.5, 0.5), (-0.5, 0.5, -0.5), (-1, 0, 0)),
        ((0.5, -0.5, 0.5), (0.5, -0.5, -0.5), (0.5, 0.5, -0.5), (0.5, 0.5, 0.5), (1, 0, 0)),
        ((-0.5, 0.5, 0.5), (0.5, 0.5, 0.5), (0.5, 0.5, -0.5), (-0.5, 0.5, -0.5), (0, 1, 0)),
        ((-0.5, -0.5, -0.5), (0.5, -0.5, -0.5), (0.5, -0.5, 0.5), (-0.5, -0.5, 0.5), (0, -1, 0)),
    ]
    pos: list[float] = []
    nrm: list[float] = []
    uv: list[float] = []
    idx: list[int] = []
    uvs = ((0, 1), (1, 1), (1, 0), (0, 0))
    for a, b, c, d, n in faces:
        base = len(pos) // 3
        for v, (uu, vv) in zip((a, b, c, d), uvs):
            pos.extend(v)
            nrm.extend(n)
            uv.extend((uu, vv))
        idx.extend((base, base + 1, base + 2, base, base + 2, base + 3))
    return pos, nrm, uv, idx


class ShopGLB:
    def __init__(self) -> None:
        self.boxes: list[dict] = []
        self.images: dict[str, bytes] = {}

    def add_image(self, name: str, png: bytes) -> None:
        self.images[name] = png

    def box(self, name: str, center: tuple[float, float, float], size: tuple[float, float, float], mat: str) -> None:
        self.boxes.append({"name": name, "t": center, "s": size, "mat": mat})

    def slab(self, name: str, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, mat: str) -> None:
        self.box(
            name,
            ((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5),
            (abs(x1 - x0), abs(y1 - y0), abs(z1 - z0)),
            mat,
        )


def _sign_png() -> bytes:
    w, h = 1536, 220
    img = Image.new("RGB", (w, h), (227, 146, 46))
    draw = ImageDraw.Draw(img)
    font = ImageFont.truetype(str(FONT), 132)
    text = "SUNSHINE'S BAKERY"
    bbox = draw.textbbox((0, 0), text, font=font)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text(((w - tw) / 2 - bbox[0], (h - th) / 2 - bbox[1] - 4), text, fill=(42, 18, 24), font=font)
    buf = __import__("io").BytesIO()
    img.save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def _logo_png() -> bytes:
    im = Image.open(LOGO).convert("RGBA")
    # Keep the circular mark; flatten onto cream so unshaded albedo stays opaque.
    bg = Image.new("RGBA", im.size, (243, 226, 196, 255))
    bg.alpha_composite(im)
    buf = __import__("io").BytesIO()
    bg.convert("RGB").save(buf, format="PNG", optimize=True)
    return buf.getvalue()


def build_shop(s: ShopGLB) -> None:
    x0, x1 = CX - HALF_W, CX + HALF_W
    zf, zb = Z_FRONT, Z_BACK
    mid_z = (zf + zb) * 0.5
    depth = zf - zb

    # --- grass field only ---
    s.box("Grass", (0.0, -0.04, -4.0), (36.0, 0.08, 28.0), "Grass")

    # --- shell ---
    s.box("Shop_Facade", (CX, PARAPET_Y * 0.5, zf - 0.04), (HALF_W * 2 + 0.08, PARAPET_Y, 0.22), "WhiteSiding")
    s.box("Shop_WallL", (x0 + WALL * 0.5, EAVE_Y * 0.5, mid_z), (WALL, EAVE_Y, depth - 0.12), "WhiteSiding")
    s.box("Shop_WallR", (x1 - WALL * 0.5, EAVE_Y * 0.5, mid_z), (WALL, EAVE_Y, depth - 0.12), "WhiteSiding")
    s.box("Shop_WallB", (CX, (EAVE_Y + 0.55) * 0.5, zb + 0.12), (HALF_W * 2 - 0.08, EAVE_Y + 0.55, 0.24), "WhiteSiding")
    s.box("Shop_Floor", (CX, 0.06, mid_z), (HALF_W * 2 - 0.4, 0.12, depth - 0.4), "WoodL")

    # clapboard grooves on the street face
    for i, y in enumerate([0.28 + i * 0.30 for i in range(21)]):
        if y > PARAPET_Y - 0.25:
            break
        s.box(f"Shop_SidingF_{i}", (CX, y, zf + 0.07), (HALF_W * 2 - 0.2, 0.045, 0.04), "WhiteSiding")

    # pink trim — street parapet + corners + fascia (entrance / side / back refs)
    s.box("Shop_TrimBotF", (CX, 0.11, zf + 0.08), (HALF_W * 2 + 0.22, 0.22, 0.38), "PinkTrim")
    s.box("Shop_TrimTopF", (CX, PARAPET_Y + 0.10, zf + 0.02), (HALF_W * 2 + 0.34, 0.22, 0.42), "PinkTrim")
    s.box("Shop_TrimL", (x0 - 0.02, PARAPET_Y * 0.5, zf + 0.04), (0.22, PARAPET_Y + 0.12, 0.40), "PinkTrim")
    s.box("Shop_TrimR", (x1 + 0.02, PARAPET_Y * 0.5, zf + 0.04), (0.22, PARAPET_Y + 0.12, 0.40), "PinkTrim")
    s.box("Shop_FasciaL", (x0 - 0.02, EAVE_Y + 0.08, mid_z), (0.16, 0.18, depth + 0.15), "PinkTrim")
    s.box("Shop_FasciaR", (x1 + 0.02, EAVE_Y + 0.08, mid_z), (0.16, 0.18, depth + 0.15), "PinkTrim")
    s.box("Shop_FasciaB", (CX, EAVE_Y + 0.55, zb - 0.02), (HALF_W * 2 + 0.18, 0.16, 0.18), "PinkTrim")
    # pink corner posts (entrance elevation)
    s.box("Shop_PostFL", (x0 - 0.04, EAVE_Y * 0.5, zf + 0.06), (0.20, EAVE_Y + 0.08, 0.20), "PinkTrim")
    s.box("Shop_PostFR", (x1 + 0.04, EAVE_Y * 0.5, zf + 0.06), (0.20, EAVE_Y + 0.08, 0.20), "PinkTrim")
    s.box("Shop_PostBL", (x0 - 0.04, EAVE_Y * 0.5, zb - 0.02), (0.20, EAVE_Y + 0.08, 0.20), "PinkTrim")
    s.box("Shop_PostBR", (x1 + 0.04, EAVE_Y * 0.5, zb - 0.02), (0.20, EAVE_Y + 0.08, 0.20), "PinkTrim")

    # gable roof (ridge along X; back elevation is the gable end)
    steps = 10
    half = HALF_W + 0.18
    for i in range(steps):
        t0, t1 = i / steps, (i + 1) / steps
        y0 = EAVE_Y + 0.12 + (RIDGE_Y - EAVE_Y) * t0
        y1 = EAVE_Y + 0.12 + (RIDGE_Y - EAVE_Y) * t1
        for side, name in ((-1, "L"), (1, "R")):
            xc = CX + side * (half * (1.0 - (t0 + t1) * 0.5))
            s.box(
                f"Shop_Roof_{name}_{i}",
                (xc, (y0 + y1) * 0.5, mid_z),
                (half / steps + 0.08, 0.22, depth + 0.35),
                "Roof",
            )
    s.box("Shop_Ridge", (CX, RIDGE_Y + 0.04, mid_z), (0.28, 0.16, depth + 0.4), "Roof")
    # roof vents (entrance elevation)
    s.box("Shop_VentRoof_0", (CX - 1.6, RIDGE_Y + 0.18, mid_z - 0.4), (0.22, 0.16, 0.22), "Black")
    s.box("Shop_VentRoof_1", (CX + 1.8, RIDGE_Y + 0.18, mid_z + 0.6), (0.22, 0.16, 0.22), "Black")

    # --- street facade: logo + sign + two dark windows + 2231 (storefront photo) ---
    s.box("Shop_Sign", (CX, 4.28, zf + 0.14), (6.35, 0.78, 0.10), "SignTex")
    s.box("Shop_LogoDisc", (CX, 5.55, zf + 0.16), (1.72, 1.72, 0.08), "LogoTex")
    s.box("Shop_LogoRim", (CX, 5.55, zf + 0.11), (1.88, 1.88, 0.05), "PinkTrim")
    _window(s, "Shop_WinF_L", -2.15, 2.05, zf + 0.12, 1.72, 1.28, dark=True)
    _window(s, "Shop_WinF_R", 2.15, 2.05, zf + 0.12, 1.72, 1.28, dark=True)
    # stacked 2231 on photo-right
    for i, ch in enumerate("2231"):
        s.box(f"Shop_Digit_{ch}_{i}", (x1 - 0.22, 2.55 - i * 0.38, zf + 0.14), (0.08, 0.28, 0.04), "Black")

    # --- left / entrance elevation: ramp, double doors, wreath, windows, AC, downspout ---
    _build_entrance_left(s, x0, zf, zb)
    # --- right / side elevation: windows, barred window, door + stairs, AC, chimney ---
    _build_side_right(s, x1, zf, zb)
    # --- back elevation: gable vent, door + stairs + rail, foundation hatch ---
    _build_back(s, x0, x1, zb)


def _window(
    s: ShopGLB,
    prefix: str,
    x: float,
    y: float,
    z: float,
    w: float,
    h: float,
    dark: bool = False,
    bars: bool = False,
    face: str = "z",
) -> None:
    glass = "GlassDk" if dark else "Glass"
    if face == "z":
        s.box(f"{prefix}_frame", (x, y, z), (w + 0.16, h + 0.16, 0.10), "PinkTrim")
        s.box(f"{prefix}_glass", (x, y, z + 0.03), (w, h, 0.05), glass)
        s.box(f"{prefix}_mull_v", (x, y, z + 0.05), (0.05, h - 0.04, 0.03), "WhiteSiding")
        s.box(f"{prefix}_mull_h", (x, y, z + 0.05), (w - 0.04, 0.05, 0.03), "WhiteSiding")
        if bars:
            for i in range(3):
                s.box(f"{prefix}_bar_h_{i}", (x, y - h * 0.28 + i * h * 0.28, z + 0.07), (w - 0.08, 0.035, 0.03), "Black")
            for i in range(3):
                s.box(f"{prefix}_bar_v_{i}", (x - w * 0.28 + i * w * 0.28, y, z + 0.07), (0.035, h - 0.08, 0.03), "Black")
    else:
        # face X (side walls); z is unused as depth, x is the wall plane
        s.box(f"{prefix}_frame", (x, y, z), (0.10, h + 0.16, w + 0.16), "PinkTrim")
        s.box(f"{prefix}_glass", (x + 0.03, y, z), (0.05, h, w), glass)
        s.box(f"{prefix}_mull_v", (x + 0.05, y, z), (0.03, h - 0.04, 0.05), "WhiteSiding")
        s.box(f"{prefix}_mull_h", (x + 0.05, y, z), (0.03, 0.05, w - 0.04), "WhiteSiding")
        if bars:
            for i in range(3):
                s.box(f"{prefix}_bar_h_{i}", (x + 0.07, y - h * 0.28 + i * h * 0.28, z), (0.03, 0.035, w - 0.08), "Black")
            for i in range(3):
                s.box(f"{prefix}_bar_v_{i}", (x + 0.07, y, z - w * 0.28 + i * w * 0.28), (0.03, h - 0.08, 0.035), "Black")


def _build_entrance_left(s: ShopGLB, x0: float, zf: float, zb: float) -> None:
    # Viewed from −X: street is toward +Z (left of the elevation). Ramp, then doors, windows, AC.
    wall_x = x0 - 0.02
    # wooden ADA ramp + landing + rail (elevation_entrance)
    landing_z = -3.15
    s.box("Shop_RampLanding", (-5.85, FLOOR_Y, landing_z), (1.85, 0.12, 1.85), "Wood")
    for i in range(8):
        t = i / 7.0
        y = 0.07 + FLOOR_Y * t
        z = zf + 0.15 - t * (zf + 0.15 - (landing_z + 0.95))
        s.box(f"Shop_RampStep_{i}", (-5.85, y, z), (1.55, 0.08, 0.28), "Wood")
    # ramp rails
    s.box("Shop_RampRailO", (-6.72, 0.72, -2.15), (0.08, 0.72, 2.55), "Wood")
    s.box("Shop_RampRailI", (-4.98, 0.72, -2.15), (0.08, 0.72, 2.55), "Wood")
    for i in range(6):
        z = zf - 0.15 - i * 0.42
        s.box(f"Shop_RampBalO_{i}", (-6.72, 0.52, z), (0.08, 0.95, 0.08), "Wood")
        s.box(f"Shop_RampBalI_{i}", (-4.98, 0.52, z), (0.08, 0.95, 0.08), "Wood")
    # double doors + wreath + handles + lantern
    door_z = -3.95
    s.box("Shop_DoorL", (wall_x - 0.04, 1.52, door_z - 0.42), (0.08, 2.15, 0.78), "WhiteSiding")
    s.box("Shop_DoorR", (wall_x - 0.04, 1.52, door_z + 0.42), (0.08, 2.15, 0.78), "WhiteSiding")
    s.box("Shop_DoorFrameL", (wall_x - 0.06, 1.58, door_z - 0.86), (0.10, 2.32, 0.10), "PinkTrim")
    s.box("Shop_DoorFrameR", (wall_x - 0.06, 1.58, door_z + 0.86), (0.10, 2.32, 0.10), "PinkTrim")
    s.box("Shop_DoorFrameT", (wall_x - 0.06, 2.72, door_z), (0.10, 0.10, 1.82), "PinkTrim")
    s.box("Shop_DoorMull", (wall_x - 0.05, 1.52, door_z), (0.08, 2.15, 0.08), "PinkTrim")
    s.box("Shop_DoorGlassL", (wall_x - 0.09, 1.85, door_z - 0.42), (0.04, 1.15, 0.48), "Glass")
    s.box("Shop_DoorGlassR", (wall_x - 0.09, 1.85, door_z + 0.42), (0.04, 1.15, 0.48), "Glass")
    s.box("Shop_DoorHandleL", (wall_x - 0.12, 1.22, door_z - 0.08), (0.06, 0.14, 0.06), "Black")
    s.box("Shop_DoorHandleR", (wall_x - 0.12, 1.22, door_z + 0.08), (0.06, 0.14, 0.06), "Black")
    s.box("Shop_LanternL", (wall_x - 0.16, 2.55, door_z + 0.95), (0.14, 0.22, 0.14), "Black")
    s.box("Shop_LanternGlowL", (wall_x - 0.16, 2.55, door_z + 0.95), (0.10, 0.14, 0.10), "WarmInterior")
    _wreath(s, wall_x - 0.14, 1.95, door_z - 0.42)
    # two side windows toward the back
    _window(s, "Shop_WinL_0", wall_x - 0.08, 1.85, -5.55, 0.95, 1.15, face="x")
    _window(s, "Shop_WinL_1", wall_x - 0.08, 1.85, -6.85, 0.95, 1.15, face="x")
    # AC condenser + downspout (entrance elevation)
    s.box("Shop_ACL", (-5.55, 0.42, -7.55), (0.55, 0.72, 0.72), "WhiteAC")
    s.box("Shop_ACL_fan", (-5.78, 0.55, -7.55), (0.06, 0.42, 0.42), "Black")
    s.box("Shop_DownspoutL", (x0 - 0.08, 1.85, zf - 0.35), (0.08, 3.55, 0.08), "WhiteSiding")
    s.box("Shop_DownspoutL_out", (x0 - 0.18, 0.12, zf - 0.35), (0.22, 0.08, 0.08), "WhiteSiding")


def _wreath(s: ShopGLB, x: float, y: float, z: float) -> None:
    for i in range(12):
        ang = i / 12.0 * math.tau
        s.box(
            f"Shop_Wreath_{i}",
            (x, y + math.sin(ang) * 0.22, z + math.cos(ang) * 0.22),
            (0.07, 0.10, 0.10),
            "WreathGreen",
        )
    s.box("Shop_WreathBow", (x, y - 0.20, z), (0.07, 0.10, 0.16), "FlowerP")
    s.box("Shop_WreathFlower", (x, y + 0.08, z + 0.10), (0.07, 0.08, 0.08), "FlowerW")


def _build_side_right(s: ShopGLB, x1: float, zf: float, zb: float) -> None:
    wall_x = x1 + 0.02
    # windows along the right long wall (side elevation, street toward +Z / left of drawing)
    _window(s, "Shop_WinR_0", wall_x + 0.08, 2.05, -2.15, 0.72, 1.15, face="x")
    _window(s, "Shop_WinR_1", wall_x + 0.08, 2.05, -3.45, 0.72, 1.15, bars=True, face="x")
    _window(s, "Shop_WinR_2", wall_x + 0.08, 2.05, -7.15, 0.72, 1.15, face="x")
    # single door + three stairs + rails
    door_z = -5.55
    s.box("Shop_DoorSide", (wall_x + 0.04, 1.55, door_z), (0.08, 2.18, 0.88), "WhiteSiding")
    s.box("Shop_DoorSideFrameL", (wall_x + 0.06, 1.62, door_z - 0.50), (0.10, 2.34, 0.10), "PinkTrim")
    s.box("Shop_DoorSideFrameR", (wall_x + 0.06, 1.62, door_z + 0.50), (0.10, 2.34, 0.10), "PinkTrim")
    s.box("Shop_DoorSideFrameT", (wall_x + 0.06, 2.76, door_z), (0.10, 0.10, 1.10), "PinkTrim")
    s.box("Shop_DoorSideGlass", (wall_x + 0.08, 1.95, door_z), (0.04, 1.05, 0.52), "Glass")
    s.box("Shop_DoorSideKnob", (wall_x + 0.12, 1.25, door_z + 0.28), (0.06, 0.10, 0.06), "Black")
    s.box("Shop_LanternR", (wall_x + 0.16, 2.62, door_z + 0.72), (0.14, 0.22, 0.14), "Black")
    for i in range(3):
        s.box(f"Shop_SideStep_{i}", (x1 + 0.55 + i * 0.28, 0.10 + i * 0.12, door_z), (0.32, 0.10, 1.05), "WoodD")
    s.box("Shop_SideRailL", (x1 + 0.95, 0.72, door_z - 0.58), (0.72, 0.85, 0.08), "WoodD")
    s.box("Shop_SideRailR", (x1 + 0.95, 0.72, door_z + 0.58), (0.72, 0.85, 0.08), "WoodD")
    # AC + electrical + chimney (side elevation)
    s.box("Shop_ACR", (5.55, 0.42, -4.55), (0.55, 0.72, 0.72), "WhiteAC")
    s.box("Shop_ACR_fan", (5.78, 0.55, -4.55), (0.06, 0.42, 0.42), "Black")
    s.box("Shop_Electric", (x1 + 0.10, 0.72, -4.95), (0.08, 0.22, 0.16), "Metal")
    s.box("Shop_Chimney", (3.15, RIDGE_Y + 0.55, -6.85), (0.48, 1.15, 0.48), "WhiteSiding")
    s.box("Shop_ChimneyCap", (3.15, RIDGE_Y + 1.18, -6.85), (0.56, 0.10, 0.56), "WhiteSiding")
    s.box("Shop_Flue", (3.15, RIDGE_Y + 1.35, -6.85), (0.16, 0.28, 0.16), "Black")
    s.box("Shop_DownspoutR", (x1 + 0.08, 1.85, zb + 0.35), (0.08, 3.55, 0.08), "WhiteSiding")


def _build_back(s: ShopGLB, x0: float, x1: float, zb: float) -> None:
    # gable end: louver vent, back door on +X, foundation hatch on −X
    s.box("Shop_Gable", (CX, EAVE_Y + 0.85, zb - 0.02), (4.2, 1.55, 0.18), "WhiteSiding")
    s.box("Shop_GableVent", (CX, EAVE_Y + 1.15, zb - 0.10), (0.42, 0.32, 0.08), "PinkTrim")
    s.box("Shop_GableLouver", (CX, EAVE_Y + 1.15, zb - 0.14), (0.28, 0.18, 0.04), "Black")
    # stem wall / foundation
    s.box("Shop_Foundation", (CX, 0.18, zb - 0.08), (HALF_W * 2 - 0.2, 0.36, 0.22), "Foundation")
    s.box("Shop_Hatch", (CX - 2.55, 0.32, zb - 0.16), (0.72, 0.62, 0.10), "WoodD")
    s.box("Shop_HatchHingeL", (CX - 2.82, 0.32, zb - 0.20), (0.06, 0.14, 0.04), "Metal")
    s.box("Shop_HatchHingeR", (CX - 2.28, 0.32, zb - 0.20), (0.06, 0.14, 0.04), "Metal")
    # back door + deck rail + stairs
    door_x = 2.15
    s.box("Shop_DoorBack", (door_x, 1.72, zb - 0.06), (0.84, 2.05, 0.08), "WhiteSiding")
    s.box("Shop_DoorBackFrameL", (door_x - 0.48, 1.78, zb - 0.08), (0.10, 2.22, 0.10), "PinkTrim")
    s.box("Shop_DoorBackFrameR", (door_x + 0.48, 1.78, zb - 0.08), (0.10, 2.22, 0.10), "PinkTrim")
    s.box("Shop_DoorBackFrameT", (door_x, 2.86, zb - 0.08), (1.06, 0.10, 0.10), "PinkTrim")
    s.box("Shop_DoorBackGlass", (door_x, 2.05, zb - 0.12), (0.48, 1.05, 0.04), "Glass")
    s.box("Shop_DoorBackKnob", (door_x + 0.28, 1.42, zb - 0.16), (0.06, 0.10, 0.06), "Black")
    s.box("Shop_BackDeck", (door_x - 0.15, FLOOR_Y, zb - 0.85), (2.35, 0.12, 1.45), "WoodD")
    s.box("Shop_BackRailL", (door_x - 1.15, 0.95, zb - 0.85), (0.08, 0.95, 1.35), "WoodD")
    s.box("Shop_BackRailR", (1.05, 0.95, zb - 1.45), (1.8, 0.95, 0.08), "WoodD")
    for i in range(6):
        s.box(
            f"Shop_BackStep_{i}",
            (door_x + 0.15, 0.08 + i * 0.07, zb - 1.15 - i * 0.22),
            (1.15, 0.09, 0.24),
            "WoodD",
        )
    s.box("Shop_BackStairRailL", (door_x - 0.48, 0.85, zb - 1.85), (0.08, 1.15, 1.55), "WoodD")
    s.box("Shop_BackStairRailR", (door_x + 0.78, 0.85, zb - 1.85), (0.08, 1.15, 1.55), "WoodD")


MATS = {
    "WhiteSiding": (0.97, 0.96, 0.93),
    "PinkTrim": (0.93, 0.55, 0.62),
    "Roof": (0.22, 0.21, 0.20),
    "Wood": (0.76, 0.52, 0.28),
    "WoodD": (0.45, 0.28, 0.14),
    "WoodL": (0.86, 0.72, 0.52),
    "Glass": (0.35, 0.48, 0.55),
    "GlassDk": (0.12, 0.16, 0.18),
    "DarkInterior": (0.18, 0.16, 0.15),
    "Concrete": (0.82, 0.80, 0.76),
    "Foundation": (0.90, 0.88, 0.82),
    "Grass": (0.48, 0.72, 0.36),
    "Black": (0.10, 0.10, 0.11),
    "WhiteAC": (0.93, 0.93, 0.94),
    "Metal": (0.45, 0.46, 0.48),
    "WarmInterior": (1.0, 0.86, 0.62),
    "WreathGreen": (0.22, 0.48, 0.22),
    "FlowerP": (0.86, 0.42, 0.55),
    "FlowerW": (0.95, 0.94, 0.90),
    "Orange": (0.89, 0.57, 0.18),
    "SignTex": (1, 1, 1),
    "LogoTex": (1, 1, 1),
}


def write_glb(shop: ShopGLB, dest: Path) -> None:
    pos, nrm, uv, idx = _cube()
    pos_b = struct.pack(f"<{len(pos)}f", *pos)
    nrm_b = struct.pack(f"<{len(nrm)}f", *nrm)
    uv_b = struct.pack(f"<{len(uv)}f", *uv)
    idx_b = struct.pack(f"<{len(idx)}H", *idx)

    blobs: list[bytes] = []
    accessors = []
    buffer_views = []

    def add_buf(data: bytes, target: int | None = None) -> int:
        data = _pad4(data)
        offset = sum(len(b) for b in blobs)
        blobs.append(data)
        view = {"buffer": 0, "byteOffset": offset, "byteLength": len(data) - (len(data) - len(data.rstrip(b"\x00")) if False else len(data))}
        # keep padded length
        view["byteLength"] = len(data) if len(data) % 4 == 0 else len(data)
        if target:
            view["target"] = target
        buffer_views.append(view)
        return len(buffer_views) - 1

    # fix add_buf to use actual padded bytes length correctly
    blobs.clear()
    buffer_views.clear()

    def push(data: bytes, target: int | None = None) -> int:
        padded = _pad4(data)
        offset = sum(len(b) for b in blobs)
        blobs.append(padded)
        view: dict = {"buffer": 0, "byteOffset": offset, "byteLength": len(data)}
        if target:
            view["target"] = target
        buffer_views.append(view)
        return len(buffer_views) - 1

    pv = push(pos_b, 34962)
    nv = push(nrm_b, 34962)
    uvv = push(uv_b, 34962)
    iv = push(idx_b, 34963)

    def acc(view: int, count: int, typ: str, comp: int, mn=None, mx=None) -> int:
        a = {"bufferView": view, "componentType": comp, "count": count, "type": typ}
        if mn is not None:
            a["min"] = mn
            a["max"] = mx
        accessors.append(a)
        return len(accessors) - 1

    pa = acc(pv, len(pos) // 3, "VEC3", 5126, [-0.5, -0.5, -0.5], [0.5, 0.5, 0.5])
    na = acc(nv, len(nrm) // 3, "VEC3", 5126)
    ua = acc(uvv, len(uv) // 2, "VEC2", 5126)
    ia = acc(iv, len(idx), "SCALAR", 5123)

    images = []
    textures = []
    img_index = {}
    for name, png in shop.images.items():
        view = push(png)
        images.append({"name": name, "mimeType": "image/png", "bufferView": view})
        textures.append({"source": len(images) - 1})
        img_index[name] = len(textures) - 1

    mat_index = {}
    materials = []
    for name, rgb in MATS.items():
        mat: dict = {
            "name": name,
            "pbrMetallicRoughness": {
                "baseColorFactor": [rgb[0], rgb[1], rgb[2], 1.0],
                "metallicFactor": 0.0,
                "roughnessFactor": 1.0,
            },
        }
        if name == "LogoTex":
            mat["pbrMetallicRoughness"]["baseColorTexture"] = {"index": img_index["logo_disc"]}
            mat["pbrMetallicRoughness"]["baseColorFactor"] = [1, 1, 1, 1]
        if name == "SignTex":
            mat["pbrMetallicRoughness"]["baseColorTexture"] = {"index": img_index["bakery_sign"]}
            mat["pbrMetallicRoughness"]["baseColorFactor"] = [1, 1, 1, 1]
        if name in ("Glass", "GlassDk"):
            mat["alphaMode"] = "BLEND"
            mat["pbrMetallicRoughness"]["baseColorFactor"] = [rgb[0], rgb[1], rgb[2], 0.55 if name == "Glass" else 0.78]
        materials.append(mat)
        mat_index[name] = len(materials) - 1

    # one mesh per material (shared unit cube)
    meshes = []
    mesh_for_mat = {}
    for name, mi in mat_index.items():
        meshes.append(
            {
                "name": f"Cube_{name}",
                "primitives": [
                    {
                        "attributes": {"POSITION": pa, "NORMAL": na, "TEXCOORD_0": ua},
                        "indices": ia,
                        "material": mi,
                    }
                ],
            }
        )
        mesh_for_mat[name] = len(meshes) - 1

    nodes = []
    groups: dict[str, list[int]] = {
        "Shop": [],
        "Shop_Ramp": [],
        "Ground": [],
    }
    for box in shop.boxes:
        idx_n = len(nodes)
        nodes.append(
            {
                "name": box["name"],
                "mesh": mesh_for_mat[box["mat"]],
                "translation": [round(box["t"][0], 4), round(box["t"][1], 4), round(box["t"][2], 4)],
                "scale": [round(box["s"][0], 4), round(box["s"][1], 4), round(box["s"][2], 4)],
            }
        )
        if box["name"] == "Grass" or box["name"].startswith("Grass"):
            groups["Ground"].append(idx_n)
        elif "Ramp" in box["name"] or box["name"].startswith("Shop_Ramp"):
            groups["Shop_Ramp"].append(idx_n)
        else:
            groups["Shop"].append(idx_n)

    group_nodes = []
    for gname, children in groups.items():
        group_nodes.append(len(nodes))
        nodes.append({"name": gname, "children": children})
    root = len(nodes)
    nodes.append({"name": "SunshineShopGrass", "children": group_nodes})

    bin_blob = b"".join(blobs)
    gltf = {
        "asset": {"generator": "Sunshine shop-on-grass builder", "version": "2.0"},
        "scene": 0,
        "scenes": [{"name": "Scene", "nodes": [root]}],
        "nodes": nodes,
        "meshes": meshes,
        "materials": materials,
        "textures": textures,
        "images": images,
        "accessors": accessors,
        "bufferViews": buffer_views,
        "buffers": [{"byteLength": len(bin_blob)}],
    }
    json_bytes = _pad4(json.dumps(gltf, separators=(",", ":")).encode("utf-8"))
    bin_padded = _pad4(bin_blob)
    total = 12 + 8 + len(json_bytes) + 8 + len(bin_padded)
    dest.parent.mkdir(parents=True, exist_ok=True)
    with dest.open("wb") as f:
        f.write(b"glTF")
        f.write(_u32(2))
        f.write(_u32(total))
        f.write(_u32(len(json_bytes)))
        f.write(b"JSON")
        f.write(json_bytes)
        f.write(_u32(len(bin_padded)))
        f.write(b"BIN\x00")
        f.write(bin_padded)
    print(f"wrote {dest} bytes={dest.stat().st_size} boxes={len(shop.boxes)} nodes={len(nodes)}")


def main() -> None:
    shop = ShopGLB()
    shop.add_image("logo_disc", _logo_png())
    shop.add_image("bakery_sign", _sign_png())
    build_shop(shop)
    write_glb(shop, OUT)


if __name__ == "__main__":
    main()
