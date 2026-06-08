---
name: publish
description: Orchestrate a pub.dev release from a release-ready `develop`. Runs the changelog-dated and docs-current gates, opens and merges the `develop → main` release PR (gated on green CI), then tags `vX.Y.Z` so the publish Action uploads to pub.dev. User invokes explicitly as /publish. Use when the user says "publish", "cut a release", "promote develop to main", or "release X.Y.Z".
---

# Release promotion (`/publish`)

This project ships to **pub.dev** as the `planner` package. Releases follow the
`develop → main` flow: work lands on `develop`, and a release is the deliberate
promotion of a release-ready `develop` to `main`, capped by a pushed `vX.Y.Z`
tag. This skill codifies the sequence that was run by hand for 0.3.0 and 0.3.1
so it is repeatable and hard to get subtly wrong. It is the release counterpart
to the start-work and cleanup skills.

**What pushes the package:** a pushed tag matching `v[0-9]+.[0-9]+.[0-9]+`
triggers [`.github/workflows/publish.yml`](../../../.github/workflows/publish.yml),
which runs `flutter pub publish --force` via pub.dev's GitHub Actions OIDC
integration (no stored tokens). pub.dev rejects a tag whose version does not
match `pubspec.yaml`, so the tag must be exactly `v<pubspec version>`. Because
that automation is live (issue #106 landed), **`/publish` stops at the pushed
tag** — it does not run `flutter pub publish` itself. See "Publish handoff"
below for the pre-automation fallback.

## Scope of this skill (first cut)

This skill does the **promotion only**. It assumes the version in
`pubspec.yaml` and the dated `CHANGELOG.md` entry are **already finalized on
`develop`** — it verifies them but does not create them.

**Out of scope (deliberate, decide later):** the *release cut* — bumping
`pubspec.yaml` and renaming a `## Unreleased` heading to `## X.Y.Z - <date>`.
If the user wants `/publish 0.3.2` to also do the bump, that is a future
enhancement (file an issue); today, finalize the version + changelog on
`develop` first, then run `/publish`.

## Step 1 — Preconditions

Stop and report if any fail; do not work around them.

1. `gh auth status` succeeds and `git remote -v` shows the GitHub remote.
2. Working tree is clean (`git status --porcelain` empty).
3. On `develop` and up to date with `origin/develop`:
   ```
   git fetch origin
   git rev-parse --abbrev-ref HEAD            # must be: develop
   git rev-list --count origin/develop..HEAD  # must be: 0 (nothing unpushed)
   git rev-list --count HEAD..origin/develop  # must be: 0 (nothing unpulled)
   ```
4. `develop` is ahead of `main` (there is something to release):
   ```
   git rev-list --count origin/main..origin/develop   # must be > 0
   ```
5. Read the target version from `pubspec.yaml` (the `version:` line). Call it
   `X.Y.Z`; the tag will be `vX.Y.Z`. Confirm `vX.Y.Z` does not already exist
   (`git tag -l vX.Y.Z` empty, and no GitHub release for it) — a re-tag will not
   re-publish and signals the version was never bumped.

## Step 2 — Up-to-date gates (block before anything is pushed)

These run **before** the PR is opened. If any fails, stop and tell the user what
to fix on `develop` — do not promote a release with a stale changelog or docs.

### 2a. Changelog is dated and matches the version

`CHANGELOG.md` must have a **dated** entry for the pubspec version as its top
section — `## X.Y.Z - <date>`, **not** `## Unreleased` and not undated. The date
should be today's date (`<date>` in `YYYY-MM-DD`, matching the existing entries).
If the top entry is still `## Unreleased`, or its version ≠ the pubspec version,
or it carries no date: **stop** — the release was not cut on `develop` yet.

Capture this section's body now; it becomes the GitHub release notes in Step 5.

### 2b. Docs reflect the released features

Surface a checklist for **explicit user confirmation** rather than silently
proceeding — you cannot fully verify prose is current, so make the human decide:

- `README.md` and `doc/*.md` describe the features being released (no TODOs or
  references to unreleased/removed behavior).
- If anything **visual** changed in this release, the screenshots were
  regenerated and committed. They are produced reproducibly from the example app
  via `example/integration_test/screenshots_test.dart` (a standalone capture
  target, *not* part of the test suite). Regenerate with, from `example/`:
  ```
  flutter test integration_test/screenshots_test.dart -d windows
  ```
  then commit the updated PNGs under `doc/screenshots/` (and any README images)
  **on `develop`** before promoting. Note: pub.dev strips relative `<img src>`
  from the README, so README screenshots must use absolute `raw.githubusercontent.com`
  URLs (see CHANGELOG 0.3.1).

Show the user the changelog section + a one-line docs/screenshots summary and
ask them to confirm before continuing.

### 2c. Package and analysis are clean

```
flutter pub publish --dry-run     # 0 warnings
flutter analyze                   # clean
flutter test                      # green
```
`flutter pub publish --dry-run` is the gate that most often catches packaging
regressions (missing files, bad `pubspec`, oversized package). If analyze/tests
are about to run on the PR anyway, you may defer the heavy suites to CI, but the
**dry-run must be clean locally** before promoting.

## Step 3 — Open the release PR and wait for CI

Open the `develop → main` PR (base `main`, head `develop`):

```
gh pr create --base main --head develop \
  --title "Release vX.Y.Z" \
  --body "<summary + the changelog section for X.Y.Z>"
```

Two CI checks gate this PR, both from [`.github/workflows/ci.yml`](../../../.github/workflows/ci.yml):
- **`verify`** — format check, `flutter analyze`, `flutter test` (runs on every PR).
- **`integration (windows)`** — the full Windows integration suite
  (`example/integration_test/app_test.dart`). This job is gated to run **only**
  on a PR whose base is `main`, i.e. exactly this release PR, so it will not have
  run on the feature PRs into `develop`.

Wait for **both** green before merging:
```
gh pr checks <PR-number> --watch
```
If a check fails, stop — fix on `develop` and let it re-run. Do not merge red.

## Step 4 — Merge and sync `main`

The repo uses merge commits for PRs (see history). Merge the release PR with a
merge commit, then sync local `main`:
```
gh pr merge <PR-number> --merge
git checkout main
git pull --ff-only
```
`main`'s HEAD is now the release merge commit.

## Step 5 — Tag and create the GitHub release

Tag the merge commit on `main` and push the tag — **this is the publish
trigger**:
```
git tag vX.Y.Z          # on main's HEAD (the merge commit)
git push origin vX.Y.Z
```
Then create the GitHub release using the changelog section (from Step 2a) as the
notes:
```
gh release create vX.Y.Z --title "vX.Y.Z" --notes "<the X.Y.Z changelog section>"
```
Pushing the tag starts [`publish.yml`](../../../.github/workflows/publish.yml).
Watch it to confirm the upload succeeds:
```
gh run watch
```

### Publish handoff (fallback only)

The automated publish is live, so normally you stop after the tag + release and
let the Action upload. **Only** if the publish automation is unavailable
(disabled, or running on a checkout from before #106) do the upload by hand —
and note that `/publish` cannot do it autonomously, because the first run needs
the owner-gated pub.dev OAuth:
```
flutter pub publish        # interactive; requires the package owner to authorize
```
Hand this step to the user; do not attempt the OAuth flow unattended.

## Step 6 — Post-release

1. Confirm the `publish.yml` run went green and the new version is live on
   `https://pub.dev/packages/planner`.
2. Remind the user to eyeball the pub.dev page: screenshots render (absolute
   image URLs) and repo-internal README links resolve — the latter only after
   pub.dev's async analysis settles, which can take a few minutes after publish
   (see issue #105).
3. The release is done. Back on `develop`, the next cycle starts a fresh
   `## Unreleased` (or the next version's) changelog section.
