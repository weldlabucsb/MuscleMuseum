# Changelog

Every push to GitHub from the main experiment control computer (`T1000`, folder `C:\Users\scientist\Documents\MuscleMuseum`) gets a dated entry here and a tag (`v1`, `v2`, ...). Newest entry first. "This computer" below means that one. The rules behind this are in `CLAUDE.md`. Since `v2` the working branch is `sr`. Before that it was `li`, which belongs to another team.

- See a version's note and its last commit: `git show vN`
- See everything that changed between two versions: `git log --oneline vA..vB` and `git diff --stat vA vB`
- Run an older version for a while: close the MuscleMuseum windows, `git switch --detach vN`, then restart MATLAB or run `clear classes`. Come back with `git switch sr` and reload MATLAB again. Uncommitted files stay in place. If git refuses because a file "would be overwritten", stop and ask; never add `-f` or `--force`.

## v2 - 2026-10-08

Commit label: `pk`. Branch: `sr`. Computer: `T1000`.

### What changed

1. **The working branch for this computer is now `sr`.** Branch `li` is used by another team, so from now on every change from this computer goes to `sr`. The folder is on `sr` and follows GitHub's `sr`.
2. **`sr` now has everything `li` has.** `sr` was at commit `55198dd` (14 May 2026, the same as GitHub's `main`). It was fast-forwarded to `bbb314f` (6 Oct 2026), which adds the 14 commits that were only on `li`: 11 ordinary commits and 3 merges, 19 files changed, about 5,280 lines added and 60 removed in text files. They are the later part of the update described under v1 ("What the update brought in"). The Basler typo that `sr` had (`BitsPerSample = 8ed`) is fixed by them.
3. **`CLAUDE.md` and `CHANGELOG.md` moved from `li` to `sr`.** They are added to `sr` in this commit. On `li` they are removed again by the commit "Remove CLAUDE.md and CHANGELOG.md (moved to sr)", sent in the same push as this one; it changes nothing else on `li`. At the other team's next pull the two files leave their folders.
4. **`CLAUDE.md` edited for the new branch.** Commands and notes now name `sr`. A new note says `li` belongs to another team: never commit or push to it (the removal commit in item 3 is the one exception, made at the user's request), and bring its work into `sr` only as a reviewed update.

### Why

- `li` belongs to another team. The v1 push put this computer's rule files on their branch; this push takes them off again and gives this computer its own branch.
- `sr` should not fall behind `li`, so it takes over all of `li`'s code before work starts on it.

### Check before the next experiment

`sr` now holds the same code as `li`, so the four checks listed under v1 apply again and are still open: reload MATLAB; the five missing settings columns (run `setParameter` once, after copying `mmParameter.db`); the missing `slanCM` function; the changed Keysight software trigger. Until the second and third are settled, START is expected to fail on this version.

### Left out on purpose

The six uncommitted files listed under v1 are still uncommitted and untouched.

### How it was tested

- Nothing was run in MATLAB.
- The update of `sr` was a fast-forward: no merge and no conflicts. The six uncommitted files were compared before and after by file checksum: identical.
- Before the push, the removal commit for `li` was compared with commit `bbb314f`: same files (identical tree id). `sr`, that commit and tag `v2` go to GitHub in one `--atomic` push, so all three arrive or none.
- The whole sequence was rehearsed beforehand in a throwaway copy of the repository.

### How to go back

Close the MuscleMuseum windows first, and reload MATLAB after switching.

| To get | Command |
|---|---|
| The code this computer ran until 2026-10-08 (commit `064c8ee`) | `git switch --detach v0` |
| `sr` as it was before this push (commit `55198dd`); it has neither of the two START problems | `git switch --detach 55198dd` |
| Back to the newest version | `git switch sr` |

- The six uncommitted files stay where they are through each of these switches.
- Tag `v1` stays on `li`'s history (commit `e66c565`). It is not part of `sr`'s history: the two documents were added to `sr` afresh, so that a later merge from `li` does not remove them. Do not run `git switch --detach v1`: its code is the same as `v2`, and all it does is bring back the old `CLAUDE.md` and `CHANGELOG.md`, which name `li` as the working branch.

## v1 - 2026-10-08

Commit label: `pk`. Branch: `li`. Computer: `T1000`.

Note added in v2: this entry was written when the working branch was `li`. It is now `sr`, so read `git switch li` below as `git switch sr`. Do not switch to `v1` itself (see v2, "How to go back").

### What changed

1. **Added `CLAUDE.md`.** It holds the five working rules for Claude sessions in this repo (review before commit, changelog on every push, a tag on every push, ask before touching hardware, never force-push) and notes on how to apply them here.
2. **Added `CHANGELOG.md`** (this file).
3. **Brought this computer's copy up to date with GitHub.** The folder was at commit `064c8ee` (20 Apr 2026) and GitHub's `li` branch was at `bbb314f` (6 Oct 2026), 33 commits ahead. Those commits were already on GitHub and are not new work in this push, but they are new to the code this computer runs. See "What the update brought in" below.

### Why

- The rules make every future change reviewable and traceable, and give a known version to return to.
- To push to `li` without force-pushing, this copy first had to contain everything already on GitHub's `li`. That is the only reason the running code was updated today.

### Check before the next experiment

Found by reading the code and the settings database. None of it has been run.

1. **Reload MATLAB.** MATLAB was open while the update was made, so it may be running a mix of old and new code. Close the MuscleMuseum windows and run `clear classes`, or restart MATLAB.
2. **The settings database is missing five new columns.** The update adds `AdCustomTitle`, `AdCustomXLabel`, `AdCustomYLabel`, `KapitzaParameter` and `ModulationParameter` to the trial settings (`src/mmParameter/BecExpSetting.m`). The table `BecExpSetting` in `Documents\MMUser\config\mmParameter.db` does not have them. `BecExp.m` (lines 545 to 547) reads the three `AdCustom...` settings for every new trial, because the Ad analysis is always on. So every START is expected to stop with an "unrecognized field" error, after the trial folder and database row have already been created. Running `setParameter` once adds the columns (the Run SetParameter button in `BecControlPanel`, or `init`). `setParameter` also refills the settings tables from `mmConfig.m` and deletes any device no longer listed there, so make a dated copy of `mmParameter.db` first.
3. **`slanCM` is missing.** `src/trial/becExp/BecAnalysis/Ad.m` line 27 now sets the default colormap with `slanCM("inferno")`. `slanCM` is not in this repo and was not found on this computer (the repo has `lib/slanCL`, a different function). Type `which slanCM` in MATLAB. If it is not found, the Ad analysis cannot load and no trial can start, because every trial uses Ad.
4. **The Keysight software trigger changed.** The Trigger button in `WgControlPanel` now sends one `*TRG` to the generator whatever the trigger source is. Before, it sent a trigger only to channels set to software trigger. Both generators on this computer use this driver.

Until items 2 and 3 are settled, the previous code can be run with `git switch --detach v0` (see "How to go back").

### What the update brought in

33 commits from 20 Apr to 6 Oct 2026: 19 ordinary commits by XiaoC and nicolehalawani, and 14 merges. 29 files changed. About 5,350 lines added and 80 removed in text files, of which about 4,470 are the two new analysis classes. Changes inside `.mlapp` and `.png` files are not counted in the line numbers.

| Area | Files | What changed |
|---|---|---|
| Waveform generators | `src/hardware/WaveformGenerator/KeysightWaveformGenerator.m` | `trigger` now sends a single `*TRG` instead of `TRIGger<n>` to each software-triggered channel. New `triggerchannel(ch)` method triggers one channel the old way; nothing calls it yet. Connect, set, upload and close are unchanged |
| Camera | `src/hardware/Acquisition/Andor.m` | New `resetCameraConnection` method: stop, reconnect, re-send the absorption settings, restart; if that fails it shuts down the parallel pool and tries once more. Nothing calls it yet. `setCallback` now remembers the callback. Normal camera operation is unchanged |
| Scopes | `src/hardware/Scope/SiglentScope.m`, `Scope.m` | Siglent only (not configured on this computer): readout switched to 10-bit, and a new `isScopeTriggered` helper that nothing calls yet. `Scope.m` is shared by all scopes, including the two Tektronix scopes here: the trapezoid fit now prints the data size and fit coefficients to the command window; the fit itself is unchanged |
| Hardware GUIs | `HardwareControlPanel.mlapp`, `ListDialog.mlapp`, `WaveformListEditor.mlapp` | `HardwareControlPanel`: scan lists 5 to 10 added (there were 4). `ListDialog`: opens for a list that has no entry yet. `WaveformListEditor`: cancelling the override-function dialog no longer resets the stored function to "None" |
| Experiment run | `src/trial/becExp/BecExp/BecExp.m`, `src/mmParameter/BecExpSetting.m`, `BecControlPanel.mlapp` | Two new optional analyses, `KapitzaPhaseDiagram` and `ModulationMonitor`, each with a settings tab in the control panel; they do nothing unless switched on. Five new trial settings (see "Check before the next experiment"). `BecExp` now takes the Ad colormap from the `OdColormap` setting and reads the three `AdCustom...` settings. When `KapitzaPhaseDiagram` is on, STOP draws and saves its theory curves before stopping the run. Start, pause, resume and stop are otherwise unchanged |
| Analysis | `Ad.m`, `AdPreviewer.mlapp`, `computeKd.m`, new `KapitzaPhaseDiagram.m`, new `ModulationMonitor.m`, new `toolbox/plotting/renderAdGif2D.m` | `Ad`: animated GIFs for 2D scans, optional custom title and axis labels, fewer tick labels on long scans, default colormap changed from `jet` to `slanCM("inferno")`. Phase-contrast imaging in `Ad` and `AdPreviewer`: the phase-plate angle is read from the variable `hw_phasePlatePhi`. `computeKd`: lines reordered and an error message corrected, same calculation. The two new analysis classes read saved data and scope files only; they talk to no instrument |
| Fits | `src/math/FitData/FitData.m`, `FitData1D.m` | New `NPlot` setting for the number of points in fit plots; default 1000 as before |
| Simulation | `src/trial/sim/...`, new `convertSpaceStep.m` | Optional GPU mode for the Schrodinger-equation simulation, off by default. New `plotMomentum` plot. `convertSpaceStep` is new and not called yet |
| Other | four `.png` files in the repo root, `src/trial/becExp/app/App.prj`, `toolbox/plotting/render.m` | Four figure images and an app-packaging project file from another computer were added; neither is code and nothing uses them. `render.m`: colorbar width changed from 0.1 to 0.15 |

Full list: `git log v0..bbb314f` and `git diff --stat v0 bbb314f`.

### Left out on purpose

Six files in this folder were already uncommitted before this session. They are not part of this commit, were not changed and were not pushed:

- Modified: `src/hardware/WaveformGenerator/Keysight33500B.m`, `src/math/Waveform/ModulatedWaveform.m`, `src/math/Waveform/WaveformEditor.mlapp`
- New: `src/math/Waveform/SawtoothModulated.m`, `SawtoothOffset.m`, `SineSawtoothModulated.m`

A snapshot of them is kept in the local branch `backup/2026-10-08-before-update` (commit `39b2952`), on this computer only.

### How it was tested

- Nothing was run in MATLAB. `CLAUDE.md` and `CHANGELOG.md` are text files that MATLAB does not load.
- The update was a fast-forward: no merge and no conflicts. The six uncommitted files were compared with the snapshot before and after the update using git's content hashes: identical.
- The updated code has not been tested on this computer. See "Check before the next experiment".

### How to go back

Close the MuscleMuseum windows first, and reload MATLAB after switching. None of these commands loses anything: files that exist only in the newer version leave the folder on an older one and come back with `git switch li`. The zip command replaces a zip of the same name if one is already there.

| To get | Command |
|---|---|
| The code from before the update (commit `064c8ee`) | `git switch --detach v0` |
| The updated code without the two new documents (commit `bbb314f`, GitHub's `li` just before this push) | `git switch --detach bbb314f` |
| Back to the newest version | `git switch li` |
| A zip of the whole folder as it was on 2026-10-08 before the update, with the six uncommitted files | `git archive -o ../MuscleMuseum-2026-10-08-before-update.zip backup/2026-10-08-before-update` |

- The six uncommitted files stay where they are through every `git switch` above, because the update did not touch them. `v0` plus those six files is what this computer ran until 2026-10-08.
- On `v0`, `CLAUDE.md`, `CHANGELOG.md` and the files the update added are not in the folder. They return with `git switch li`.
- Tag `v0` is on this computer and on GitHub. The snapshot branch is on this computer only. Do not switch to it while the six files are in the folder; git will refuse.
- Git does not roll back the settings database. If `setParameter` has been run in the meantime, the old code still works with the extra columns as far as reading the code shows, but the dated copy of `mmParameter.db` is the certain way back.

## v0 - baseline

Tag `v0` marks commit `064c8ee` ("bug fix", 20 Apr 2026): the last committed version this computer ran until 2026-10-08, before the update above and before Claude's first change. The folder also held six uncommitted files at the time (listed under v1); they are not part of `v0`. No changes of its own.
