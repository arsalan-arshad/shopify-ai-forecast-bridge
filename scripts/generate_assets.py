#!/usr/bin/env python3
"""
Generates production-grade AppExchange and open-source visual assets
for Shopify AI Forecast & Inventory Intelligence Bridge without external dependencies.
"""

import os
import struct
import subprocess
import zlib

ASSETS_DIR = os.path.abspath(os.path.join(os.path.dirname(__file__), '..', 'assets'))
os.makedirs(ASSETS_DIR, exist_ok=True)


def make_png_buffer(width, height, pixel_fn):
    """
    Constructs a true-color PNG using Python's standard library.
    pixel_fn(x, y) returns (r, g, b) tuple (0-255).
    """
    raw = bytearray()
    for y in range(height):
        raw.append(0)  # Filter byte: 0 = None
        for x in range(width):
            r, g, b = pixel_fn(x, y)
            raw.append(r & 0xFF)
            raw.append(g & 0xFF)
            raw.append(b & 0xFF)

    compressed = zlib.compress(bytes(raw), level=6)

    def chunk(tag, data):
        return (
            struct.pack('>I', len(data))
            + tag
            + data
            + struct.pack('>I', zlib.crc32(tag + data) & 0xFFFFFFFF)
        )

    ihdr = struct.pack('>IIBBBBB', width, height, 8, 2, 0, 0, 0)
    return (
        b'\x89PNG\r\n\x1a\n'
        + chunk(b'IHDR', ihdr)
        + chunk(b'IDAT', compressed)
        + chunk(b'IEND', b'')
    )


# 1. Generate App Icon (512x512)
print('Generating app_icon.png (512x512)...')


def icon_pixel(x, y):
    # Rounded corner mask (radius = 90)
    w, h = 512, 512
    r_corner = 90
    dx = min(x, w - 1 - x)
    dy = min(y, h - 1 - y)
    if dx < r_corner and dy < r_corner:
        dist_sq = (r_corner - dx) ** 2 + (r_corner - dy) ** 2
        if dist_sq > r_corner**2:
            return (248, 250, 252)  # background match

    # Gradient: Shopify Green (#008060 -> (0, 128, 96)) to Salesforce Blue (#0176D3 -> (1, 118, 211))
    ratio = (x + y) / (w + h)
    r = int(0 * (1 - ratio) + 1 * ratio)
    g = int(128 * (1 - ratio) + 118 * ratio)
    b = int(96 * (1 - ratio) + 211 * ratio)

    # Accent center band / forecast chart motif
    if 210 <= y <= 300 and 120 <= x <= 392:
        # Simulated chart line
        chart_y = int(270 - 40 * ((x - 120) / 272))
        if abs(y - chart_y) <= 8:
            return (255, 255, 255)
        if y > chart_y and (x % 30 < 18):
            return (min(255, r + 40), min(255, g + 50), min(255, b + 60))

    # Dot marker
    if (x - 392) ** 2 + (y - 230) ** 2 <= 144:
        return (255, 255, 255)

    return (r, g, b)


icon_bytes = make_png_buffer(512, 512, icon_pixel)
icon_png_path = os.path.join(ASSETS_DIR, 'app_icon.png')
with open(icon_png_path, 'wb') as f:
    f.write(icon_bytes)

# Resize to 120x120 for AppExchange requirement
icon_120_path = os.path.join(ASSETS_DIR, 'app_icon_120.png')
subprocess.run(
    ['sips', '-z', '120', '120', icon_png_path, '--out', icon_120_path],
    check=True,
    capture_output=True,
)

# Convert icon to JPEG
icon_jpg_path = os.path.join(ASSETS_DIR, 'app_icon.jpg')
subprocess.run(
    ['sips', '-s', 'format', 'jpeg', icon_png_path, '--out', icon_jpg_path],
    check=True,
    capture_output=True,
)

# 2. Generate Banner (1280x720)
print('Generating app_banner.png (1280x720)...')


