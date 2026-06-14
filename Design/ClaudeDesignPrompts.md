# Claude Usage, design prompt pack

A complete set of paste ready prompts for designing every screen, component, and flow of the app. Each prompt is self contained. Prepend the Design System block (Section 0) to any single prompt before you send it, so the design comes back on system.

Every prompt is grounded in real user demand (researched from Reddit, the Anthropic forum, Hacker News, GitHub issues, and App Store reviews):

1. People want an ambient fuel gauge they never have to open. Glance and know.
2. Warn me before the wall. Threshold and pace alerts, no surprise lockouts.
3. Three separate gauges, never one bar: 5 hour session, weekly all models, weekly Opus sub limit. Each with its own reset countdown.
4. Lead with the forecast and pace, not just the number. "You are fine until reset" is the calming default.
5. Show Opus vs Sonnet, with an action ("switch to Sonnet to preserve Opus").
6. Trust: honest numbers, a freshness stamp, and a clear stale or disconnected state.
7. Traffic light color, zero setup, private, lightweight.

Our wedge vs the competition: everything free, no in app purchase, and a fully standalone app on every device (each device signs in directly, so data is never stale and nothing leaves the device).

How to use this file: copy Section 0, then copy the one component prompt you want, paste both into Claude (or any design AI), and ask for either a high fidelity visual mockup or production SwiftUI, your call. Tell it the target platform if the component has variants.

---

## 0. Design System (prepend this to every component prompt)

You are designing a native Apple platform app called "Claude Usage," a free, private tool that shows a Claude subscriber their live usage limits at a glance. It is informational only. Use this design system exactly.

Brand and mood: calm, humane, trustworthy, modern. It borrows Anthropic's warmth (a soft clay coral accent, rounded forms, generous breathing room) and executes it as a sleek dark, glass forward interface. The feeling is a quiet fuel gauge, not a busy dashboard. Reduce anxiety, never add to it.

Platforms: macOS 14 and later (menu bar app plus a window), iOS 17 and later, iPadOS 17 and later. SwiftUI. Use Liquid Glass (the glassEffect material) on macOS 26 and iOS 26, and fall back to ultraThinMaterial on macOS 14 and iOS 17.

Color tokens (dark, the default theme):
- Background: a near black charcoal vertical gradient from #0F0F12 at the top to #08080A at the bottom.
- Glass surface: translucent white at about 7 percent over the background, with a 1px hairline border in white at 8 percent. On OS 26 use glassEffect for cards.
- Ink (primary text): warm white #F5F4F2.
- Ink secondary: warm gray #B7B4AF at about 75 percent.
- Ink tertiary: warm gray at about 45 percent.
- Accent (Claude clay coral): #D97757. Use for the primary call to action, active states, the brand arc, and links. Use sparingly.
- Health, traffic light, applied by utilization percent:
  - Safe, under 70 percent: green #4FD37E.
  - Caution, 70 to 90 percent: amber #FFB84D.
  - Danger, over 90 percent: red #FF6B6B.
  - Gauges may use a subtle gradient along the arc in the current health color, with a soft outer glow in that color.
- Pace marker: a thin tick in white at 60 percent, drawn on a gauge or bar to show how far through the time window you are.

Typography:
- Big numbers (the percent in a gauge): SF Rounded, bold.
- Headings: SF Pro, semibold.
- Body and captions: SF Pro.
- Use monospaced digits for any number that updates, and a numeric content transition when it changes.
- Support Dynamic Type. Never hard cap text size in a way that clips.

Shape and depth:
- Corner radius: cards 20, small tiles 14, pills fully rounded.
- Soft, low shadows. The only glow is the health colored glow on an active gauge.
- Keep borders subtle. Let the glass and spacing do the work.

Spacing scale: 4, 8, 12, 16, 20, 24. Card padding 16 to 20. Comfortable, airy, never cramped.

