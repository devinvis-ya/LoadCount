# Visit Counter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a single-page visit counter with cosmic dark theme, animated stars, bot detection, and Supabase backend.

**Architecture:** One `index.html` with embedded CSS/JS calls a Supabase RPC function for atomic visit increment. Bot detection runs client-side (User-Agent + behavioral). A `setup.sql` file provisions the Supabase schema.

**Tech Stack:** HTML/CSS/JS (no build tools), Supabase JS SDK via CDN, PostgreSQL RPC function

---

## File Structure

| File | Responsibility |
|------|---------------|
| `setup.sql` | Supabase table, RPC function, RLS policies |
| `index.html` | Complete frontend: structure, styles, star canvas, counter animation, bot detection, Supabase integration |

---

### Task 1: Supabase SQL Setup

**Files:**
- Create: `setup.sql`

- [ ] **Step 1: Write the SQL setup script**

```sql
-- setup.sql
-- Run this in Supabase SQL Editor to provision the visit counter

-- 1. Create table
CREATE TABLE IF NOT EXISTS visits (
  id integer PRIMARY KEY DEFAULT 1,
  count integer NOT NULL DEFAULT 0,
  bots integer NOT NULL DEFAULT 0,
  CONSTRAINT single_row CHECK (id = 1)
);

-- 2. Insert initial row
INSERT INTO visits (id, count, bots) VALUES (1, 0, 0)
ON CONFLICT (id) DO NOTHING;

-- 3. Create atomic increment function
CREATE OR REPLACE FUNCTION increment_visits(is_bot boolean DEFAULT false)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  result json;
BEGIN
  IF is_bot THEN
    UPDATE visits SET count = count + 1, bots = bots + 1 WHERE id = 1;
  ELSE
    UPDATE visits SET count = count + 1 WHERE id = 1;
  END IF;

  SELECT json_build_object('count', v.count, 'bots', v.bots)
  INTO result
  FROM visits v WHERE v.id = 1;

  RETURN result;
END;
$$;

-- 4. Lock down direct table access, allow only RPC
ALTER TABLE visits ENABLE ROW LEVEL SECURITY;

-- Deny all direct access (anon role)
CREATE POLICY "No direct access" ON visits
  FOR ALL TO anon
  USING (false);

-- 5. Grant execute on the function to anon
GRANT EXECUTE ON FUNCTION increment_visits(boolean) TO anon;
```

- [ ] **Step 2: Commit**

```bash
git add setup.sql
git commit -m "feat: add Supabase SQL setup script for visit counter"
```

---

### Task 2: HTML Structure and CSS Styling

**Files:**
- Create: `index.html`

- [ ] **Step 1: Create index.html with full structure and styles**

Write `index.html` with:
- `<!DOCTYPE html>`, lang="en", meta viewport, title "Visit Counter"
- Supabase JS SDK CDN link: `<script src="https://cdn.jsdelivr.net/npm/@supabase/supabase-js@2"></script>`
- Embedded `<style>` block with all CSS
- HTML structure: `<canvas id="stars">`, `<div class="container">` with counter, visitor message, breakdown

CSS requirements:

