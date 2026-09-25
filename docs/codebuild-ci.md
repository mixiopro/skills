# AWS CodeBuild CI

This repository uses AWS CodeBuild-hosted GitHub Actions runners for its Linux and Windows CI jobs. GitHub Actions remains the workflow and pull-request status layer; the job execution capacity is supplied by CodeBuild. This matches the existing Mixio `studio-ci` and `inference-ci` projects.

## Runner contract

| Workflow job | Runner labels | Execution platform |
|---|---|---|
| Linux skill and screenplay validation | `codebuild-skills-ci-${{ github.run_id }}-${{ github.run_attempt }}`, `skills-linux-validation` | CodeBuild Ubuntu 22.04 standard 7.0 |
| Windows installer and npx discovery | `codebuild-skills-ci-${{ github.run_id }}-${{ github.run_attempt }}`, `image:windows-3.0`, `instance-size:medium`, `skills-windows-installation` | CodeBuild Windows Server Core 2019 |
| Public installer Unix/Linux | `codebuild-skills-ci-${{ github.run_id }}-${{ github.run_attempt }}`, `public-installer-linux` | CodeBuild Ubuntu 22.04 standard 7.0 |
| Public installer Unix/macOS | `macos-latest` | GitHub-hosted macOS |
| Public installer Windows | `codebuild-skills-ci-${{ github.run_id }}-${{ github.run_attempt }}`, `image:windows-3.0`, `instance-size:medium`, `public-installer-windows` | CodeBuild Windows Server Core 2019 |
| Mixio maintainer tracking | `codebuild-skills-ci-${{ github.run_id }}-${{ github.run_attempt }}`, `maintainer-tracking` | CodeBuild Ubuntu 22.04 standard 7.0 |

The base label must contain the exact CodeBuild project name and the current GitHub run ID/attempt. The additional labels keep multiple jobs in one workflow run from being matched to the wrong ephemeral runner.

The macOS check is intentionally retained on `macos-latest`. CodeBuild-hosted GitHub Actions runners currently support Linux and Windows platforms, not GitHub Actions macOS runners. Moving that check requires a separate CodeBuild macOS reserved-capacity decision.

## AWS project setup

The expected AWS region is `ap-south-1`, the source is `https://github.com/mixiopro/skills`, and the project name is `skills-ci`. The AWS account must already have a GitHub source connection and a service role that can be used by CodeBuild-hosted GitHub runners. The existing Mixio role can be read from `studio-ci`:

```bash
export AWS_REGION=ap-south-1
export CODEBUILD_PROJECT=skills-ci
export CODEBUILD_SERVICE_ROLE_ARN="$(aws codebuild batch-get-projects \
  --region "$AWS_REGION" \
  --names studio-ci \
  --query 'projects[0].serviceRole' \
  --output text)"
```

Create the runner project with no build artifacts. Its buildspec is intentionally empty because CodeBuild replaces the build commands with the ephemeral GitHub Actions runner bootstrap:

```bash
aws codebuild create-project \
  --region "$AWS_REGION" \
  --name "$CODEBUILD_PROJECT" \
  --source '{"type":"GITHUB","location":"https://github.com/mixiopro/skills","buildspec":""}' \
  --artifacts '{"type":"NO_ARTIFACTS"}' \
  --environment '{"type":"LINUX_CONTAINER","image":"aws/codebuild/standard:7.0","computeType":"BUILD_GENERAL1_MEDIUM","privilegedMode":true,"imagePullCredentialsType":"CODEBUILD"}' \
  --service-role "$CODEBUILD_SERVICE_ROLE_ARN" \
  --timeout-in-minutes 60 \
  --queued-timeout-in-minutes 480 \
  --no-badge-enabled
```

Enable the workflow-job webhook and the same pull-request approval policy used by the existing Mixio runner projects:

```bash
aws codebuild create-webhook \
  --region "$AWS_REGION" \
  --project-name "$CODEBUILD_PROJECT" \
  --filter-groups '[[{"type":"EVENT","pattern":"WORKFLOW_JOB_QUEUED"}]]' \
  --pull-request-build-policy '{"requiresCommentApproval":"ALL_PULL_REQUESTS","approverRoles":["GITHUB_WRITE","GITHUB_MAINTAIN","GITHUB_ADMIN"]}'
```

If the project already exists, use `aws codebuild update-project` with the same source, environment, role, and timeout values instead of creating a second project. Do not put GitHub tokens, webhook secrets, or AWS credentials in this repository.

## Verification

Read the resource configuration back from AWS:

```bash
aws codebuild batch-get-projects \
  --region "$AWS_REGION" \
  --names "$CODEBUILD_PROJECT" \
  --query 'projects[0].{arn:arn,source:source,environment:environment,serviceRole:serviceRole,timeoutInMinutes:timeoutInMinutes}' \
  --output json

aws codebuild batch-get-projects \
  --region "$AWS_REGION" \
  --names "$CODEBUILD_PROJECT" \
  --query 'projects[0].webhook' \
  --output json
```

Then inspect the GitHub workflow and check run:

```bash
gh pr checks 35 --repo mixiopro/skills
gh run view RUN_ID --repo mixiopro/skills
aws codebuild list-builds-for-project \
  --region "$AWS_REGION" \
  --project-name "$CODEBUILD_PROJECT"
```

A queued job usually means the project name in `runs-on` does not match the CodeBuild project, the repository webhook is missing/inactive, or the GitHub connection has not been authorized for `mixiopro/skills`. A CodeBuild run is ephemeral; the durable workflow log remains in GitHub Actions.

## Rollback

To return execution to GitHub-hosted runners, restore the previous `runs-on` values in the workflows: `ubuntu-latest` for Linux, `windows-latest` for Windows, and the original macOS matrix. Keep the AWS project until the replacement checks have been verified; deleting it is not part of routine rollback.