Motion: gentle. Animate value changes with a snappy spring. Respect Reduce Motion (cross fade instead of move, no looping motion).

Accessibility: every gauge and bar needs a text label and value for VoiceOver. Color is never the only signal (pair red with an icon or word). Meet contrast on the dark background. Support Dynamic Type and Reduce Motion.

Content and tone rules:
- Three usage windows, always distinct: "Session" (the rolling 5 hour limit), "Weekly" (all models), and "Opus weekly" (the Opus only sub limit). Never merge them into one bar.
- Reset times come from the data field resets_at. Always show the real reset time. Never compute or imply a fixed weekly anchor like "every Monday."
- Any cost or "hours left" value is an estimate. Label it as an estimate. Many users pay a flat fee and dislike seeing per token costs shown as if billed.
- Lead with meaning. Prefer "You are on track, weekly resets in 3 days" over a bare "62 percent."
- Writing style: never use dashes of any kind. No em dash, no en dash, no hyphen as punctuation or separator. Use commas, periods, or separate sentences.

Deliverable, unless told otherwise: a polished mockup for the stated platform and size, in the dark theme, with realistic sample data, showing the default state plus any states the prompt lists.

---

## 1. Onboarding flow (first launch, before sign in)

Context: prepend Section 0. A brand new user opens the app and has not signed in. We need to earn a sign in by naming the pain and proving the privacy model, fast. The competitor's worst reviews are about a paywall and stale data, so we lead with free and private.

Goal: a short, confident onboarding that converts to "Sign in to Claude." One scroll on iPhone, a centered column on Mac. Calm, not salesy.

Content and structure, top to bottom:
1. Hero: a single elegant gauge ring at about 62 percent in the clay accent, with the headline "Never get blindsided by your Claude limits" and a one line subhead naming the surfaces ("See your 5 hour and weekly usage, when it resets, and your extra credit balance, at a glance in the menu bar, on your Home Screen, and Lock Screen").
2. Four feature rows, each an icon plus a tight title and one line:
   - Know how much is left. Live 5 hour and weekly limits before you hit the wall.
   - Know when it resets. Exact reset times so you can plan your day.
   - See if you are on pace. A simple ahead or behind read, not just a number.
   - Get warned early. A nudge before you hit a limit, and a ping when it resets.
3. A "Private by design" card with a lock shield icon and three checked lines: you sign in on Claude's own page so the app never sees your password, your data stays on this device with no servers, your session is stored only in this device's Keychain.
4. Primary button "Sign in to Claude" (clay, prominent, large). Under it, small text: "Pro and Max plans. Team, Enterprise, and Google sign in are not supported."
5. Footer disclaimer, tertiary text, centered: "An independent app. Not affiliated with or endorsed by Anthropic."

States to show: the default screen. Also show the button in a pressed state.

Platforms: iPhone (full screen scroll), Mac (centered column max width about 460 inside a resizable window). The Mac version should feel at home in a window, not stretched.

Accessibility: large readable type, VoiceOver labels on the feature icons, the gauge has a label.

Deliverable: the full onboarding screen for both iPhone and Mac, dark theme.

---

## 2. Sign in sheet (web login wrapper)

Context: prepend Section 0. Tapping "Sign in to Claude" presents a sheet that hosts Claude's real login web page (email plus verification code) inside a web view. We only design the chrome around that web view, not Claude's page itself. When the session cookie is captured the sheet closes itself.

Goal: a trustworthy, minimal frame that makes it obvious the user is signing in on Claude's own page, with a graceful manual fallback.

Content and structure:
- A top bar: "Cancel" on the left, a centered title "Sign in to Claude," and "Done" on the right (semibold). Done is the manual fallback if auto capture does not fire.
- The web view fills the middle.
- A thin status line at the bottom in caption text. Default copy: "Sign in with the email you use for claude.ai." After Done is tapped while not yet signed in: "Not signed in yet. Finish signing in to Claude above, then tap Done." During capture: "Just a moment."
- A subtle reassurance row above or below the web view: a small lock icon plus "This is Claude's official page. We never see your password."

