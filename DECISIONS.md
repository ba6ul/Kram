# Decisions log

Folder structures in `_Templates/` start as a theory and get reshaped once they're
actually used. Before restructuring an existing template, check here for *why* a
folder exists. If it's already earning its keep, don't merge, rename, or remove it
without asking first.

New entries go under the relevant project type, newest last. Don't delete old
entries when a decision changes — add a line saying what superseded it instead,
so the history stays readable.

## App (2026-08-15)

- Created the `App` project type for store/social/marketing assets: icon, Play
  Store screenshots, social, logo.
- `00_inbox` exists because Kram's `sort` verb routes by file extension only — it
  can't tell an icon `.psd` apart from a logo `.psd` by content. All loose
  psd/png/jpg/ai/svg land here; sorting them into 01-04 is a manual step.
- `03_social` splits into `raw/` (screenshots as dropped) and `carousel/`
  (rearranged Instagram carousel exports), matching the actual workflow: drop
  screenshots, then hand-arrange them into carousel slides.
- `04_logo` holds an HD export (1080px), distinct from a smaller ~660px variant
  used elsewhere. Only the HD one lives in this structure so far.
- Status: unused in practice yet — first real project will likely reshape this.
  Treat as a working theory, not a settled structure.

## Repo history (2026-08-15)

- This repo was originally `VidOrg-Master`, containing only `Long-vid.bat` — a
  single hand-written batch script that prompted for a project name and made
  the folders `01_After effects`, `02_davici resolve`, `03_Photoshop`,
  `04_chitra`, `05_chalchitra`, `06_awaj`, `07_export`.
- Renamed to `Kram` and given this full tool on top of that history rather than
  starting a fresh repo, because everything here grew directly out of that
  script: the numbered-folder convention, the `_Base` + per-type template
  split, and the `hi-Latn` locale pack's `chitra` / `chalchitra` / `awaj`
  translations are literally lifted from `Long-vid.bat`'s hardcoded folder
  names.
- `Long-vid.bat` itself is kept at `legacy/Long-vid.bat` rather than deleted —
  it's superseded by `New Long project.bat` + `Organise.ps1 -Type Long`, but
  it's the origin artifact for the whole project, not dead weight.
