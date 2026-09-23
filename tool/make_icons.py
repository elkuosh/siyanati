# يرسم أيقونة التطبيق بكل المقاسات (محتاج: pip install pillow)
import math, os
from PIL import Image, ImageDraw

S = 1024
im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(im)
d.rounded_rectangle([0, 0, S - 1, S - 1], radius=230, fill=(21, 101, 192, 255))
cx, cy, r = S // 2, int(S * 0.56), int(S * 0.33)
w = int(S * 0.075)
d.arc([cx - r, cy - r, cx + r, cy + r], start=150, end=390, fill=(255, 255, 255, 255), width=w)
d.arc([cx - r, cy - r, cx + r, cy + r], start=345, end=390, fill=(255, 167, 38, 255), width=w)
for a in range(150, 391, 30):
    t = math.radians(a); r1 = r - w - 20; r2 = r - w - 70
    d.line([cx + r1 * math.cos(t), cy + r1 * math.sin(t), cx + r2 * math.cos(t), cy + r2 * math.sin(t)],
           fill=(255, 255, 255, 200), width=18)
t = math.radians(305); L = r * 0.78
d.line([cx, cy, cx + L * math.cos(t), cy + L * math.sin(t)], fill=(255, 255, 255, 255), width=34)
d.ellipse([cx - 55, cy - 55, cx + 55, cy + 55], fill=(255, 255, 255, 255))
d.ellipse([cx - 22, cy - 22, cx + 22, cy + 22], fill=(21, 101, 192, 255))

os.makedirs('assets/icon', exist_ok=True)
im.save('assets/icon/icon_1024.png')
for px in [48, 72, 96, 144, 192]:
    im.resize((px, px), Image.LANCZOS).save(f'assets/icon/ic_launcher_{px}.png')
print('icons done')