States to show: default (prompting sign in), capturing (brief spinner in the status line), and the not yet signed in nudge.

Platforms: iPhone (full height sheet), Mac (a sheet about 460 by 640).

Deliverable: the sign in sheet chrome for iPhone and Mac, with the three status states.

---

## 3. First data load and core empty states

Context: prepend Section 0. Right after sign in, the first fetch is in flight, so there is no real data yet. We must never show fake sample numbers. We also need a clean look for the rare "could not reach Claude" case.

Goal: honest, calm placeholders that feel intentional, not broken.

Design these states:
1. Loading the first time: the dashboard frame with the limits card showing "Loading your limits" next to a soft gauge glyph, and a one line hint "This takes a second." No fake percentages anywhere.
2. Could not reach Claude (offline, or session expired): a friendly inline banner at the top in amber, "Could not reach Claude. Your session may have expired. Open Settings to sign in again." Tapping it opens Settings. Below it, the rest of the dashboard shows the last known values if we have them, each clearly marked as stale (see the freshness component), or the loading placeholder if we have nothing.
3. Stale data: when we are showing the last successful fetch because the newest one failed, show a small "Showing last known limits" note with the age.

States to show: all three.

Platforms: iPhone and Mac.

Deliverable: the three states, dark theme.

---

## 4. Main dashboard (the heart of the app)

Context: prepend Section 0. This is the primary screen, shown once the user is signed in and we have live data. It is the calm fuel gauge people open instead of digging into claude.ai settings. Lead with meaning and pace, not raw numbers.

Goal: in one glance, the user knows how much is left across all three windows, when each resets, whether they are on pace, and which limit they will hit first. It must feel reassuring in the common case (most users never hit a limit) and clearly urgent when a limit is near.

Data available per window (Session, Weekly, Opus weekly): a utilization percent from 0 to 100, and a real reset time (resets_at). Also: the plan name (for example "Max" or "Pro"), the Opus and Sonnet weekly percentages when present, an optional extra usage or credit pool, and a "last updated" timestamp.

Content and structure, top to bottom:
1. Header row: the title "Claude Usage" on the left, a gear (Settings) and a refresh button on the right. Show a small freshness stamp under or near the title, "Updated 2 minutes ago." On refresh, animate the numbers with a numeric transition.
2. The headline insight, the most important element: a single sentence that states the binding constraint and the verdict. Examples to design for:
   - Calm default: "You are on track. Weekly resets in 3 days." (subtle, low key, maybe with a small green check.)
   - Caution: "At this pace you will hit your weekly limit Thursday around 4 PM." (amber, with a small forecast icon.)
   - Opus specific: "Opus is your tightest limit, 82 percent used. Switch to Sonnet to make it last." (amber, with an action affordance.)
   Design all three variants of this headline.
3. The three gauges. Two large rings side by side for Session and Weekly, each showing the percent in the center, the window name, and a reset countdown beneath ("resets in 1h 12m" for session, "resets in 3d" for weekly). Each ring is health colored and carries a thin pace marker tick showing how far through the time window the user is, so a glance reveals ahead or behind pace. Below the rings, the Opus weekly and Sonnet weekly limits as horizontal bars, each labeled, with a percent and a warning icon if high. If the account has no Opus or Sonnet split, hide those bars cleanly.
4. Extra usage card (only if the user has extra usage or credits enabled): a separate, visually distinct card so it never looks like part of the plan bars. Show remaining balance and spend this month against the user's monthly cap. Label it clearly as billed separately.
5. Optional, lower on the screen: a compact entry point to History ("See your last 30 days") and, on Mac only, a Claude Code stats section (designed separately).

