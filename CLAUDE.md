# MuscleMuseum: rules for Claude

MuscleMuseum is the MATLAB software that runs the experiments on this computer. Claude is used here to add features, improve existing code, build GUIs and troubleshoot. **Every change must be traceable.**

This folder (`C:\Users\scientist\Documents\MuscleMuseum`) is the copy MATLAB actually runs: it is on MATLAB's saved path, and this computer (`T1000`) is the main experiment control computer. An edit here is an edit to the live experiment code.

This file was written on that computer and for it. In a copy of the repo on another computer the five rules still apply, but check the facts in the notes below (folder, commit label, devices) before relying on them.

## Rules

1. **Review first.** After making changes, show the user what changed and how to test it. Don't commit until the user has tested and approved. If the user needs to run an experiment before approving, set the changes aside so the code is back to the last pushed version.
2. **Changelog on every push.** Before each push, add a dated entry to `CHANGELOG.md` saying what changed and why, and include it in that push.
3. **Versions to return to.** Tag every push (`v1`, `v2`, `v3`, ...) and note the tag in the changelog entry. If the user asks to go back to an earlier version, show what will change first, and never delete history.
4. **Hardware.** Never run anything that talks to the experiment hardware without asking the user first.
5. **Never force-push.**

The user may add more rules. Add each new rule to this list with the next number, and record the addition in `CHANGELOG.md` like any other change.

## How to apply the rules in this repo

These notes say how to carry out the five rules in this repo. Where a note asks for more caution than a rule's own words, it says so, and the user can strike it.

### Git basics

