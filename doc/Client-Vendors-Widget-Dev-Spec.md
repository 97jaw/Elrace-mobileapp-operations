# Client & Vendors — Home Widget Cards (Stacked Hero, Option 1a)
Spec for Flutter implementation. Category is visible to **Management role only**.

## Card shape & layout (applies to all 3 cards)
- Border radius: **26px**
- Padding: **20px**
- Margin between cards: **14px** vertical gap; last card **20px** bottom margin
- Card width: full bleed minus **20px** side margins (screen padding)
- Position: `relative`, `overflow: hidden` (so background art is clipped to rounded corners)
- Text color base: white (`#FFFFFF`)
- Stack order top→bottom: **Client → Vendor → Sub-Contractor**

---

## 1. CLIENT card
**Background gradient:** 160° linear gradient, `#2FD5A17A → #003D4E` (teal/emerald → deep navy-teal)

**Background image:** `assets/uae-emblem-cutout.png` (source 1034×1332px, transparent cutout)
- Position: absolute, right: `6px`, vertically centered
- Rendered height: `194px`, width: `173px`
- Opacity: `0.25`
- Fade: left edge masked with linear-gradient fade (transparent 0%–8%, solid from 40%), angle 115° — i.e. image fades into the card gradient on its left side, fully visible near the right edge
- object-fit: contain, non-interactive (pointer-events: none)

**Content (top row):**
- Label "CLIENTS": `11px`, weight `800`, letter-spacing `0.08em`, color `#09580BB9` (dark green, semi-transparent — sits on lighter part of gradient)
- Metric "71 Active": `21px` weight `800` white (`#fff`) for the number; "Active" nested at `14px` weight `600`, same white

**Content (stats row, margin-top 16px, gap 22px):**
- "RECEIVABLES" label: `10px`, `rgba(255,255,255,0.55)`, letter-spacing `0.05em`
- Value "AED 3.66M": `19px` weight `800`
- Divider: `1px solid rgba(255,255,255,0.15)` left border, `22px` left padding
- "TOP CLIENT" label: same style as Receivables label
- Value "AED 890K": `15px` weight `700`

**Footer risk line** (margin-top 14px, `12.5px` weight `600`):
- "▲ 12 overdue invoices" in `#FCA5A5` (soft red)
- separator " · "
- "2 agreements expiring" in `#FDE68A` (soft amber)

---

## 2. VENDOR card
**Background gradient (base):** 160° linear gradient, `#252A6B → #100F30` (deep indigo → near-black)

**Overlay wash (sits above base, below image):** full-card linear-gradient `180°, #F2ECEEE1 → #977DFF7D` (near-white → violet, both semi-transparent) — softens/lightens the indigo base
- Contains one decorative circle: `100px × 100px`, border-radius `50%`, `80px` border width, border color `#73080823` (dark red, very transparent), positioned `left:270px; top:48px`

**Background image:** `assets/dubai-skyline-cutout.png` (source 600×600px, transparent cutout)
- Position: absolute, right: `-28px`, vertically centered
- Rendered height: `135%` of card, width auto (object-fit: contain)
- Opacity: `0.11`
- Same left-edge fade mask as Client card (115°, transparent 0–8%, solid from 40%)

**Content (top row):**
- Label "VENDORS & SUPPLIERS": `11px` weight `800`, letter-spacing `0.08em`, color `#3E50A8` (indigo)
- Metric "58 Active": number `21px` weight `800` white; "Active" `14px` weight `600` white

**Stats row:**
- "PAYABLES" label + "AED 2.1M" value — same sizing pattern as Client (10px label / 19px 800 value)
- Divider, then "OPEN LPO" + "AED 6.7M" (15px weight 700)

**Footer risk line** (`12.5px` weight `600`):
- "▼ 65% LPO value" in `#C7D2FE` (light indigo)
- "4 invoices pending approval" in `#FDE68A` (amber)

---

## 3. SUB-CONTRACTOR card
**Background gradient (base):** 160° linear gradient, `#7C2D12 → #3A1206` (rust/copper → dark brown)

**Overlay wash:** full-card linear-gradient `180°, #736A86 → #C8CED6DE` (muted purple-grey → light grey, semi-transparent), layered over a `14px × 14px` radial-dot texture (`rgba(255,255,255,0.08)` dots, 1px radius) — gives a subtle site/texture pattern under the lightening wash

**Background image:** `assets/crane-worker-cutout.png` (source 736×736px, transparent cutout)
- Position: absolute, right: `-41px`, top: `93px` (offset, not perfectly centered), transform translateY(-50%)
- Rendered height: `199px`, width: `216px`
- Opacity: `0.3`
- Same left-edge fade mask (115°, transparent 0–8%, solid from 40%)

**Content (top row):**
- Label "SUB-CONTRACTORS": `11px` weight `800`, letter-spacing `0.08em`, color `#FDBA74` (light orange)
- Metric "34 Active": number `21px` weight `800` white; "Active" `14px` weight `600` white

**Stats row:**
- "RETENTION HELD" + "AED 540K" (10px label / 19px 800 value)
- Divider, then "MR PENDING" + "9" (15px weight 700)

**Footer risk line** (`12.5px` weight `600`, color `#FED7AA` light peach):
- "⚠ 1 agreement expiring in 15 days"

---

## Background image assets to hand off
Provide these 3 PNGs to the dev (transparent background, already cut out):
1. `uae-emblem-cutout.png` — 1034×1332px — Client card (UAE emblem/eagle)
2. `dubai-skyline-cutout.png` — 600×600px — Vendor card (skyline motif)
3. `crane-worker-cutout.png` — 736×736px — Sub-Contractor card (construction/crane motif)

All three should be exported as **@1x/@2x/@3x** (or a single high-res PNG ≥2x target render size, e.g. ~450×450 minimum) for Flutter's `Image.asset` with `fit: BoxFit.contain`, since they're rendered small (~170–220px) but need to stay crisp on high-DPI phones.

## Flutter build notes
- Each card = a `Container` / `ClipRRect(borderRadius: 26)` with a `Stack`:
  1. Gradient background (`BoxDecoration.gradient`)
  2. Optional overlay wash gradient (Vendor & Sub-Contractor only)
  3. Background image `Positioned` + `ShaderMask` (or `Opacity` + a horizontal gradient mask) to replicate the left-fade — `ShaderMask` with a `LinearGradient` (`Alignment.centerLeft → Alignment.centerRight`, stops `[0.0, 0.08, 0.40, 1.0]`, colors transparent→transparent→opaque→opaque) is the closest Flutter equivalent of the CSS mask.
  4. Foreground content column (labels, metric, stats row, footer line) — all in a `Padding(20)` on top of the stack.
- Card metric row ("71" + "Active") = `Text.rich` with two `TextSpan`s of different `fontSize`/`fontWeight`, both white.
- Tap target: whole card wrapped in `InkWell`/`GestureDetector` → navigates to that entity's category-detail screen (already scoped in Turn 2 of the design file — list+stats → quick-profile sheet → Documents & Reports).
