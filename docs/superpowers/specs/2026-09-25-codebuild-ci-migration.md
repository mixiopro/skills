# AWS CodeBuild CI Migration Specification

## Goal

Run the repository's Linux GitHub Actions jobs on an AWS CodeBuild-hosted GitHub Actions runner, using the existing Mixio CodeBuild pattern, while preserving GitHub pull-request status checks. Keep Windows and macOS validation on GitHub-hosted runners where the active AWS region cannot provide equivalent CodeBuild images.

## Scope

- CodeBuild project name: `skills-ci`.
- AWS region: `ap-south-1`.
- GitHub source repository: `https://github.com/mixiopro/skills`.
- CodeBuild runner webhook event: `WORKFLOW_JOB_QUEUED`.
- Linux jobs use the project default Ubuntu 22.04 standard 7.0 image.
- Windows jobs remain on `windows-latest`; the required CodeBuild Windows image is not available in `ap-south-1`, and this migration does not provision a second-region Windows project.
- Every CodeBuild-backed job has a unique workflow label so concurrent jobs cannot be matched to the wrong ephemeral runner.
- The macOS public-installer check remains on `macos-latest`; CodeBuild-hosted GitHub Actions runners do not provide a GitHub Actions macOS runner platform.
- The maintainer tracking check remains functionally unchanged and is routed to CodeBuild Linux with its GitHub event context preserved by the Actions runner.

## Non-goals

- Replacing GitHub Actions workflow orchestration or pull-request status reporting.
- Creating a CodeBuild macOS reserved-capacity fleet.
- Adding credentials, tokens, or account secrets to the repository.
- Changing screenplay validation logic or the public installer contract.

## Acceptance criteria

1. `skills-ci` exists in `ap-south-1` with the repository source, existing CodeBuild GitHub runner service role, Ubuntu 22.04 standard 7.0 environment, and an active `WORKFLOW_JOB_QUEUED` webhook.
2. Linux jobs in `.github/workflows/skills-ci.yml` and `.github/workflows/public-installer.yml` request the `skills-ci` CodeBuild runner with unique labels; Windows jobs remain explicitly `windows-latest`.
3. `.github/workflows/mixio-tracking.yml` requests the same CodeBuild Linux runner with a unique label.
4. The Windows and macOS installer jobs remain explicitly GitHub-hosted and documented as regional/platform exceptions.
5. The existing repository checks continue to run without test or installer behavior changes.
6. AWS and GitHub verification separately identify the configured project, active webhook, and successful post-migration workflow run.
