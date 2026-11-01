# Work while Javier is at his day job

*Proposed 2026-11-01. Javier & Claude. **Approved by Javier the same day (D-17): one run at 9:00 Mon–Fri, done by
12:00; he works 8:00–17:00.***

## The short version
One scheduled Claude session runs on this PC on weekday mornings. It picks the next items marked **(solo)** in
`TODO.md`, builds and tests them, and leaves a report and a short clip or screenshots on the Dailies page. Javier
reviews in the evening in about 15 minutes: the board shows what moved, the Dailies page shows what it looks like,
and anything that needs him waits in one list. Nothing goes public, nothing costs extra money, and nothing reaches
his accounts without him.

## What can honestly run on its own
| Work | Alone? | Why |
|---|---|---|
| Game code: movement, fights, enemies, levels in grey boxes, menus | **yes** | testable on this PC, headless, fenced |
| Automated tests and the bot playthrough | **yes** | that's how unattended work proves itself |
| Cutting, cleaning and rigging pictures Javier already approved | **yes** | the picks are made; this is handwork |
| Music and sound made from code | **yes, as drafts** | goes on the Dailies page for his ear |
| Writing prompts for the next art batch | **yes** | written, not run |
| Docs, the board, TODO.md, the test matrix for his next play | **yes** | |
| Running ChatGPT image batches | **no** | his account; done together, or by him from Claude's prompt sheet |
| OpenArt / Runway | **no** | costs money: his yes per batch |
| Feel tests and playthroughs | **no** | only he can say if it feels right |
| Picks on the Dailies page, design answers | **no** | his decisions |
| Pushing to the public GitHub, releases, the AUR | **no** | public: after his review |
| Anything with sudo, installing packages | **no** | the sudoForge box needs him at the keyboard |

## The options, and what each costs
1. **A scheduled session on this PC (recommended).** The Claude desktop app starts a session at a set time on
   weekdays. It runs here, so it can run Godot (fenced), the tests and the bot, and see the files.
   - *Cost:* no extra money. It uses Javier's Claude plan, so a long run eats into the same usage he has in the
     evening. We start with one run of up to ~3 hours, measure what one run actually uses in the first week, and
     shrink it if his evenings feel it.
   - *Needs:* the PC on and awake, the desktop app open. Javier already leaves his sessions open while he's at
     work (unless the PC has to be off), so this fits how he works. If the PC is off, the run is skipped, nothing
     breaks.
2. **A cloud session (a scheduled routine on Anthropic's servers).** Runs from the GitHub repo, not this PC.
   - *Cost:* also Javier's plan; no extra money.
   - *Limits:* no Godot window, no gamepad, none of this PC's tools; it can write code and docs, and only proves
     what a headless test can. It needs the public repo first and pushes to a branch, which is public.
   - *Use:* only if the PC can't be left on. Not recommended to start.
3. **Both.** Not worth it yet: double the usage for work that can't be checked any better.

## The rules every unattended run follows
- **Only (solo) items.** Anything unmarked waits for a session with Javier.
- **Its own branch, never `main`.** Each run works on `daily/YYYY-MM-DD`; Javier's yes merges it.
  Nothing is pushed to GitHub by an unattended run.
- **Fenced and timed:** every Godot run through `scripts/capped.sh` + `timeout`; the whole run stops at its time
  limit even mid-task, and says where it stopped.
- **It proves its work:** tests green with the count, the bot through every finished level, a clip or screenshots.
  A failed test is reported as failed, never hidden.
- **It stops at the first thing that needs Javier** for that item, writes it down, and moves to the next (solo) item.
- **It writes one report:** `reports/YYYY-MM-DD.md` — done, proven how, not done and why, what needs Javier.

## The assistant team's part
Javier's assistant team (another project) tests what the run built, on the KognogOS machines, for smoothness and lag,
and tallies any paid credits. Their notes come to the next session through Javier. The run never reaches into that
project, and that project's names never go into this repo.

## Where Javier reviews
1. **The board** (beside the chat): what moved today.
2. **The Dailies page:** the clips, screenshots and drafts, with Approve / Change buttons.
3. **The evening session:** Claude reads the report, merges what he approved, pushes, updates every surface.

## What we need from Javier to set it up
- Yes or no on the recommendation.
- His working hours (so the run starts after he leaves and is done before he's home).
- *(Answered: the PC stays on with sessions open while he works, unless it has to be off.)*
