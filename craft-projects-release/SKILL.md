---
name: craft-projects-release
description: Release and deploy Craft CMS projects in this folder after the developer tested the updates locally and on staging. Use when asked to release or deploy the Craft projects. Optional argument: project folder names to limit the run.
---

# craft-projects-release

Runs after `craft-projects-update`, once the developer tested everything locally and on
staging. Project-specific settings live in each project's `CLAUDE.md` under `## Maintenance`.
Never add project names or paths to this file.

## Hard rules

- Ask before every push to `main` or `master`, once per project, in chat. Show what will be pushed.
- Never force-push. Never stash, reset or discard changes.
- A failure stops that project only.

## 1. Select projects

- Projects = direct subfolders with a `CLAUDE.md` that contains `## Maintenance`.
- If the user named projects as arguments, use those. Otherwise list the projects with
  something to release (see step 2) and ask which ones to release.

## 2. Check what is pending

Run `git fetch` first. Then, per `release` value:

- `push`: commits in `git log --oneline origin/<production-branch>..<production-branch>`.
- `tagged`: commits on `origin/<base-branch>` since the last tag (`git describe --tags --abbrev=0`).

Nothing pending: report "nothing to release" and skip. Working tree not clean: report and skip.

## 3. Release

`release: push`

1. `git checkout <production-branch>`
2. Show the pending commits. Ask for confirmation.
3. `git push origin <production-branch>`. No tags.

`release: tagged`

1. Run the commands of the `## Releasing` section in the project's `CLAUDE.md`, in order.
2. Before the first push to `<production-branch>`, stop. Show the new version, the changelog
   entry and the commits. Ask for confirmation.
3. Commands that only push `<base-branch>` (staging) may run without asking.

## 4. Summary

| Project | Release type | Version / commits | Pushed | Deploy |

Take the `Deploy` column from the `deploy` key. Mark every project whose `deploy` contains
`manual` as "manual deploy needed" so the developer knows to run the SSH deploy script.

## 5. Release log

Run this last, after the summary, whenever at least one project was checked.
Write one Markdown file to `<this folder>/_logs/` (the folder that holds the projects; create
`_logs` if missing). The developer imports it into Joplin via a hotfolder, so write a new
file every run and never edit an old one. Write the log in German.

- File name: `release-YYYY-MM-DD-HHMM.md` (local time at the end of the run, e.g.
  `release-2026-10-23-1124.md`). No `:` in the file name: macOS and sync tools break on it.
  If the file exists, append `-2`, `-3`, ….
- First line: `# Release YYYY-MM-DD-HH:MM` (same time).

One section per released project, in release order:

```markdown
## <project> <new version>

- Release: <release value> · Gepusht: <branches and tag> · Deploy: <deploy value>
- **Manuelles Deploy nötig**   ← only if `deploy` contains `manual`

<changelog entry>

**Commits**

- `<short hash>` <subject>
```

- Changelog entry (`tagged`): the new version's section from the project's `CHANGELOG.md`,
  from its `## [<version>]` heading up to the next `## ` heading. Drop that version
  heading (the section heading already names it). Shift the remaining headings down one
  level (`###` → `####`). Empty entry: write `_Kein Changelog-Eintrag (nur chore/docs)._`.
- Commits: `tagged`: `git log --oneline --no-merges <previous tag>..<new tag>` without the
  `chore(release)` commit. `push`: the pushed commits. Omit the version in the heading.

Then a closing section with everything that needs attention, only the items that apply:

```markdown
## Besonderheiten

- Übersprungen, weil nichts ansteht: <projects>.
- Übersprungen, weil nicht sauber: <projects>.
- Push abgelehnt: <projects>.
- Fehlgeschlagen: <project>: <short error>.
- Manuelles Deploy nötig: <projects>.
- Hinweise: <e.g. Dependabot or other warnings from push output, empty changelog entries>.
```

Report the file path in chat.
