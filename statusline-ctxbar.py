#!/usr/bin/env python3
"""Usage bars for statusline-command.sh: value-locked gradient, half-cell colour samples, round Nerd Font caps,
steady head bloom. One process renders every bar at every requested width.

usage: statusline-ctxbar.py [--theme NAME] [--bg dark|light] [--widths 10,6,3] P [P ...]
  prints one line per (width, P): "<bar> <pct>%" with ANSI colours, or an empty line for an empty/invalid P.
  Lines come width-major: all P for the first width, then all P for the next width."""
import sys, math, colorsys

# Gradient stops per theme: (percent, hue in degrees, saturation, lightness). Hues are interpolated along the
# shortest arc, so a stop at 355 after one at 10 stays on the warm side instead of sweeping through green and blue.
THEMES = {
    "sorbet": dict(pal=[(0, 190, .90, .56), (30, 204, .92, .60), (60, 223, .93, .65), (78, 240, .92, .69),
                        (84, 262, .90, .70), (100, 284, .88, .68)], track=(38, 44, 58), bloom=(245, 250, 255)),
    "ember":  dict(pal=[(0, 48, .90, .62), (30, 38, .92, .62), (60, 24, .90, .62), (78, 10, .88, .60),
                        (84, 355, .85, .58), (100, 340, .80, .55)], track=(54, 40, 34), bloom=(255, 244, 230)),
    "sunset": dict(pal=[(0, 50, .95, .62), (30, 38, .95, .62), (60, 20, .92, .62), (78, 0, .90, .62),
                        (84, 345, .88, .60), (100, 325, .80, .58)], track=(52, 36, 44), bloom=(255, 240, 238)),
}
# On a light background the empty track is pale and the head "bloom" darkens instead of whitening
LIGHT = dict(track=(222, 226, 234), bloom=(60, 66, 84))
RST = "\x1b[0m"
LCAP, RCAP = "", ""

def fg(c): return f"\x1b[38;2;{c[0]};{c[1]};{c[2]}m"
def bg(c): return f"\x1b[48;2;{c[0]};{c[1]};{c[2]}m"
def clamp(x, a=0.0, b=1.0): return max(a, min(b, x))
def mix(a, b, t):
    t = clamp(t); return tuple(round(a[k] + (b[k] - a[k]) * t) for k in range(3))

def val(pal, pct):
    pct = clamp(pct, 0, 100)
    for (p0, h0, s0, l0), (p1, h1, s1, l1) in zip(pal, pal[1:]):
        if pct <= p1:
            t = (pct - p0) / (p1 - p0)
            dh = (h1 - h0 + 180) % 360 - 180            # shortest arc
            r, g, b = colorsys.hls_to_rgb(((h0 + dh * t) % 360) / 360, l0 + (l1 - l0) * t, s0 + (s1 - s0) * t)
            return (round(r * 255), round(g * 255), round(b * 255))

def render(p, W, pal, track, bloom):
    exact = p / 100 * W
    pulse = 0.30                                      # steady head bloom
    pix = []
    for j in range(2 * W):
        xc = (j + 0.5) / 2
        base = val(pal, xc / W * 100)
        c = base
        if xc <= exact + 1: c = mix(c, bloom, pulse * math.exp(-((xc - exact) / 1.2) ** 2))
        g = mix(track, base, 0.20)
        if xc > exact: g = mix(g, base, 0.8 * pulse * math.exp(-((xc - exact) / 1.8) ** 2))
        pix.append(mix(g, c, clamp((exact - (xc - 0.25)) / 0.5)))
    body = "".join(fg(pix[2 * i]) + bg(pix[2 * i + 1]) + "▌" + RST for i in range(W))
    return fg(pix[0]) + LCAP + RST + body + fg(pix[-1]) + RCAP + RST

def main(argv):
    theme, light, widths, vals = "sorbet", False, [10], []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a == "--theme" and i + 1 < len(argv): theme = argv[i + 1]; i += 2
        elif a == "--bg" and i + 1 < len(argv): light = argv[i + 1] == "light"; i += 2
        elif a == "--widths" and i + 1 < len(argv):
            try: widths = [max(3, int(w)) for w in argv[i + 1].split(",") if w]
            except ValueError: pass
            i += 2
        else: vals.append(a); i += 1
    th = THEMES.get(theme, THEMES["sorbet"])
    pal = th["pal"]
    track = LIGHT["track"] if light else th["track"]
    bloom = LIGHT["bloom"] if light else th["bloom"]
    for W in widths:
        for a in vals:
            try: p = clamp(float(a), 0, 100)
            except ValueError: print(); continue
            print(f"{render(p, W, pal, track, bloom)} {fg(val(pal, p))}{round(p)}%{RST}")

if __name__ == "__main__":
    main(sys.argv[1:])