def banner_pixel(x, y):
    w, h = 1280, 720
    # Gradient: Deep Shopify green-black (#00281e) to Salesforce deep navy (#013466)
    ratio_x = x / w
    ratio_y = y / h
    ratio = 0.5 * ratio_x + 0.5 * ratio_y

    r = int(0 * (1 - ratio) + 1 * ratio)
    g = int(50 * (1 - ratio) + 80 * ratio)
    b = int(40 * (1 - ratio) + 140 * ratio)

    # Top accent bar
    if y < 10:
        return (0, 161, 224)

    # 4 Feature Card areas
    card_y_start = 480
    card_y_end = 640
    if card_y_start <= y <= card_y_end:
        for i in range(4):
            card_x_start = 80 + i * 285
            card_x_end = card_x_start + 260
            if card_x_start <= x <= card_x_end:
                # Border
                if (
                    x == card_x_start
                    or x == card_x_end
                    or y == card_y_start
                    or y == card_y_end
                ):
                    return (255, 255, 255)
                # Card background fill
                return (min(255, r + 25), min(255, g + 30), min(255, b + 40))

    return (r, g, b)


banner_bytes = make_png_buffer(1280, 720, banner_pixel)
banner_png_path = os.path.join(ASSETS_DIR, 'app_banner.png')
with open(banner_png_path, 'wb') as f:
    f.write(banner_bytes)

# Convert banner to JPEG
banner_jpg_path = os.path.join(ASSETS_DIR, 'app_banner.jpg')
subprocess.run(
    ['sips', '-s', 'format', 'jpeg', banner_png_path, '--out', banner_jpg_path],
    check=True,
    capture_output=True,
)

# 3. Generate 4 UI Walkthrough Screenshots (1280x850)
screenshots = [
    ('screenshot1_executive_dashboard.png', (1, 118, 211)),  # Salesforce Blue
    (
        'screenshot2_forecast_intelligence_lwc.png',
        (0, 128, 96),
    ),  # Shopify Green
    ('screenshot3_conversational_ai_chat.png', (121, 40, 202)),  # AI Purple
    (
        'screenshot4_deal_protection_validator.png',
        (234, 0, 30),
    ),  # Critical Alert Red
]

for filename, theme_color in screenshots:
    print(f'Generating {filename} (1280x850)...')

    def screenshot_pixel(x, y):
        w, h = 1280, 850
        # Chrome Header bar (0 to 60)
        if y < 60:
            return (241, 245, 249)
        if y == 60:
            return (203, 213, 225)

        # Left SLDS Navigation rail (0 to 220)
        if x < 220:
            if x == 219:
                return (226, 232, 240)
            return (255, 255, 255)

        # Main viewport background
        if y < 140:
            # Header card
            if 80 <= y <= 130 and 240 <= x <= 1240:
                if y == 80 or y == 130 or x == 240 or x == 1240:
                    return (226, 232, 240)
                # Accent strip
                if x <= 246:
                    return theme_color
                return (255, 255, 255)

        # 3 Dashboard metric cards (160 to 280)
        if 160 <= y <= 280:
            for i in range(3):
                cx1 = 240 + i * 340
                cx2 = cx1 + 310
                if cx1 <= x <= cx2:
                    if y == 160 or y == 280 or x == cx1 or x == cx2:
                        return (226, 232, 240)
                    if y == 161 or y == 162 or y == 163:
                        return theme_color
                    return (255, 255, 255)

        # Main content table / card (310 to 800)
        if 310 <= y <= 800 and 240 <= x <= 1240:
            if y == 310 or y == 800 or x == 240 or x == 1240:
                return (226, 232, 240)
            # Table header
            if 310 <= y <= 350:
                return (248, 250, 252)
            # Alternating rows
            row_idx = (y - 350) // 45
            if row_idx % 2 == 1:
                return (248, 250, 252)
            return (255, 255, 255)

        return (248, 250, 252)

    ss_bytes = make_png_buffer(1280, 850, screenshot_pixel)
    ss_path = os.path.join(ASSETS_DIR, filename)
    with open(ss_path, 'wb') as f:
        f.write(ss_bytes)

print('✅ All visual assets successfully generated in assets/')