Key behaviors to convey in the design:
- The pace marker is the secret weapon. Make it legible: if the colored fill is well behind the pace tick, the user is comfortably under pace, design it to read as reassuring.
- Color is never the only signal. Pair amber and red with words and icons.
- Never show a cost figure here unless the user opted into Claude Code stats, and then label it an estimate.

States to show: the calm on track state, a caution state where weekly is high, and the Opus tightest state.

Platforms: iPhone (single scroll column), iPad and Mac (the same content, comfortable in a window, rings can sit larger). The menu bar popover reuses this layout at a narrower width, designed separately in Section 11.

Accessibility: each gauge reads its name, percent, and reset time to VoiceOver. The headline insight is the first thing VoiceOver announces.

Deliverable: the dashboard in the three states, for iPhone and Mac.

---

## 5. Limit gauge component (ring and bar)

Context: prepend Section 0. The reusable building block used across the dashboard, the menu bar, and widgets. Design it as a small component sheet so every surface is consistent.

Goal: one gauge that communicates utilization, health, time pace, and reset, instantly.

Design two forms:
1. Ring form: a circular track with a health colored progress arc and a soft glow in the health color. Centered: the big percent in SF Rounded, the window name under it in small caps. A thin pace marker tick sits on the ring at the "time elapsed" position, so the gap between the fill and the tick reads as ahead or behind pace. Below the ring: the reset countdown.
2. Bar form: a rounded capsule track with a health colored fill, a label and percent on the row above it, an optional warning icon, and the same pace marker as a thin vertical tick on the bar.

Show each form at three health levels: safe (green, fill well behind the pace tick), caution (amber, fill near the pace tick), danger (red, fill past 90 with the warning icon). Also show an "unknown" or "loading" state (gray track, em dash free placeholder like a dot or the word "loading").

Include a "remaining" variant: the same gauge but showing remaining percent instead of used, for users who prefer to see budget left.

Platforms: works on all. Provide sizes: large (dashboard), medium (popover), small (widget), tiny (menu bar).

Deliverable: a component sheet showing ring and bar, all health levels, both used and remaining variants, all four sizes.

---

## 6. Forecast and pace callout

Context: prepend Section 0. A standalone insight element that appears on the dashboard and in the menu bar popover. This is the research backed anxiety killer.

Goal: turn raw burn into a plain language verdict.

Design these variants:
1. On track (the calm default): low key, green accent, small check icon. "You are on track. Weekly resets in 3 days." Quiet, not alarming.
2. Approaching a limit: amber, forecast icon. "At this pace you will hit your weekly limit Thursday around 4 PM." Optionally a faint mini sparkline of recent burn.
3. Opus tightest: amber, with a gentle action. "Opus is your tightest limit. Switch to Sonnet to make it last." The action is a hint, not a button that does anything in Claude, just guidance.
4. Already at a limit: red, reassuring about recovery. "Weekly limit reached. Full access returns in 2 days, Thursday 4 PM."

Make the calm state visually recede and the urgent states gently stand out. Never use scary or shaming language.

Platforms: all.

Deliverable: the four callout variants.

---

## 7. Extra usage and credits card

Context: prepend Section 0. Some plans have extra usage (overage credits) that bill separately at API rates once the plan limit is hit, controlled by a user set monthly cap. Many users fear silent charges, so clarity is the whole job.

Goal: show the overage pool as clearly separate from plan usage, with no ambiguity about whether it is even on.

Content:
- A distinct card titled "Extra usage."
- If enabled: remaining balance (for example "$42 left"), spend this month against the monthly cap (for example "$8 of $50 this month") as a small separate bar, and the monthly reset date. A clear note: "Billed separately from your subscription."
- If not enabled: a calm one liner, "Extra usage is off. You will simply pause at your plan limit until it resets." with a quiet link to learn more (opens claude.ai). Never nag to enable it.

States to show: enabled with low spend, enabled near the cap (amber), and off.

Platforms: all.

Deliverable: the three states.

---

