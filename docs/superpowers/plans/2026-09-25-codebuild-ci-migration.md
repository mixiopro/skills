# AWS CodeBuild CI Migration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Route the repository's Linux and Windows GitHub Actions jobs through the AWS CodeBuild-hosted runner project `skills-ci` while retaining the macOS check as an explicit GitHub-hosted exception.

**Architecture:** Keep GitHub Actions as the workflow and status-check layer. Create one CodeBuild runner project in `ap-south-1` with a `WORKFLOW_JOB_QUEUED` webhook; jobs opt into it with the required dynamic `codebuild-skills-ci-${{ github.run_id }}-${{ github.run_attempt }}` label. Use separate unique labels for each job and a Windows image override so one project can serve both Linux and Windows jobs.

**Tech Stack:** GitHub Actions YAML, AWS CodeBuild-hosted GitHub Actions runners, AWS CLI, Bash, PowerShell, existing repository validation scripts.

**Spec:** `docs/superpowers/specs/2026-09-25-codebuild-ci-migration.md`

## Global Constraints

- CodeBuild project name is `skills-ci` and AWS region is `ap-south-1`.
- The repository source is `https://github.com/mixiopro/skills`.
- CodeBuild receives `WORKFLOW_JOB_QUEUED` events and uses the existing Mixio GitHub runner service-role pattern.
- Linux uses Ubuntu 22.04 standard 7.0; Windows uses the `windows-3.0` override with a medium instance.
- macOS remains `macos-latest` until a separate CodeBuild macOS fleet is provisioned.
- No credentials or tokens may be committed.
- Existing validation commands and public installer behavior remain unchanged.

---

### Task 1: Route CI workflows to the CodeBuild runner

**Files:**
- Modify: `.github/workflows/skills-ci.yml`
- Modify: `.github/workflows/public-installer.yml`
- Modify: `.github/workflows/mixio-tracking.yml`

**Interfaces:**
- Consumes: the CodeBuild project name and image labels defined by the specification.
- Produces: GitHub Actions jobs that request ephemeral CodeBuild runners using unique labels.

- [ ] **Step 1: Update Linux and Windows runner labels in `skills-ci.yml`**

Use the dynamic base label `codebuild-skills-ci-${{ github.run_id }}-${{ github.run_attempt }}`. Add `skills-linux-validation` to the Linux job and add `image:windows-3.0`, `instance-size:medium`, and `skills-windows-installation` to the Windows job.

- [ ] **Step 2: Split the public installer Unix matrix into Linux and macOS jobs**

Run the existing Unix validation command on a CodeBuild Linux runner with `public-installer-linux`; keep the same command on `macos-latest` with no CodeBuild labels. Route the existing Windows validation command to CodeBuild with `image:windows-3.0`, `instance-size:medium`, and `public-installer-windows`.

- [ ] **Step 3: Route maintainer tracking to CodeBuild Linux**

Replace only the `runs-on` value in `mixio-tracking.yml` with the dynamic CodeBuild label plus `maintainer-tracking`. Preserve the tracking script and all GitHub event environment behavior.

- [ ] **Step 4: Parse the modified workflow YAML locally**

Run:

```bash
python3 - <<'PY'
from pathlib import Path
import yaml
for path in Path('.github/workflows').glob('*.yml'):
    yaml.safe_load(path.read_text())
    print(f'parsed {path}')
PY
```

Expected: all workflow files parse successfully.

- [ ] **Step 5: Commit the workflow routing change**

```bash
git add .github/workflows/skills-ci.yml .github/workflows/public-installer.yml .github/workflows/mixio-tracking.yml
git commit -m "ci: route validation jobs through CodeBuild"
```

### Task 2: Document the CodeBuild runner contract

**Files:**
- Create: `docs/codebuild-ci.md`

**Interfaces:**
- Consumes: the workflow labels and AWS project values from Task 1.
- Produces: operator documentation for provisioning, verifying, and retiring the runner project without exposing credentials.

- [ ] **Step 1: Document the project and label contract**

Include the exact project name, region, source repository, webhook event, Linux default image, Windows override, unique labels, and the macOS exception.

- [ ] **Step 2: Document AWS and GitHub verification commands**

Include read-only commands using `aws codebuild batch-get-projects`, `aws codebuild list-projects`, `gh pr checks`, and `gh run view`. State that the CodeBuild GitHub connection and service role must already exist.

