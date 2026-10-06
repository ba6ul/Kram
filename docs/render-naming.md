# Render naming

Kram sorts files by type, but it can't tell you what a render *is*. If the file
is called `ksjhdfhas.mp4`, nothing can — not Kram, and not you three months
later when you've forgotten the video.

This guide sets up After Effects and DaVinci Resolve so every render is named
for you, from information the software already has. It's a one-time setup per
machine, done by hand. It isn't scripted, because both apps change where and how
they store these settings between versions — a guide survives an update better
than a script does.

## Why renders end up with junk names

Editing software lags, so you render often — halfway through, at the end, to
check something. You can't know in advance which render is a throwaway and
which one you'll end up putting on a timeline. So you don't bother naming any
of them, and the useful ones end up called `test4` and `Untitledf`.

You also can't fix it afterwards. Once a render is on an After Effects or
Resolve timeline, renaming the file takes it offline. **The name has to be
right at the moment the file is created.**

At that moment the software knows two things you'll forget later: which comp or
timeline you rendered, and when. That's enough for a name that means something:

```
Snyder vs Nolan_2026-05-27_18-27.mp4
Snyder vs Nolan_2026-05-27_19-04.mp4   <- re-render later, no clash
```

## Where renders go

Every Kram project has a `00_DROP_HERE` folder. Point every render, save, and
export at it — once per project; both apps remember the last folder you used.
Kram never moves or inspects anything inside it, so a render already on a
timeline can't be taken offline by an Organise run.

## The one habit this needs

Both setups copy whatever the comp or timeline is already called. So **name the
comp or timeline when you create it** — `suitcase intro`, `timer countdown`,
`issues cards` — while you still know what it is. That's inside the software,
during work you're already doing, not a separate chore.

Making a variant? Duplicate it and add `v2`, rather than rendering the same comp
twice under different hand-typed names.

A comp left as `Comp 1` will still render as `Comp 1_2026-…`. The date and time
keep it unique, but only the comp name gives it meaning.

## After Effects

Tested on After Effects 2025 (25.2).

After Effects ships a built-in file name preset called **Comp Name And
Date/Time**:

```
[compName]_[dateYear]-[dateMonth]-[dateDay]_[timeHour]-[timeMins].[fileExtension]
```

Out of the box the default is **Comp Name** instead, which gives every render of
a comp the same name — so you're asked to rename it, and you type whatever.
Switch the default once:

1. Add any comp to the render queue (**Ctrl+M**).
2. Click the small arrow next to **Output To:**.
3. **Ctrl+click** **Comp Name And Date/Time**. Ctrl+click makes it the default,
   rather than applying it to this one render.
4. Check **Edit → Preferences → Output → Use Default File Name and Folder** is
   on.

To confirm: add a comp to the render queue. **Output To** should show the comp
name followed by the date and time.

**After reinstalling or updating After Effects**, preferences may be reset — do
step 3 again. The preset is built into After Effects, so it's always there.

### Where the setting lives

For when the steps above stop matching your screen after an update:

- File: `%APPDATA%\Adobe\After Effects\<version>\Adobe After Effects <version> Prefs.txt`
- Section: `["Output File Name Template Presets Data Section v5"]`
- Value: `"Default Index v3"` is the position of the default preset in the list
  under `["Output File Name Template Presets Section v6"]`, counting from 0.
  On 25.2, `"6"` is Comp Name And Date/Time.

Only edit this file with After Effects closed — it rewrites the file on exit —
and back it up first. Section names carry version numbers (`v5`, `v6`) because
Adobe changes them; if yours differ, look for the preset list by its contents
rather than trusting the names above.

## DaVinci Resolve

Written for Resolve 20. Not yet confirmed step-by-step on a real machine — update
this section once it is.

1. Go to the **Deliver** page.
2. In **Render Settings**, open the **File** tab.
3. Set **Filename uses** to **Custom name**.
4. In the name box, type `%` and choose **Timeline Name** from the list that
   appears. It becomes a chip in the box.
5. If the tab offers **Use unique filenames**, turn it on so re-renders don't
   overwrite each other.
6. Open the **…** menu at the top of Render Settings → **Save As New Preset** →
   name it `Kram`. Pick this preset when rendering.

Typing `%` shows other variables too (project name, clip metadata). Timeline
name is the one that carries meaning; add others only if you need them.

## What this doesn't solve

Renders that already exist with junk names. For those, the only reliable way to
find out what they are is to look at them — and once one is on a timeline,
renaming it is a job for inside the editing software (relink), not Explorer.