```css
/* Reset */
* { margin: 0; padding: 0; box-sizing: border-box; }

/* Full viewport, dark gradient background */
body {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #0f0c29, #302b63, #24243e);
  font-family: system-ui, -apple-system, sans-serif;
  overflow: hidden;
  color: #e0e7ff;
}

/* Canvas covers full screen behind content */
#stars {
  position: fixed;
  top: 0;
  left: 0;
  width: 100%;
  height: 100%;
  z-index: 0;
}

/* Content centered above canvas */
.container {
  position: relative;
  z-index: 1;
  text-align: center;
  padding: 2rem;
}

/* Counter number — large, neon glow */
.counter {
  font-size: clamp(3rem, 10vw, 7rem);
  font-weight: 800;
  color: #e0e7ff;
  text-shadow:
    0 0 20px rgba(129, 140, 248, 0.6),
    0 0 40px rgba(129, 140, 248, 0.4),
    0 0 80px rgba(129, 140, 248, 0.2);
  cursor: pointer;
  transition: text-shadow 0.3s ease;
  /* Monospace digits to prevent layout shift during animation */
  font-variant-numeric: tabular-nums;
}

.counter:hover {
  text-shadow:
    0 0 30px rgba(129, 140, 248, 0.8),
    0 0 60px rgba(129, 140, 248, 0.5),
    0 0 100px rgba(129, 140, 248, 0.3);
}

/* Visitor message */
.visitor-msg {
  font-size: clamp(0.9rem, 2.5vw, 1.2rem);
  color: rgba(165, 180, 252, 0.6);
  margin-top: 1rem;
  letter-spacing: 0.05em;
}

/* Bot breakdown — hidden by default, revealed on hover/tap */
.breakdown {
  max-height: 0;
  overflow: hidden;
  transition: max-height 0.4s ease, opacity 0.4s ease;
  opacity: 0;
  font-size: clamp(0.8rem, 2vw, 1rem);
  color: rgba(165, 180, 252, 0.45);
  margin-top: 0.5rem;
}

.breakdown.visible {
  max-height: 3rem;
  opacity: 1;
}

/* Loading state */
.counter.loading {
  animation: pulse 1.5s ease-in-out infinite;
}

@keyframes pulse {
  0%, 100% { opacity: 0.4; }
  50% { opacity: 0.7; }
}
```

HTML body structure:

```html
<canvas id="stars"></canvas>
<div class="container">
  <div class="counter loading" id="counter">...</div>
  <div class="visitor-msg" id="visitor-msg"></div>
  <div class="breakdown" id="breakdown"></div>
</div>
```

- [ ] **Step 2: Open in browser and verify layout**

Open `index.html` in a browser. Verify:
- Dark gradient background fills viewport
- "..." text centered with pulsing animation
- No scrollbars, no overflow
- Resize to mobile width — text scales down smoothly

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: add HTML structure and CSS for visit counter page"
```

---

### Task 3: Star Particles Canvas Animation

**Files:**
- Modify: `index.html` (add `<script>` block before closing `</body>`)

- [ ] **Step 1: Add star particles script**

Add this script inside `index.html` at the end of `<body>`, inside a `<script>` tag:

```javascript
// === Star Particles ===
(function initStars() {
  const canvas = document.getElementById('stars');
  const ctx = canvas.getContext('2d');
  let stars = [];
  const STAR_COUNT = 200;

  function resize() {
    canvas.width = window.innerWidth;
    canvas.height = window.innerHeight;
  }

  function createStars() {
    stars = [];
    for (let i = 0; i < STAR_COUNT; i++) {
      stars.push({
        x: Math.random() * canvas.width,
        y: Math.random() * canvas.height,
        radius: Math.random() * 1.5 + 0.5,
        speed: Math.random() * 0.3 + 0.1,
        twinkleSpeed: Math.random() * 0.02 + 0.005,
        twinkleOffset: Math.random() * Math.PI * 2,
      });
    }
  }

  function draw(time) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    for (const star of stars) {
      const opacity = 0.4 + 0.6 * Math.sin(time * star.twinkleSpeed + star.twinkleOffset);
      ctx.beginPath();
      ctx.arc(star.x, star.y, star.radius, 0, Math.PI * 2);
      ctx.fillStyle = `rgba(224, 231, 255, ${opacity})`;
      ctx.fill();

      // Slow drift upward
      star.y -= star.speed;
      if (star.y < -star.radius) {
        star.y = canvas.height + star.radius;
        star.x = Math.random() * canvas.width;
      }
    }
    requestAnimationFrame(draw);
  }

  window.addEventListener('resize', () => { resize(); createStars(); });
  resize();
  createStars();
  requestAnimationFrame(draw);
})();
```

- [ ] **Step 2: Open in browser and verify stars**

Open `index.html`. Verify:
- Stars visible on background, slowly drifting upward
- Twinkling effect visible
- Resize window — stars recalculate positions, no glitches

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: add animated star particles canvas background"
```

