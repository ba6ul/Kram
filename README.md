

# Kram

A project organiser for video editors, photo editors, and designers on Windows.

It does two things:

1. **Scaffolds** a project folder for the kind of work you're doing.
2. **Sorts** whatever you dump in that project's root into the right subfolders,
   as many times as you like, throughout the project.

No install, no dependencies. It's PowerShell, which Windows already has.

## Why it works this way

Most file organisers watch a fixed folder. That doesn't fit creative work, where
every project is a new folder and you often have several running at once. So
Kram has **no global inbox and no "active project"** — each project is
self-contained and independent. The project's own root folder *is* its inbox.

It also doesn't ask you to set anything up before you start working. You make
your draft first, and only create the project folder once you actually have
files worth organising.

## The loop

1. Start working. Create nothing.
2. Draft done → run **New project\New Long project.bat** (or Shorts / Photo / UI
   / App). Name it.
3. Drop everything you're working with into the project root.
4. Run **Organise.bat** from inside the project. It files everything.
5. Keep working.
6. More files pile up in the root → run **Organise.bat** again.
7. Repeat forever. Already-filed folders are never disturbed.
8. Finished → run **Tidy (final cleanup).bat** for a last pass before archiving.

Every render, save, and export goes into **`00_DROP_HERE`** — test renders, half
renders, the final, whatever name it came out with. There's no rule about what
goes where inside it, on purpose: rules you have to remember mid-edit are rules
you eventually stop following. Kram never moves anything in there and never
looks inside, because a render you dropped there may already be on a timeline.

A project mid-loop looks like this, and Kram only touches the top group:

```
My Video/
├── random-footage.mp4                 <- new
├── downloaded-image-weird-name.png    <- new
├── random-folder/                     <- new
│
├── 00_DROP_HERE/                      <- your renders, never touched
├── 01_After_effects/                  <- already organised, left alone
├── 05_video/                          <- already organised, left alone
└── 06_audio/                          <- already organised, left alone
```

## How it knows what's new

Managed folder names are read live from `_Templates/`. Anything in the project
root that isn't one of them is new. That's the entire rule — no database, no
timestamps, nothing that can drift out of sync. Re-running is always safe.

## Right-click menu (optional)

Double-click **Setup\Install.bat** once and you get:

- **Right-click empty space** in any folder → *Kram — New project* → Long /
  Shorts / Photo / UI / App. The project is created right there, in the folder
  you're standing in.
- **Right-click a folder** → *Kram* → Organise / Preview / Organise + rename /
  Tidy.

Both sit at the top of the menu between separators, with Kram's own icons, so
they don't get lost among every other app's entries.

*Preview* is the dry run — it prints exactly what would move and then stops
without touching anything. Useful the first time you point Kram at a folder full
of unfamiliar downloads.

Everything is written under `HKCU`, so it needs no administrator rights, affects
only your user, and comes off cleanly with **Setup\Uninstall.bat**. Run
Install.bat again after adding a project type to `config.json` — the *New
project* submenu is built from it.

> **Windows 11:** these entries live under **"Show more options"** (or
> Shift+Right-click). Install.bat asks whether to switch to the full, classic
> right-click menu so Kram shows on the first click — Microsoft's own documented
> registry escape hatch. It changes the menu for every app and restarts Explorer
> once, so it's a question, never automatic. Uninstall.bat offers to undo it.
> Kram doesn't appear in Windows 11's compact first-level menu: that needs a
> compiled shell extension, and Kram stays plain PowerShell.