## 8. History view (trends over time)

Context: prepend Section 0. We persist each poll locally to build a private time series. History helps people learn their own rhythm and answers "am I getting my money's worth." This is a separate screen reached from the dashboard.

Goal: clear, scannable trends with time range control, no clutter.

Content and structure:
1. A time range selector as a segmented control: 12h, 24h, 3d, 7d, 30d, 90d.
2. A session usage line chart for the current and recent 5 hour windows, showing how utilization climbed over time.
3. A history bar chart showing peak utilization per session or per week across the selected range, color coded by health, so heavy periods are obvious.
4. A summary strip: average weekly utilization, your busiest day, and a plain "subscription value" read (for example "You use about 60 percent of your weekly allowance," framed neutrally, never as pressure to use more).
5. An export action (share or save the history as a file). Make export obviously work, since broken export is a common complaint.

States to show: a populated 30 day view, and an early state where there is only a little history yet ("Keep the app running to build your history. You have 2 days so far.").

Platforms: iPhone (stacked, charts full width), iPad and Mac (charts can sit side by side, more density).

Accessibility: charts need audio graph or at least summarized VoiceOver descriptions and accessible value labels.

Deliverable: the populated view and the early state, for iPhone and Mac.

---

## 9. Activity grid (GitHub style year view)

Context: prepend Section 0. A distinctive, loved pattern: a calendar heat grid of daily usage intensity over the past year. Lives inside History or on its own.

Goal: a beautiful, glanceable year of usage that shows streaks and intensity.

Content:
- A grid of small rounded cells, one per day, columns are weeks, rows are weekdays, with month labels along the top and weekday labels down the side.
- Cell color encodes daily peak utilization using a clay to deep clay scale on the dark background (empty days are a faint glass cell). Keep it on brand, not the GitHub greens.
- A legend "less to more."
- Tapping or hovering a cell shows a tooltip with the date and that day's peak utilization.
- A small headline above it, for example "Your last year" and a streak stat ("12 day active streak").

States to show: a full year with varied intensity, and a sparse new user year.

Platforms: iPhone (horizontally scrollable grid), iPad and Mac (full year visible).

Deliverable: the full and sparse states.

---

## 10. Claude Code stats section (Mac only)

Context: prepend Section 0. On Mac, with the user's permission to read the local Claude Code logs, we can show rich stats the competitor charges for. This is an optional, opt in section on the dashboard or History. Cost is an estimate and many users do not want costs shown, so make cost optional and clearly labeled.

Goal: surface Claude Code activity richly without implying real billing.

Content:
1. An enable card first: "See your Claude Code stats. Read your local Claude Code logs to show messages, tools, and tokens by model. This stays on your Mac." with an "Enable" button that triggers the folder permission, and a note that it is free and revocable.
2. Once enabled, the stats:
   - Top tiles: messages sent, tool calls, sessions, total tokens. Use estimate labels where relevant.
   - Tokens by model (Opus, Sonnet, Haiku) as a clean breakdown.
   - Top projects by token use, a short list with a "see all" that opens a detail screen.
   - Optional cost, off by default, with a toggle "Show estimated cost." When on, every cost is suffixed or grouped under the word "estimated."
3. A revoke control in Settings to turn it back off.

States to show: the enable card, the enabled stats with cost off, and the enabled stats with cost on.

Platforms: Mac only.

Deliverable: the three states, plus the top projects detail list.

---

## 11. Menu bar glance and popover (Mac)

Context: prepend Section 0. On Mac the app lives in the menu bar. The menu bar item is the single most important "glance and know" surface. Clicking it opens a popover that is a compact version of the dashboard.

Goal: a menu bar item that tells the truth in a few pixels, and a popover that gives the full calm read without a full window.

Design two things:

