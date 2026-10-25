# GitHub and Git LFS synchronization

The current development branch is `codex/opening-quality`. It contains the earlier local development branches, Claude's large asset/gameplay passes and the four small story/crop corrections. Uploading this branch publishes their shared commit history; it does not merge into `main`.

## Local audit, 2026-10-25

- Git LFS 3.8.0 and the LFS pre-push hook are installed. Models, native Blender sources, audio, terrain heightmaps and native libraries have LFS attributes.
- `git lfs fsck --dry-run --objects --pointers origin/codex/lookout-radio-opening..HEAD` passed before the remaining animal checkpoint. The historical unpublished assets were locally present and their pointers valid.
- There were 123 unpublished commits before the remaining local files were committed. No ordinary Git blob in that unpublished range was 10 MB or larger, so no 100 MB GitHub file-limit violation was found there.
- The remaining animal pass includes deer/wolf/bear models and generators, articulated lower legs, the shared fur shader, carcass material support, its tests/capture source and the existing review images. Animal checks passed 13/13 and food-web checks 17/17. No additional gameplay changes were made for synchronization.
- A static scan found 195 existing literal runtime file references and none missing or outside the index after staging. This is a literal-reference check, not an exhaustive dynamic loader/build certification.
- Generated Python bytecode is excluded. Previously tracked bytecode is removed from the index while the local files are retained. Godot caches, builds and raw downloaded audio remain excluded.

## Authentication and upload

An `Access denied` error writing `.git/lfs/tmp` is a local filesystem/agent permission issue, not proof of asset corruption or GitHub quota exhaustion. Git fetch may work anonymously while uploads still need authentication. During this audit, Git/LFS had no usable GitHub credential and GitHub CLI was signed out. Authenticate locally; never put a password or access token in this repository or its documentation.

```powershell
gh auth login --hostname github.com --git-protocol https --web
gh auth setup-git --hostname github.com
git lfs fsck --objects --pointers
git lfs push --all origin codex/opening-quality
git push --set-upstream origin codex/opening-quality
```

Here `--all` belongs to **LFS**, scoped to this branch: it uploads asset versions reachable through its history, including older Blender/model versions. It does not force-push or publish every local Git branch. Publish recovery tags explicitly after checking their targets. There is no reason to rewrite history or disable the LFS pre-push hook based on the successful local integrity check.

If GitHub reports an LFS storage/bandwidth or billing limit after authentication, retain the local assets and commits and resolve that specific account restriction; successful ordinary Git upload alone does not prove that LFS assets are recoverable.

## Verify recovery

Confirm the remote branch hash equals local `HEAD`. Verify LFS availability from a separate temporary download/cache so the existing local LFS objects cannot hide missing remote files. Check both the current checkout and historical versions before calling the backup complete. A fresh machine also needs Git LFS and a Godot import pass:

```powershell
git clone --branch codex/opening-quality https://github.com/EarthDeparture/brave_and_cold.git
cd brave_and_cold
git lfs pull
git lfs fsck --objects --pointers
```