---

### Task 4: Counter Animation (Count-Up Effect)

**Files:**
- Modify: `index.html` (add to `<script>` block)

- [ ] **Step 1: Add counter animation function**

Add after the star particles IIFE:

```javascript
// === Counter Animation ===
function animateCounter(element, target, duration) {
  const start = performance.now();
  const format = (n) => n.toLocaleString('en-US');

  function step(now) {
    const elapsed = now - start;
    const progress = Math.min(elapsed / duration, 1);
    // Ease-out cubic
    const eased = 1 - Math.pow(1 - progress, 3);
    const current = Math.round(eased * target);
    element.textContent = format(current);
    if (progress < 1) {
      requestAnimationFrame(step);
    }
  }

  requestAnimationFrame(step);
}
```

- [ ] **Step 2: Add a temporary test call to verify animation**

Add temporarily at end of script:

```javascript
// TEMP: test animation — remove after verifying
const counterEl = document.getElementById('counter');
counterEl.classList.remove('loading');
animateCounter(counterEl, 1247893, 2000);
document.getElementById('visitor-msg').textContent = 'You are visitor #1,247,893';
```

- [ ] **Step 3: Open in browser and verify animation**

Open `index.html`. Verify:
- Number counts up from 0 to 1,247,893 over ~2 seconds
- Easing effect visible (starts fast, slows at end)
- Numbers formatted with commas
- Visitor message appears below

- [ ] **Step 4: Remove temporary test call**

Remove the `// TEMP` block added in Step 2.

- [ ] **Step 5: Commit**

```bash
git add index.html
git commit -m "feat: add count-up animation for visit counter"
```

---

### Task 5: Bot Detection

**Files:**
- Modify: `index.html` (add to `<script>` block)

- [ ] **Step 1: Add bot detection logic**

Add after the counter animation function:

```javascript
// === Bot Detection ===
function detectBot() {
  return new Promise((resolve) => {
    // Level 1: User-Agent check
    const ua = navigator.userAgent.toLowerCase();
    const botPatterns = [
      'bot', 'crawl', 'spider', 'slurp', 'ia_archiver',
      'facebookexternalhit', 'twitterbot', 'linkedinbot',
      'whatsapp', 'telegrambot', 'googlebot', 'bingbot',
      'yandexbot', 'baiduspider', 'duckduckbot', 'semrush',
      'ahrefs', 'mj12bot', 'dotbot', 'petalbot',
    ];
    if (botPatterns.some((p) => ua.includes(p))) {
      resolve(true);
      return;
    }

    // Level 2: Behavioral check — wait 3 seconds for interaction
    let isHuman = false;
    const events = ['mousemove', 'touchstart', 'scroll', 'keydown'];

    function onInteraction() {
      isHuman = true;
      events.forEach((e) => window.removeEventListener(e, onInteraction));
    }

    events.forEach((e) => window.addEventListener(e, onInteraction, { once: true }));

    setTimeout(() => {
      events.forEach((e) => window.removeEventListener(e, onInteraction));
      resolve(!isHuman);
    }, 3000);
  });
}
```

- [ ] **Step 2: Commit**

```bash
git add index.html
git commit -m "feat: add two-level bot detection (UA + behavioral)"
```

---

### Task 6: Supabase Integration and Main Flow

**Files:**
- Modify: `index.html` (add to `<script>` block)

- [ ] **Step 1: Add Supabase initialization and main flow**

Add after bot detection function:

