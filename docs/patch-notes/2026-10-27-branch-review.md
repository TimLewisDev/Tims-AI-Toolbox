# Review any git branch, locally: tt-mr-review is now tt-branch-review

- **Date:** 2026-10-27

## Why
`tt-mr-review` only worked on a GitLab merge request. It needed `glab` or a GitLab MCP server, took its diff and intent from GitLab, and ended by posting comments back. It could not be used in a GitHub, Bitbucket or Azure DevOps repository, or in a repository with no host at all, and an engineer who only wanted a review of a branch still had to have a merge request open.

## Added
- `tt-branch-review/scripts/resolve-branch.sh [--repo <dir>] [--against <base>] [branch]`: works out the branch to review and the base to compare it with, using git only. With no branch it takes the checked-out one. With no base it takes the remote's default branch (`origin/HEAD`), else the only one of `main`, `master`, `develop` and `trunk`; if there are several or none it stops and says to pass `--against`. It also prints the commit, merge base, commit and file counts, and whether the branch has uncommitted changes, and stops with a message for an unknown ref, a branch with no common ancestor, or no file changes.
- Tests for the script in `tools/test-scripts.sh`.

## Changed
- `tt-mr-review` is renamed `tt-branch-review`, and is run as `/tt-branch-review [branch] [against <base>]`.
- It reads the diff with `git diff` between the merge base and the branch's commit, and reads files from that commit, so the branch need not be checked out. The intent comes from the commit messages and the branch name; a ticket in an issue-tracker integration is read only if one is already available.
- The findings are shown in the chat and also written to a `Review.md` in the scratch folder outside the repo.
- The model roles are renamed to match: `mr-review-group` is `branch-review-group` and `mr-refute` is `branch-refute`, in `model-roles.tsv` and the `thorough` and `economy` modes. A model chosen for the old role names in `tt-config` is no longer applied; set it again.
- `tt-workflow` and `tt-guide` offer `/tt-branch-review` once a build is complete.

## Removed
- Posting. `scripts/post-notes.sh`, the approval questions for inline and summary comments, and the GitLab, `glab` and MCP requirement are gone. The skill is read-only: it changes nothing in the repo and posts nothing anywhere.

## Notes
- Anyone who typed `/tt-mr-review` needs to type `/tt-branch-review`. Pass the branch name; an MR number is no longer understood.
- Uncommitted changes are not reviewed; commit them first, or review a branch that has them.
- The review dimensions, the grouping, the parallel reviewers and the challenge of every serious finding are unchanged.
