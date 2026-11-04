# The look and the sound — style sheet

*Javier & Claude, started 2026-11-03 (Javier: "move forward please"). The rules every picture and sound follows. The
prompts that ask ChatGPT for them are in `docs/PROMPTS.md`; the free drafts that test them are on the Dailies page.
Nothing here is final until Javier picks: the three style frames are the first pick.*

## The idea in one line
**A neon night that slowly goes out.** Level 1 is bright signs on wet streets; each level turns the lights down and the
grime up, until level 10 is rust, smoke and red light (the design, "The look").

## The screen
- 1920 × 1080, drawn side-on and flat. The street is the bottom third; the fighters stand on it.
- A standing fighter is about **320 px tall** (a third of the screen). Every part is drawn at that size or larger,
  never upscaled.
- **No perspective in the backgrounds** (Karatecation, L-3): every layer is drawn straight side-on, so it can tile and
  scroll. Depth comes from the layers and from haze, not from vanishing lines.

## The layers (back to front)
| # | Layer | Scrolls at | What's on it |
|---|---|---|---|
| 1 | sky | 0 (fixed) | the night sky, a glow from the city, smoke later on |
| 2 | far city | 0.15 | skyline cut-outs, tiny lit windows, a hazy colour |
| 3 | mid buildings | 0.45 | the block across the street: signs, fire escapes, shutters |
| 4 | the street's back wall | 0.8 | shopfronts and doors right behind the fighters |
| 5 | the street | 1.0 | the walking surface: wet asphalt, puddles, kerb, props |
| 6 | foreground | 1.25 | a lamppost, a railing, steam: passes in front, never covers a fight for long |

Each layer is a wide strip made of **tiles no wider than 2048 px** (the GPU limit, L-7) that join seamlessly left to right.

## The fighters
- **Cut-out parts** on the 21 bones (D-20): head, neck, chest, belly, upper and lower arms, hands (fist and open),
  thighs, shins, feet, toes. Each part is its own picture with a little overlap at the joints so no gap shows when it
  bends.
- Drawn **side-on**, facing right. The game mirrors them to face left.
- **Shading: two tones plus a rim light.** Every part has a lit tone and a shadow tone (the "slight 3D feel"), and a
  thin **rim of the level's neon colour** on the edge facing the signs. The rim is what ties a fighter to the street:
  magenta and cyan in level 1, sodium orange later, red at the end.
- **Outline:** decided by the style frame Javier picks (A has a bold dark outline, B none, C a broken comic line).
- **Damage stages, every part** (D-9, no blood ever): fresh → bruised (purple-yellow patches) → swollen (the shape
  puffs out, an eye closes) → broken (the arm or leg hangs at a wrong angle, a bandage-free crack line). The game swaps
  the part's picture as health drops.
- The two heroes (a man and a woman) and the enemies share one body plan, so every move fits every fighter.

## Colour by level (neon to grit)
Working names for the places; Javier names them for real. Saturation drops level by level (100% → about 35%).

| Level | Place (working) | Sky | Signs / light | Street | Feel |
|---|---|---|---|---|---|
| 1 | Neon Row | `#1b1035` indigo | `#ff3ea5` magenta, `#2de2e6` cyan | `#23202f` wet, mirror puddles | bright, fun, rain |
| 2 | the market alley | `#1a1a33` | `#ffb347` amber, `#2de2e6` cyan | `#262330` | busy, steam from stalls |
| 3–5 | the docks and warehouses | `#141c2a` steel blue | `#ff9b3d` sodium orange, few signs | `#22252b` | fog, cranes, fewer people |
| 6–8 | the factory district | `#1c1d17` olive dark | `#c8d36a` sick green, `#ff7a2f` | `#24221d` oily | rust, sparks, broken signs |
| 9 | the tower | `#16161a` concrete | `#ff3b30` emergency red | `#2a2a2e` tiles | stairs, cold light |
| 10 | the top | `#1a0f0d` smoke | `#e0402a` red, embers | `#2b1c18` | rust, smoke, red light |

The fighters' clothes stay the same through the game; only the light on them changes. That way the darkening reads as
the city, not the hero.

## The sound
- **Music:** electronic, gritty and beat-driven, **no singing**. Built the Karatecation way for $0: our own notes,
  every instrument made from scratch by our own script (no samples, no paid tool). Level 1 is the brightest cue
  (faster, a major lift in the hook); later levels slow down, drop the bright lead and grow the bass and noise.
  Every cue loops cleanly so a long fight never hits silence.
- **Sound effects:** short and punchy, a few versions each so repeats don't sound robotic. Hits get a body thud and a
  slap; heavier blows add a low boom. **Pain is heard, never bled** (D-9): grunts and cracks come with the pain system.
- Loudness: music peaks at -1 dB and sits under the effects; effects are the loudest thing in a fight.
- Format: Ogg Vorbis, 48 kHz.

## How a piece gets in
1. Made (free draft by our script, or a ChatGPT batch after Javier's yes with the count and cost written first).
2. On the Dailies page, one card each.
3. Javier approves or sends it back with a note. Only approved pieces go into the game (`assets/`, CC BY-SA 4.0).