A. The menu bar item, with selectable styles (offer all, let the user pick in Settings):
   - Percentage only: a small health colored "62%."
   - Mini bar: a tiny horizontal bar.
   - Mini ring: a tiny ring.
   - Icon fill: the app glyph that fills with health color by session percent.
   - Optional: show weekly alongside session, for example "S 41% W 62%."
   Show each style at safe, caution, and danger. Keep it crisp at menu bar height and legible in both light and dark menu bars.

B. The popover (about 380 wide): the dashboard content condensed. The headline insight at top, the freshness stamp, the three gauges (rings can be medium, Opus and Sonnet as bars), the forecast callout, the extra usage card if relevant, and a footer row with refresh, Open Dashboard, and Settings. It must render its own header controls since a menu bar popover has no navigation bar.

States to show: the menu bar styles across health levels, and the popover in the calm and caution states.

Platforms: Mac.

Deliverable: the menu bar style sheet and the popover in two states.

---

## 12. Widgets (Home Screen, Lock Screen, StandBy, desktop)

Context: prepend Section 0. Widgets are our biggest "ambient" surface and a key differentiator since ours are free and standalone. Design the full family. Widgets read the latest saved snapshot, so include a subtle freshness or stale treatment.

Goal: instantly readable usage at every widget size, on brand, beautiful.

Design these:

A. System small (Home Screen iOS, Notification Center and desktop on Mac): one large ring (Weekly by default, user choosable to Session), the percent, and a tiny reset countdown. Health colored. Dark glass surface.

B. System medium: two rings side by side (Weekly and Session) plus a small column with Opus and Sonnet percentages and the weekly reset. The title "Claude Usage."

C. System large (Mac and iPad): the three gauges plus the forecast headline and reset times. Almost a mini dashboard.

D. Three style options for the system widgets, selectable: Rings (circular), Compact (large percentage with reset time), Bars (horizontal bars). Show all three at small and medium.

E. iOS Lock Screen and StandBy accessory widgets:
   - Accessory circular: a gauge of weekly percent.
   - Accessory rectangular: "Claude Usage, Weekly 62% 5h 41%, resets in 3d."
   - Accessory inline: "Claude wk 62% 5h 41%."
   These must be monochrome friendly and legible on the Lock Screen.

Stale treatment: if the snapshot is old, show a tiny clock glyph or dim the value slightly, never show a wrong fresh looking number.

States to show: each size and style at a safe and a caution level, plus the accessory family.

Platforms: iOS, iPadOS, macOS as noted.

Deliverable: the full widget family sheet.

---

## 13. Settings, Appearance

Context: prepend Section 0. A settings screen (a sheet on iPhone, a window tab on Mac) for look and glance preferences. Keep it tidy and grouped.

Goal: let users tune what they see without overwhelming them.

Controls to design (grouped under "Appearance"):
- Menu bar style (Mac): a picker for the styles in Section 11.
- Show weekly alongside session in the menu bar: toggle (Mac).
- Fill the icon by usage: toggle (Mac).
- Show remaining instead of used: toggle (applies to menu bar and dashboard).
- Show the pace marker on gauges: toggle.
- Time format: System, 24 hour, 12 hour.
- Dashboard text size: a small picker, and a note that the app also follows the system accessibility text size.
- Default widget metric: Weekly or Session.

Each row has a clear label and, where helpful, a one line description. Use native grouped list styling on its respective platform.

Platforms: iPhone (grouped list sheet), Mac (a settings tab).

Deliverable: the Appearance settings for iPhone and Mac.

---

## 14. Settings, Notifications and the rule editor

Context: prepend Section 0. Alerts are the second most demanded feature. We use a flexible rule system. New users start with two sensible default rules (90 percent on Session and on Weekly). This is two designs: the rules list, and the rule editor.

Goal: powerful but approachable alerting.

A. Rules list:
- A list where each row is one rule, showing its plain language summary ("Warn me when Weekly crosses 90 percent"), the target limit as a small tag, and an on or off switch.
- A row menu for delete and duplicate. A "Delete all" at the bottom. An "Add rule" button at the top.
- For brand new users, show the two starter rules already present.