- [ ] **Step 3: Document rollback**

Explain that restoring `runs-on: ubuntu-latest`, `runs-on: windows-latest`, and the original macOS matrix restores GitHub-hosted execution; do not prescribe deleting the AWS project as part of routine rollback.

- [ ] **Step 4: Verify documentation paths and shell snippets**

Run:

```bash
git diff --check
rg -n 'skills-ci|WORKFLOW_JOB_QUEUED|macos-latest|windows-3.0' docs/codebuild-ci.md
```

Expected: no whitespace errors and every required contract term is present.

- [ ] **Step 5: Commit the documentation**

```bash
git add docs/codebuild-ci.md
git commit -m "docs: describe CodeBuild CI runner"
```

### Task 3: Provision and verify the AWS CodeBuild project

**Files:**
- No repository files; AWS resource change authorized by the migration request.

**Interfaces:**
- Consumes: the source repository, project name, existing service role, and region from the specification.
- Produces: active CodeBuild project `skills-ci` and a webhook filtering `WORKFLOW_JOB_QUEUED`.

- [ ] **Step 1: Confirm project absence and existing runner role**

Run:

```bash
aws codebuild list-projects --region ap-south-1
aws codebuild batch-get-projects --region ap-south-1 --names studio-ci
```

Expected: `skills-ci` is absent and `studio-ci` identifies the existing service-role/image pattern.

- [ ] **Step 2: Create the CodeBuild runner project**

Create `skills-ci` with GitHub source `https://github.com/mixiopro/skills`, no artifacts, `LINUX_CONTAINER`, `aws/codebuild/standard:7.0`, `BUILD_GENERAL1_MEDIUM`, the existing `codebuild-github-runner-service-role`, and a 60-minute build timeout.

- [ ] **Step 3: Create the workflow-job webhook**

Create a webhook for `skills-ci` with the single filter `{ "type": "EVENT", "pattern": "WORKFLOW_JOB_QUEUED" }` and the established pull-request build policy.

- [ ] **Step 4: Read back project and webhook configuration**

Run:

```bash
aws codebuild batch-get-projects --region ap-south-1 --names skills-ci
aws codebuild get-webhook --region ap-south-1 --project-name skills-ci
```

Expected: the project source, role, environment, and active workflow-job filter match the specification.

- [ ] **Step 5: Record the AWS resource evidence**

Record the project ARN, webhook status, and verification timestamp in the handoff/report; never record tokens or webhook secrets.

### Task 4: Verify the migration end to end

**Files:**
- Modify: none unless verification exposes a defect.

**Interfaces:**
- Consumes: repository checks, CodeBuild readback, and GitHub Actions run evidence.
- Produces: separate implemented, verified, merged, and deployed status.

- [ ] **Step 1: Run the repository checks locally**

Run:

```bash
bash -n install.sh scripts/check-skill-count.sh scripts/check-screenplay-integration.sh scripts/check-npx-install.sh
bash scripts/check-skill-count.sh
bash scripts/check-screenplay-integration.sh
SKILLS_CLI_VERSION=1.7.0 bash scripts/check-npx-install.sh
(cd skills/how-to-make-script && python3 scripts/check_links.py . && python3 scripts/validate_assets.py . && python3 scripts/check_routes.py . && python3 scripts/check_loading_budget.py . && python3 -m pytest -q tests)
```

Expected: every command exits zero.

- [ ] **Step 2: Push the branch and inspect the first CodeBuild-backed run**

Use the existing PR branch workflow. Confirm the Linux and Windows jobs are picked up by `skills-ci`, while the macOS job remains GitHub-hosted.

- [ ] **Step 3: Inspect GitHub check conclusions**

Run:

```bash
gh pr checks 35 --repo mixiopro/skills
```

Expected: CodeBuild-backed jobs report pass/fail in GitHub and no job remains queued for an unmatched runner label.

- [ ] **Step 4: Inspect CodeBuild build history**

Run:

```bash
aws codebuild list-builds-for-project --region ap-south-1 --project-name skills-ci
```

Expected: a completed build exists for each CodeBuild-backed workflow job.

- [ ] **Step 5: Commit only if verification requires repository fixes**

Use a focused `fix:` commit and repeat the affected local and hosted checks; do not hide infrastructure or tracking failures as test passes.
