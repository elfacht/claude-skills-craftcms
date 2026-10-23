---
name: craft-projects-update
description: Update all Craft CMS projects in this folder with ddev (craft update all), check URLs and sitemaps, run E2E tests and commit or open a PR per project. Use when asked to update the Craft projects / Craft installations. Optional argument: project folder names to limit the run.
---

# craft-projects-update

Updates every Craft CMS project in this folder. Project-specific settings live in each
project's `CLAUDE.md` under `## Maintenance`. This skill holds only the generic flow.
Never add project names or paths to this file.

## Hard rules

- Never push to `main` or `master` without explicit confirmation from the user in chat.
- Never stash, reset, discard or overwrite existing changes in a project.
- Commits and squash-merge titles are Conventional Commits.
- Do not create GitHub issues. Do not touch git submodules.
- Process projects one after another. A failure stops that project only, not the run.

## 0. Start containers

Run `ddev start --all` once, before anything else. It starts every ddev project that is not
running. `craft-projects-release` stops them again at the end with `ddev stop --all`, after the
user confirms.

## 1. Discover projects

- Projects = direct subfolders with a `CLAUDE.md` that contains `## Maintenance`.
- If the user named projects as arguments, limit the run to those.
- Folders with a `.git` but without the block: list them as "not configured" in the summary.
- Parse the YAML block. Keys:

| Key | Meaning |
| --- | --- |
| `git-flow` | `pr` = feature branch + PR, `direct` = commit on `production-branch` |
| `base-branch` | `pr`: branch to start from and PR target. `direct`: same as `production-branch` |
| `production-branch` | `main` or `master` |
| `merge-after-tests` | `true`: squash-merge the PR when all checks pass. `false`: stop at the PR |
| `e2e` | Command run from the project root, or `none` |
| `deploy` | Info only, shown in the summary |
| `release` | Used by `craft-projects-release` |

## 2. Detect paths and URL (not configured)

- ddev root: the folder that contains `.ddev/` (project root, or `cms/` / `app/`).
  Run every `ddev` command from there.
- Craft root: the folder that contains the `craft` executable.
- Craft command: if Craft root = ddev root, use `ddev craft <cmd>`. Otherwise `ddev craft`
  fails with `Could not open input file: ./craft`. Then use
  `ddev exec -d /var/www/html/<craft-root-relative-to-ddev-root> php craft <cmd>`
  (e.g. `-d /var/www/html/app`). All `ddev craft` commands below mean this command.
- Project URL: `ddev describe -j | jq -r '.raw.primary_url'`.

## 3. Preflight

Stop the project and report the reason if any check fails.

1. `git status --porcelain` is empty. Otherwise report the dirty files and skip.
2. `git checkout <base-branch> && git pull --ff-only`.
3. `ddev start`.
4. Note current versions: `ddev craft update` (lists pending updates). No updates: report "up to date" and skip.
5. Backup: `ddev snapshot --name pre-update-$(date +%Y%m%d-%H%M)`.

## 4. Branch (`git-flow: pr` only)

`git checkout -b chore/update-craft-cms-to-<version-without-dots>`, e.g. `chore/update-craft-cms-to-51015`.
Use the new `craftcms/cms` version. If only plugins update: `chore/update-craft-plugins-<yyyymmdd>`.

## 5. Update

```bash
ddev craft update all --interactive=0
ddev craft clear-caches/all
```

If the update fails: stop the project. Show the error. Point to the snapshot
(`ddev snapshot restore <name>`). Do not restore without confirmation.

## 6. Checks

Steps 1 and 2: run `bash <this skill folder>/sitemap-check.sh <url>`. It prints `ROOT <code>`,
one `SITEMAP` line per sitemap, `BAD <code> <url>` per failing page and `PAGES <n> NON200 <n>`.

1. Project URL returns `200`: `curl -sk -o /dev/null -w '%{http_code}' <url>`.
2. Sitemap: request `<url>/sitemap.xml`. Collect every `<loc>`. A `<sitemapindex>` links more
   sitemaps: fetch them too, recursively. Request every page URL and collect non-`200` codes.
   If `<loc>` hosts differ from the ddev URL, replace the host with the ddev URL.
   No sitemap (`404`): note it, do not fail.
3. If `e2e` is not `none`: run it from the project root.

All checks pass = no non-`200` URL and E2E green (or `none`).

## 7. Commit

- Stage only files changed by the update (typically `composer.json`, `composer.lock`,
  `config/project/**`). Show `git status` if anything else changed and ask.
- Message: `chore(deps): update craft cms to <version>` plus a body listing every updated
  package `name old → new`. Plugins only: `chore(deps): update <plugin> to <version>`
  (several plugins: `chore(deps): update craft plugins`).
- `direct` and checks failed: do not commit. Report and leave changes for the user.

## 8. Finish per flow

`git-flow: direct`

- Commit stays local on `production-branch`. No push. Pushing is done by `craft-projects-release`.

`git-flow: pr`

1. `git push -u origin <branch>`
2. `gh pr create --fill --base <base-branch>` (add the check results to the PR body).
3. If `merge-after-tests: true` and all checks pass:
   `gh pr merge -s -d --subject "chore(deps): update craft cms to <version>"`, then
   `git checkout <base-branch> && git pull --ff-only && git checkout <production-branch>`.
4. Otherwise leave the PR open and report why.

## 9. Summary

One table for all projects:

| Project | Flow | Craft old → new | URL | Sitemap (non-200) | E2E | Result (commit / PR link / merged) |

Below it: skipped projects with reason, "not configured" folders, snapshot names, and
the `deploy` note of every project that needs a manual step.