B. Rule editor (a sheet):
- Pick a template: Crosses above a percent, Falls below a percent, Limit resets, On pace to hit the limit, Before reset (a chosen number of minutes before, with an optional capacity condition).
- Pick the target limit: Session, Weekly, Weekly Opus, or Extra usage.
- Set the threshold or minutes as needed, with a live plain language preview of the rule at the bottom ("You will be warned when Weekly Opus crosses 75 percent.").
- Save and Cancel.
- Optional, Mac with Apple Intelligence: a "Free text" tab where the user types "warn me at 75 and 90 percent of my weekly limit" and it parses into one or more rules to review before saving. Design this tab too, with the parsed rules shown as editable chips.

States to show: the rules list with several rules, the editor with a template chosen and the live preview, and the free text tab with parsed results.

Platforms: iPhone and Mac.

Deliverable: the list and the editor (including the free text tab), for iPhone and Mac.

---

## 15. Settings, Account and Privacy

Context: prepend Section 0. The trust screen. Privacy is a selling point, state it plainly.

Goal: make the privacy model obvious and give the user control of their session.

Content:
- Connection: shows "Connected to claude.ai" with the plan name, and a "Sign out" button. If disconnected, a "Sign in to Claude" button.
- Claude Code stats (Mac): a toggle to enable or revoke the local log access.
- Privacy card: three plain statements with check icons. "Everything stays on this device. There are no servers." "You sign in on Claude's own page. We never see your password." "Your session is stored only in this device's Keychain." 
- About: version, the "not affiliated with Anthropic" disclaimer, a link to send feedback, and a note that the app reads your usage from claude.ai and may need an update if Claude changes its site.

States to show: connected and disconnected.

Platforms: iPhone and Mac.

Deliverable: both states.

---

## 16. System notification and in app banners

Context: prepend Section 0. When a rule fires, we post a system notification. We also show in app banners for connection and stale states.

Goal: clear, calm, actionable alerts.

Design:
1. System notification content for: a threshold alert ("Claude Usage, You have used 90 percent of your Weekly limit. Resets in 2 days."), a reset ping ("Claude Usage, Your Session limit just reset. Full access is back."), and an on pace warning ("Claude Usage, At this pace you will hit your Weekly limit before it resets."). Show how they look in the macOS and iOS notification styles.
2. In app banners: the amber "Could not reach Claude" banner, and a subtle "Showing last known limits" stale banner.

Deliverable: the notification examples and the two banners.

---

## 17. App icon and brand mark

Context: prepend Section 0. We need a distinctive, on brand app icon that reads at every size, plus the in app glyph used for the hero and the menu bar icon fill.

Goal: a memorable mark that says "calm usage gauge" with Claude warmth.

Direction: a gauge or ring motif in the clay accent on a dark, softly glassy background, with a subtle warm glow. It must read at 16px (menu bar, Finder) and look refined at 1024px. Avoid the Anthropic logo or anything that implies official endorsement. Provide the full macOS icon ladder and the iOS 1024 master, plus a single color glyph version for the menu bar.

Deliverable: the icon at 1024, a small size preview at 16 and 32, and the monochrome menu bar glyph.

---

## Build order suggestion (for when designs come back)

1. Dashboard plus its gauge, forecast, and freshness components (Sections 4, 5, 6, plus the freshness piece of 3). This alone fixes "barely showing information" using data we already fetch.
2. Menu bar glance and popover, and the widget family (Sections 11, 12). The ambient surfaces people want most.
3. Settings, Appearance and Notifications with the rule editor (Sections 13, 14, 16).
4. History and the activity grid (Sections 8, 9), which need the local time series.
5. Mac Claude Code stats (Section 10).
6. Onboarding, Account and Privacy, app icon polish (Sections 1, 2, 15, 17).
