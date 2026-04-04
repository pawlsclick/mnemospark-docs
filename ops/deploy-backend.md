# Deployment Runbook (Stage -> Prod)

Before treating **prod** as ready for cutover, complete the **staging-first parameterization** in `mnemospark-backend` (template parameters + GitHub variables for addresses, RPC URL, settlement mode, relayer secret id—no workflow literals). See **`ops/deploy-backend-prod.md`** (prerequisite + instructions + agent prompt).

## Prerequisites
- GitHub Environments:
  - `staging` (auto)
  - `prod` (required reviewers; used by **Promote to Production**)
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
   - Deploys to the stack named in that config (`mnemospark-staging`), updating the existing stack with the new template and artifacts (including **regional AWS WAFv2** on the public **REST** API stage when present in `template.yaml`)
   - Runs smoke tests if `STAGING_BASE_URL` is set and not a placeholder

4. **Verify staging**  
   Check the workflow run in GitHub Actions. Optionally hit the staging API or review CloudWatch logs for the updated Lambdas to confirm behavior.

5. **Promote to prod (when you are ready)**  
   **Prod does not deploy when staging deploys.** Trigger **Promote to Production** manually with the commit SHA you validated in staging. Approve the GitHub **`prod`** environment if required reviewers are configured.

## Standard flow (summary)
1. Merge PR to `main`
2. `Deploy Staging` runs automatically (updates **`mnemospark-staging` only**)
3. `Security Post Deploy` runs (Trivy, Checkov, ZAP)—does **not** update prod
4. When satisfied with staging, trigger `Promote to Production` manually (prod **never** auto-updates from staging)
5. Prod deploy uses GitHub environment **`prod`**; approval if configured

**WAF:** The root SAM **`template.yaml`** can define **regional WAFv2** (`MnemosparkBackendApiWebAcl` + association to the **REST** API stage). **Prod** gets its **own** Web ACL when **`mnemospark-prod`** is deployed from the same template—verify output **`MnemosparkBackendApiWebAclArn`** and deploy-role **WAFv2** permissions. Details: **`ops/deploy-backend-prod.md`** → *AWS WAF (regional, REST API)*.

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

### Deploy fails on WAFv2 (staging or prod)
If CloudFormation fails creating **`AWS::WAFv2::WebACL`** or **`AWS::WAFv2::WebACLAssociation`**, the OIDC deploy role likely lacks **WAFv2** (and related API Gateway Web ACL) actions. Align the **staging** and **prod** deploy policies with **`docs/iam-mnemospark-deploy-policy.json`** in **mnemospark-backend** (`Sid`: **WAFv2**). After prod deploy, confirm the **regional** Web ACL is associated to the correct **REST** API stage; see **`ops/deploy-backend-prod.md`** (*AWS WAF*).

### Legitimate traffic blocked (403 / empty responses)
Managed rules on the REST API WAF can block unusual clients. Use **AWS WAF** → sampled requests and **CloudWatch** metrics for the stack’s Web ACL, then tune rules (e.g. scope-down or rule overrides) in **`template.yaml`** or the console and redeploy.