- Remote `origin` is `https://github.com/weldlabucsb/MuscleMuseum`. Work on branch `li`. Commits made in this folder are labelled `pk` (set in this folder's git config).
- At the start of a session run `git status`, `git stash list` and `git fetch`. Before changing files, tell the user if anything is uncommitted, set aside in a stash, ahead or behind, or if `git status` says `HEAD detached` (the folder is on an old version: change nothing until it is back on `li`).
- `git fetch` only updates the record of what is on GitHub. Never bring new commits into this folder (`git pull`, `git merge`) without showing the user what would arrive (`git log --oneline HEAD..origin/li`, `git diff --stat HEAD origin/li`) and getting a yes: it changes the code the experiment runs. After a yes use `git merge --ff-only origin/li` and describe the update in the next changelog entry.
- Uncommitted work that was already there when the session started belongs to the user. Never commit, stash, overwrite or discard it without asking. Ask before editing a file that already has uncommitted changes: afterwards git cannot tell the user's edits from the session's.
- Stage files by name and commit only what was staged. Never use `git add -A`, `git add .`, `git commit -a`, or `git stash` without file names.
- Never put scratch files, copies of the repo or git worktrees inside this folder. `init` adds every subfolder to the MATLAB path, so duplicate class files would shadow the real ones.
- `.mlapp` files are zip archives, so git cannot show what changed inside them. To review GUI code, compare the code file inside, using Git Bash: `unzip -p <file>.mlapp matlab/document.xml` prints the current code. For the committed version, write a copy outside the repo (`git show HEAD:<path>.mlapp > <temp folder>/old.mlapp`) and run the same `unzip -p` on it.

### Rule 1: setting changes aside

- Set aside only the files changed in this session: `git stash push -u -m "<what this is>" -- <file> <file> ...`. If `git status --short` shows a session file with `D` or `R` in the first column (a staged deletion or rename), unstage it first with `git restore --staged -- <path>`; this changes no file.
- Always check the result: `git status` must show the folder as it was before the session, and `git stash list` must show exactly one new entry. A wrong file name makes git stop with `fatal: pathspec ... did not match`, yet it still saves a stash entry and leaves every file in the folder. In that case correct the names, run the command again, and tell the user about the extra entry; do not pop or drop it.
- If the user's own uncommitted files are still in the folder, say so: the code is then the last pushed version plus those files.
- Bring the changes back while on branch `li`: find the entry with `git stash list`, then `git stash pop <number>`. If git reports a conflict, stop and tell the user: the stash is kept, but the file now holds conflict markers and will not run. Tell the user both commands. Never drop or clear a stash without asking.
- MATLAB keeps class definitions in memory. After files change (edit, set aside, restore, update, version switch), tell the user that the open MATLAB session keeps running the old code until the MuscleMuseum windows are closed and `clear classes` is run, or MATLAB is restarted. `clear classes` also empties the workspace, so the user chooses the moment; Claude never runs it.

### Rules 2 and 3: pushing

Start only after the user has tested the change and approved it (rule 1).

1. Run `git fetch` and `git status -sb`. If it says `behind`, GitHub has newer commits: tell the user and settle that first (see step 5). Then find the next tag: `git tag --list "v[0-9]*" --sort=-v:refname` lists the version tags, highest first; use the next number. Tags are shared by every copy of the repo through GitHub.
2. Add the entry at the top of `CHANGELOG.md`: heading `## vN - YYYY-MM-DD`, then what changed, why, how it was tested, and anything left out on purpose.
3. Stage the changed files and `CHANGELOG.md` by name, check that `git diff --cached --stat` lists only those files, and commit. Then tag that commit: `git tag -a vN -m "vN: <one line>"`.
4. Push the branch and the tag together: `git push --atomic origin li vN`. Confirm they arrived: `git ls-remote origin li vN` must show `refs/heads/li` at the same id as `git rev-parse HEAD`, and `refs/tags/vN`.
5. If the push is rejected, do not force and do not rebase. With `--atomic` nothing was pushed. If GitHub has newer commits: `git fetch`, show the user what arrived, then stop and ask, because bringing them in changes the code this computer runs. After a yes: `git merge --no-commit origin/li` (plain `git merge` would commit the combined code at once, before the user has tested it). If git refuses to start or reports a conflict, run `git merge --abort` if a merge is in progress, tell the user and go no further. Otherwise have the user reload MATLAB and test again. If the user does not approve, or needs to run an experiment first, `git merge --abort` puts the folder back to the commit the user tested. After approval, add what arrived to the `vN` changelog entry, stage `CHANGELOG.md` and commit (this one commit completes the merge), move the tag to the new commit (`git tag -d vN`, then tag again; allowed only because `git ls-remote` shows the tag never reached GitHub), and push again.

Never, in any situation:

- With `git push`: `--force`, `-f`, `--force-with-lease`, `--mirror`, `--prune`, `--delete`, or a refspec that starts with `+` or `:`.
- `git reset --hard` or `git clean`, and `git checkout -- <file>` or `git restore <file>` on a file holding uncommitted work the session did not make. These destroy uncommitted work with no way back.
- Changing commits that have been pushed (`git commit --amend`, `git rebase`).
- Deleting branches (including `backup/*`), dropping or clearing a stash without the user's yes (a `git stash pop` that applies cleanly removes its own entry and is fine), or deleting or moving a tag that has been pushed.

### Rule 3: going back to an earlier version

- First show what will change: `git log --oneline vOLD..HEAD` (commits that will be left out), `git diff --stat HEAD vOLD` (files that will change) and `git status --short` (uncommitted work in the folder now).
- **To run an old version for a while:** `git switch --detach vOLD`. Uncommitted files that the switch does not need to change stay in place. If git refuses because a file "would be overwritten", nothing has changed: stop and ask, and never add `-f` or `--force`. Return with `git switch li`. While on an old version do not edit or commit. On a version before `v1`, `CLAUDE.md` and `CHANGELOG.md` are not in the folder; the rules still apply. Git does not roll back the settings database.
- **To make an old version the current one again:** never move the branch back. With the user's yes, bring the old files into the folder with `git restore --source=vOLD --staged --worktree -- . ':(exclude)CLAUDE.md' ':(exclude)CHANGELOG.md'`, adding one more `':(exclude)<file>'` for every file that `git status` lists as modified or untracked and that the session did not make. `git restore` overwrites every uncommitted file it is given without warning, so never run it without those excludes. Afterwards `git diff --stat vOLD -- . ':(exclude)CLAUDE.md' ':(exclude)CHANGELOG.md'` must list only the excluded files. The user then tests, and the commit, changelog entry and tag follow after approval like any other push.
- Use `git revert` only as `git revert --no-commit <commit>` on one ordinary commit. Plain `git revert` commits at once, which breaks rule 1, and it stops part-way on merge commits, of which this history has many.

### Rule 4: what counts as talking to hardware

Reading source code is always fine. Creating a hardware object and reading its properties sends nothing. Ask the user before running any of the following, whether from a MATLAB command, a script or a GUI:

- Any method of a class in `src/hardware`. Examples: `connect`, `set`, `upload`, `trigger`, `triggerchannel`, `read`, `lock`, `unlock`, `check` and `close` on a waveform generator, scope or phase lock; `connectCamera`, `setCameraParameter...`, `setCallback`, `startCamera`, `pauseCamera`, `stopCamera` and `resetCameraConnection` on a camera.
- Anything that talks to an instrument directly: `visadev`, `serialport`, `videoinput`, `oscilloscope`, `imaqreset`, the Andor SDK functions (`AndorInitialize`, `AndorShutDown`, ...), and `writeline`, `write`, `query`, `writeread`, `readline` or `readbinblock` on a device handle.
- Opening `WgControlPanel`, `ScopeControlPanel` or `PhaseLockControlPanel`: they connect as they open, and the scope panel also writes settings to the scope. Every button inside them reaches the device. Closing one that was opened on its own disconnects the device.
- In `HardwareControlPanel`: Connect, Connect All, Disconnect, Disconnect All, Upload, Scan, closing the window while devices are connected, and calling the panel's methods from the command line. Upload and Scan act on every connected device, not one.
- In `BecControlPanel`: START, PAUSE, RESUME, STOP, FAST STOP, Reset Image Acquisition, and closing the window during a run. The same goes for `BecExp` `start`, `pause`, `resume`, `stop`, `fastStop`, `setHardware`, `unlock`, `updateHardware` and `fetchHardwareLog`.
- Copying files into the data folder of a running trial. Each finished run reads the connected scopes and, in a scan, uploads the next step; when images are not auto-acquired, new image files in that folder count as a finished run.
- The test scripts `testBeatLock`, `testBasler`, `testPCO`, `testTektronix`, `testKeysight`, `onsiteTest` and `localTest`, and `runtests` on the `test` folder.
- Code outside this repo that is on MATLAB's path: the Andor SDK wrappers in the MATLAB folder, and the user's scripts in `Documents\MMUser\script` (for example `setLatticeModulation` writes commands to a connected generator).

Two things that look safe but do reach the instruments:

- **Local Test** in `BecControlPanel` only skips the camera. If the chosen trial type has hardware associations, START still opens `HardwareControlPanel`, connects the associated devices and uploads to every connected device.
- **`set(obj)`** on a connected generator or scope is the driver's configure command, not a property listing. On a Keysight generator it switches the outputs off and clears waveform memory. The Reset button in `WgControlPanel` is this command, and `close` runs it too when the generator reports an error.

The next items do not talk to an instrument, so rule 4's own words do not cover them. They are listed because they change the settings database, what the next upload sends, or a running experiment. Ask first all the same, unless the user says otherwise:

- **Starting MATLAB from the terminal** (`matlab -batch ...`). It is not a sandbox: any MATLAB on this computer starts with this folder on its path and uses the same settings database, the same PostgreSQL databases and the same instruments as the experiment session.
- **`init`, `setParameter` and `setDatabase`.** `setParameter` (also the Run SetParameter button in `BecControlPanel`) empties and refills settings tables in `Documents\MMUser\config\mmParameter.db` from `mmConfig.m`; a device no longer listed there is deleted with its saved settings and trial associations. `setDatabase` logs in to the local and remote PostgreSQL servers as administrator. `init` runs both and ends with `clear` and `close all`.
- **Editing the waveform library, scan lists, variable values, device settings or hardware associations.** Nothing is sent at once, but these entries are what the next Upload, START or scan step sends to the instruments.
- **Opening `BecControlPanel` or `HardwareControlPanel`.** They connect to nothing, but both write to the settings database as they open.
- **Creating a `BecExp` or a simulation object.** It creates a data folder on the experiment data drive and a row in the experiment database.
- **Parallel-pool work, including simulations.** It shares the pool with the live Andor camera loop. Do not run it, or start or delete the pool, in the experiment's MATLAB session while data is being taken.

Devices listed in `Documents\MMUser\config\mmConfig.m` on 2026-10-08: camera `TOP` (Andor iXon 897); waveform generators `ShakenTrap` and `SWAP` (Keysight 33600A); scopes `QpdScope` and `LatticeScope` (Tektronix 1104); phase lock commented out. The GUIs read the device tables in `mmParameter.db`, which follow `mmConfig.m` only after `setParameter` runs, so confirm with the user before relying on this list.

When unsure whether something reaches hardware, treat it as hardware and ask.

### Other facts worth knowing

- MATLAB R2023a is the release installed here and the only one the README says was tested; later releases may break the database functions.
- Settings live outside this repo in `Documents\MMUser`, a separate git repository on its own branch (`sr`). It holds the user's uncommitted changes, including the live `mmParameter.db`. The rule about the user's uncommitted work applies there too.
- The settings database has its own table layout. When an update changes a class in `src/mmParameter`, the new columns reach `mmParameter.db` only when `setParameter` runs. After every update, check `git diff --stat <old> <new> -- src/mmParameter` and tell the user if `setParameter` is needed before the next run.
- Keep exactly one copy of this repo on the MATLAB path, in a folder named `MuscleMuseum`. `init` finds the repo by looking for a path entry that ends in `MuscleMuseum`.
- There is almost no automated testing: one unit test (`test/testBecExp/testObj2struct.m`), and otherwise hand-run scripts, several of which talk to hardware. Testing a change means the user trying it in MATLAB, so "how to test it" must be concrete steps the user can follow.
