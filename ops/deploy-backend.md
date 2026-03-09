# Deployment Runbook (Stage -> Prod)

## Prerequisites
- GitHub Environments:
  - `staging` (auto)
  - `production` (required reviewers)
- GitHub secrets:
  - `AWS_ROLE_ARN_STAGING`
  - `AWS_ROLE_ARN_PROD`
- GitHub vars:
  - `AWS_REGION`
  - `STAGING_BASE_URL`
  - `PROD_BASE_URL`
  - `ZAP_TARGET_URL_STAGING`

## First-time bootstrap
```bash
sam build
sam deploy --guided --config-file samconfig.staging.toml
sam deploy --guided --config-file samconfig.prod.toml
```

## Updating staging after code changes (order of operations)

You do **not** need to change or delete the existing CloudFormation stack before merging. The workflow that runs after merge will **update** the existing stack (e.g. `mnemospark-staging`) in place.

1. **Develop and test on a branch**  
   Open a PR from your branch (e.g. `fix/lambda-entry-point`). Run unit tests locally; CI will run them again on push to the PR.

2. **Merge the PR to `main`**  
   No manual steps on AWS or CloudFormation are required before merging.

3. **Automatic deploy to staging**  
   The **Deploy Staging** workflow runs on push to `main`. It:
   - Runs unit tests
   - Assumes the staging deploy role (OIDC)
   - Runs `sam build` then `sam deploy --config-file samconfig.staging.toml`
   - Deploys to the stack named in that config (`mnemospark-staging`), updating the existing stack with the new template and artifacts
   - Runs smoke tests if `STAGING_BASE_URL` is set and not a placeholder

4. **Verify staging**  
   Check the workflow run in GitHub Actions. Optionally hit the staging API or review CloudWatch logs for the updated Lambdas to confirm behavior.

5. **Promote to production (when ready)**  
   Trigger the **Promote to Production** workflow manually. Production deploy requires environment approval.

## Standard flow (summary)
1. Merge PR to `main`
2. `Deploy Staging` runs automatically (updates existing `mnemospark-staging` stack)
3. `Security Post Deploy` runs (Trivy, Checkov, ZAP)
4. Trigger `Promote to Production` manually
5. Production deploy requires environment approval

## Rollback
If a staging deploy fails or introduces issues: use CloudFormation stack history for **mnemospark-staging** to redeploy a previous known-good template/artifact, then re-run smoke tests. Do not delete the stack unless you are doing a full teardown; normal updates are in-place.

## Troubleshooting

### ROLLBACK_FAILED (bucket not empty)
If the stack goes to `ROLLBACK_FAILED` because **CloudTrailLogBucket** (or any S3 bucket) could not be deleted: the bucket is not empty. With versioning enabled, you must remove all object versions and delete markers before CloudFormation can delete the bucket.

1. In AWS Console: S3 → select the stack’s CloudTrail log bucket (e.g. `mnemospark-staging-cloudtraillogbucket-...`) → Empty bucket (include all versions).
2. Then either:
   - **Continue rollback:** CloudFormation → Stacks → select `mnemospark-staging` → Stack actions → Continue update rollback; or
   - **Delete stack:** Stack actions → Delete stack (after emptying, the bucket delete will succeed).

### CREATE_FAILED: UnauthorizedTaggingOperation (API Gateway)
If the deploy role fails with a permissions error on a **tagging** operation for API Gateway (e.g. when creating the stage), the role needs access to API Gateway tag resources. Add `arn:aws:apigateway:*::/tags/*` to the API Gateway `Resource` list in the deploy role’s policy. See `docs/iam-mnemospark-deploy-policy.json` (APIGateway statement).
