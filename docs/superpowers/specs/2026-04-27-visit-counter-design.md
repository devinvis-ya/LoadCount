# Visit Counter — Design Spec

## Overview

Single-page website that displays a visit counter with bot/human breakdown. Dark cosmic theme with animated star particles and neon glow effects. Mobile-responsive.

## Tech Stack

- **Frontend:** Single `index.html` file (HTML/CSS/JS, no build tools)
- **Backend:** Supabase (PostgreSQL) — free tier
- **Supabase JS SDK:** via CDN

## Supabase Schema

### Table: `visits`

| Column | Type    | Default | Description              |
|--------|---------|---------|--------------------------|
| id     | integer | 1       | Primary key (single row) |
| count  | integer | 0       | Total visit count        |
| bots   | integer | 0       | Bot visit count          |

### RPC Function: `increment_visits(is_bot boolean)`

- Atomically increments `count` by 1
- If `is_bot = true`, also increments `bots` by 1
- Returns both `count` and `bots` values
- Uses `UPDATE ... SET count = count + 1` for atomicity at DB level

## Bot Detection (Two-Level)

1. **User-Agent check (immediate):** Match against known bot patterns: `Googlebot`, `bingbot`, `crawl`, `spider`, `bot`, `slurp`, `ia_archiver`, `facebookexternalhit`, `Twitterbot`, etc. If matched — classified as bot immediately.
2. **Behavioral check (3-second delay):** If User-Agent is clean, wait 3 seconds. Listen for `mousemove`, `touchstart`, `scroll`, `keydown`. If no interaction detected — classify as bot.
3. **Increment timing:** For UA-detected bots, increment is sent immediately. For behavioral detection, increment is sent after the 3-second window.

## Visual Design

### Background
- Dark gradient: `#0f0c29` → `#302b63` → `#24243e`
- Animated star particles rendered on a full-screen `<canvas>` element
- Stars slowly drift and twinkle

### Counter Display (Center of Page)
- Large number with neon glow effect (`text-shadow` with purple/blue glow)
- Animation: number "counts up" from 0 to current value on page load (easing, ~2 seconds)
- Font: system-ui, bold weight
- Color: light (#e0e7ff) with glow shadows in `rgba(129, 140, 248, ...)`

### Visitor Message
- Below the counter: "You are visitor #N"
- Subtle, smaller text in muted purple

### Bot Breakdown (Interactive)
- On hover (desktop) or tap (mobile) on the counter area — smoothly reveals breakdown:
  - "People: N / Bots: N"
- CSS transition for smooth expand/collapse
- Muted styling, doesn't compete with the main number

### Mobile Adaptation
- Font sizes use `clamp()` for fluid scaling
- Canvas particles adapt to screen dimensions
- Tap interaction for bot breakdown (instead of hover)
- No horizontal scroll, full-viewport layout

## File Structure

```
index.html    — complete frontend (HTML + embedded CSS + JS)
setup.sql     — SQL script for Supabase table + function setup
```

## Setup Flow (Manual)

1. Create a Supabase project at supabase.com
2. Run `setup.sql` in Supabase SQL Editor
3. Copy project URL and anon key into `index.html`
4. Deploy `index.html` to any static hosting

## Security Considerations

- Supabase anon key is public (by design) — Row Level Security allows only RPC function execution
- No direct table read/write from client — only through the RPC function
- Bot detection is best-effort, not security-critical