Everything else Setup needs lives in `Setup\_internal\` — you don't need to open
it. Icons there are drawn by `Make-Icons.ps1` from the Windows icon font, nothing
downloaded. To restyle them, edit the colours or symbols at the top of that
script, run it, then run Install.bat again. If Explorer still shows old icons,
it's caching them: restart Explorer or sign out and back in.

## What's in this folder

```
Kram/
├── New project/        double-click to create a project (Long, Shorts, Photo, UI, App)
├── Setup/              Install.bat / Uninstall.bat for the right-click menu
├── docs/               guides, e.g. render naming for After Effects / Resolve
├── Organise.ps1        the tool itself
├── config.json         sort rules and project types
├── _Templates/         folder structure for each project type
├── templates-support/  launchers copied into every new project
└── locales/            folder-name language packs
```

`Organise.ps1` stays at the top on purpose: every project Kram has created, and
the installed right-click menu, call it at this exact path. Moving it would break
them all.

## Setup

1. Clone or download this folder anywhere. It's portable — everything resolves
   relative to the script.
2. Copy `config.local.example.json` to `config.local.json` and set
   `projectsRoot` to where you want projects created. That file is gitignored,
   so your paths never conflict with anyone else's.
3. Optionally drop real template project files into `_Templates/<Type>/` named
   `PROJECT.aep`, `PROJECT.drp`, `PROJECT.psd`. They're renamed to the project
   name on creation. Kram deliberately does not create empty ones — a 0-byte
   `.psd` isn't a file Photoshop can open.

## Languages

Folder names come from a language pack, so `05_video`, `05_chalchitra`, and
`05_चलचित्र` all come out of the same codebase.

| Pack | Script | Example |
|---|---|---|
| `en` | Latin | `05_video`, `06_audio/SFX` |
| `hi-Latn` | Hindi, romanised | `05_chalchitra`, `06_awaaj/Dhwani` |
| `hi-Deva` | Hindi, Devanagari | `05_चलचित्र`, `06_आवाज़/ध्वनि` |

Script subtags follow BCP 47, so `hi` on its own is never used — romanised and
Devanagari Hindi are separate packs with separate translations, not one pack
with a transliteration step.

Templates use canonical English names. A pack renames folders when a project is
created, and the choice is stored per project — so all three can coexist on one
machine, and a project keeps its language forever regardless of your current
default.

Set your default with `defaultLocale` in `config.local.json`, or override per
project with `-Locale hi-Deva`.

**Adding a language** is one file: copy `locales/en.json`, map only the folder
names you want changed, and leave out anything that should stay as-is. Numeric
prefixes are kept ASCII in the shipped packs so folders still sort correctly in
Explorer. Pull requests welcome.

## Safety

Moving media that's already on an After Effects or Resolve timeline takes it
offline. Kram is built around that:

- `sort` only ever touches loose items in the project root. Anything already
  inside a managed folder is untouchable.
- `tidy` reports misplaced nested files but **never moves them** — you do that
  by hand with the project closed.
- Files locked by another program are skipped.
- Collisions become `name (2).ext`. Nothing is overwritten, ever.
- Every move is logged to `organise-log.json` in the project.

## Image sequences

Runs of 3+ files sharing a prefix, extension, and digit padding
(`render_0001.png`, `render_0002.png`, …) are detected and moved together into
their own subfolder. Dropped folders move intact for the same reason —
flattening a sequence destroys it.

The optional `-Rename` flag only *cleans* junk from downloaded filenames — `%20`
escapes, exotic dashes, 200-character URL slugs — while keeping brackets and any
real script, so Devanagari or Cyrillic filenames survive intact. It never appends
sequential numbers, because that is exactly what would make After Effects mistake
a pile of unrelated stills for a sequence.

```
My%20Cool%20Clip%20(final)%20v2.mp4   ->   My Cool Clip (final) v2.mp4
```

## Render names

Kram can file a render but can't tell you what `ksjhdfhas.mp4` was. Set up After
Effects and DaVinci Resolve once so every render is named after its comp or
timeline plus the date and time — see [docs/render-naming.md](docs/render-naming.md).

## Project types

| Type | For |
|---|---|
| `Long` | Long-form video. AE / Resolve / Photoshop project folders, footage, audio, cache. |
| `Shorts` | Vertical/short-form. Same plus thumbnails and a hooks file. |
| `Photo` | Photo editing. source / edited / export / presets. |
| `UI` | App UI design. design / references / wireframes / exports / prototypes. |
| `App` | App store & social assets. icon / screenshots / social / logo, each source + export, plus an inbox for unsorted drops and a credentials folder for signing keys/`.env` files. |

Add your own by making a folder in `_Templates/` and an entry in `config.json`.

## Customising

- **Structure** — edit the folders in `_Templates/` in Explorer. `_Base/` is
  shared by all types; each type layers on top. No code involved.
- **Sort rules** — `config.json`. `defaultRules` maps extension → folder, and
  each type can override individual extensions (a `.png` is footage material in
  a video project but a reference in a UI project).

## Commands

```
Organise.ps1 -Verb new -Type Long [-Name x] [-Locale hi-Deva] [-Here]
Organise.ps1 -Verb sort [-Path .] [-DryRun] [-Rename]
Organise.ps1 -Verb tidy [-Path .] [-Apply]
```

## Not built yet

- A top-level Windows 11 context menu entry (needs a signed MSIX shell extension).
- Localised UI messages — only folder names are translated today.
