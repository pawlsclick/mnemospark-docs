# Dashboard GraphQL API key (Secrets Manager + EC2)

This runbook covers the shared secret used for **mnemospark-backend** dashboard GraphQL (`POST /graphql`): API Gateway invokes a **Lambda request authorizer** that compares the **`x-api-key`** header to the current value in **AWS Secrets Manager** (`DashboardGraphqlApiKeySecretArn` in `template.yaml`).

The **dashboard v2** host (EC2 + Tailscale Serve + systemd) should not put that key in any `NEXT_PUBLIC_*` variable. Instead, set **`DASHBOARD_GRAPHQL_API_KEY`** only in server-side env (for example `.env.local` next to the Next.js app) so the **`/api/graphql`** proxy can attach the header when calling the public HTTPS URL.

## Names and locations

| Item | Detail |
| --- | --- |
| Secret | Create in the same account/region as the stack (for example staging in `us-east-1`). Plaintext string, or JSON with `api_key` / `apiKey`. |
| Stack parameter | `DashboardGraphqlApiKeySecretArn` — pass on `sam deploy` or via GitHub Actions (variable `DASHBOARD_GRAPHQL_API_KEY_SECRET_ARN`). |
| EC2 / Next.js | `DASHBOARD_GRAPHQL_URL` = stack output `DashboardGraphQLHttpApiUrl` (full URL including stage path). `DASHBOARD_GRAPHQL_API_KEY` = same plaintext as the secret’s current value. |
| Browser | `NEXT_PUBLIC_GRAPHQL_ENDPOINT=/api/graphql` (same-origin to the proxy). `NEXT_PUBLIC_USE_MOCK_GRAPHQL=false`. |

## Rotation

1. Generate a new random API key (long, unguessable).
2. **Secrets Manager:** Update the secret value (new version). Confirm the authorizer Lambda can read it (IAM already allows `GetSecretValue` on that ARN).
3. **EC2:** Update `DASHBOARD_GRAPHQL_API_KEY` in `.env.local` (or your env file) to match the new value.
4. Restart the dashboard service, for example: `sudo systemctl restart mnemospark-ops-v2.service`.
5. Smoke-test: GraphQL query with `x-api-key` (see below). Wrong key should return **401** from API Gateway.

## Verification (`curl`)

Replace `ENDPOINT` with the `DashboardGraphQLHttpApiUrl` value and `KEY` with the current key.

```bash
curl -sS -X POST "$ENDPOINT" \
  -H "Content-Type: application/json" \
  -H "x-api-key: $KEY" \
  -d '{"query":"{ health { ok } }"}'
```

Expect HTTP **200** and JSON with `data.health.ok` true. Omitting `x-api-key` or sending a wrong value should yield **401**.

## GitHub Actions

Staging and production deploy workflows pass `DashboardGraphqlApiKeySecretArn` using the environment variable **`DASHBOARD_GRAPHQL_API_KEY_SECRET_ARN`**. Set that variable per environment to the correct secret ARN before deploying.

## Cross-region note

The staging API may live in **us-east-1** while the dashboard EC2 runs in another region (for example **eu-north-1**). Traffic uses **public HTTPS** to the API Gateway URL; no VPC peering is required for this path.