```javascript
// === Supabase Init ===
// Replace these with your Supabase project credentials
const SUPABASE_URL = 'YOUR_SUPABASE_URL';
const SUPABASE_ANON_KEY = 'YOUR_SUPABASE_ANON_KEY';

const supabase = window.supabase.createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// === Main Flow ===
(async function main() {
  const counterEl = document.getElementById('counter');
  const visitorMsg = document.getElementById('visitor-msg');
  const breakdownEl = document.getElementById('breakdown');

  // Start bot detection immediately (runs in parallel with any setup)
  const isBotPromise = detectBot();

  // Wait for bot detection result
  const isBot = await isBotPromise;

  // Call Supabase RPC — atomic increment
  const { data, error } = await supabase.rpc('increment_visits', { is_bot: isBot });

  if (error) {
    console.error('Supabase error:', error);
    counterEl.textContent = ':(';
    counterEl.classList.remove('loading');
    visitorMsg.textContent = 'Could not load visit count';
    return;
  }

  const totalCount = data.count;
  const botCount = data.bots;
  const peopleCount = totalCount - botCount;

  // Animate counter
  counterEl.classList.remove('loading');
  animateCounter(counterEl, totalCount, 2000);

  // Show visitor message after animation completes
  setTimeout(() => {
    visitorMsg.textContent = `You are visitor #${totalCount.toLocaleString('en-US')}`;
  }, 2100);

  // Store breakdown data for hover/tap reveal
  breakdownEl.textContent = `People: ${peopleCount.toLocaleString('en-US')} · Bots: ${botCount.toLocaleString('en-US')}`;
})();
```

- [ ] **Step 2: Add hover/tap interaction for breakdown reveal**

Add after the main IIFE:

```javascript
// === Breakdown Reveal ===
(function initBreakdown() {
  const container = document.querySelector('.container');
  const breakdown = document.getElementById('breakdown');

  // Desktop: hover
  container.addEventListener('mouseenter', () => {
    breakdown.classList.add('visible');
  });
  container.addEventListener('mouseleave', () => {
    breakdown.classList.remove('visible');
  });

  // Mobile: tap toggle
  container.addEventListener('click', () => {
    breakdown.classList.toggle('visible');
  });
})();
```

- [ ] **Step 3: Commit**

```bash
git add index.html
git commit -m "feat: integrate Supabase RPC, wire up counter display and breakdown"
```

---

### Task 7: Manual End-to-End Test

- [ ] **Step 1: Set up Supabase project**

1. Go to supabase.com, create a new project
2. Open SQL Editor, paste contents of `setup.sql`, run it
3. Go to Settings → API, copy the Project URL and anon key
4. In `index.html`, replace `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` with actual values

- [ ] **Step 2: Test in desktop browser**

Open `index.html` in browser. Verify:
- Stars animate on background
- Counter animates from 0 to 1
- Visitor message shows "You are visitor #1"
- Hover over counter area — breakdown appears smoothly ("People: 1 · Bots: 0")
- Move mouse away — breakdown hides

- [ ] **Step 3: Refresh to test increment**

Refresh the page. Verify:
- Counter now shows 2
- Visitor message: "You are visitor #2"

- [ ] **Step 4: Test mobile responsiveness**

Open browser DevTools, toggle device toolbar (mobile view). Verify:
- Layout fits screen, no horizontal scroll
- Text scales down appropriately
- Tap on counter area toggles breakdown
- Stars animate smoothly

- [ ] **Step 5: Test bot detection**

Open DevTools → Network Conditions → set User Agent to "Googlebot/2.1". Refresh. Verify:
- Counter increments
- Breakdown shows bot count increased

- [ ] **Step 6: Commit final version (with placeholder keys restored)**

Before committing, restore placeholder values:

```bash
# Make sure real keys are NOT committed
```

Replace actual Supabase credentials back with `YOUR_SUPABASE_URL` and `YOUR_SUPABASE_ANON_KEY` in `index.html`.

```bash
git add index.html
git commit -m "feat: complete visit counter with bot detection and cosmic theme"
```
