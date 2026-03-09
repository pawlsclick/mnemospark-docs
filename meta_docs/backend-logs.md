# Where to check backend logs (requests and responses)

The mnemospark backend is deployed with AWS SAM (API Gateway + Lambda). All request/response and function logs go to **AWS CloudWatch Logs** in the same account and region as the stack.

## 1. API Gateway access logs (HTTP requests and responses)

**Log group (pattern):**

```
/aws/apigateway/<StackName>-<StageName>-access
```

Example: if the stack is `mnemospark-staging` and stage is `prod`, the log group is:

```
/aws/apigateway/mnemospark-staging-prod-access
```

**What you see:** One JSON line per request. The access log format (from [mnemospark-backend/template.yaml](https://github.com/pawlsclick/mnemospark-backend/blob/main/template.yaml)) includes:

- `requestId` — API Gateway request ID
- `ip` — client IP
- `requestTime` — request time
- `httpMethod` — GET, POST, DELETE, etc.
- `routeKey` — resource path (e.g. `/price-storage`, `/storage/upload`)
- `status` — HTTP status (200, 403, 500, etc.)
- `protocol` — HTTP/1.1, etc.
- `responseLength` — response size
- `integrationError` — backend integration error message (if any)

So you can see **which route was hit, status, and high-level errors** here. Request/response bodies are **not** logged in access logs.

**How to open:** AWS Console → CloudWatch → Log groups → find the log group above → open a log stream and filter by time or `requestId`.

The stack output **ApiGatewayAccessLogGroupName** is the logical ID of this log group; in the console you need the **log group name** (the pattern above).

---

## 2. Lambda function logs (per-route logic and errors)

Each Lambda behind the API has its own log group:

**Log group pattern:**

```
/aws/lambda/<FunctionName>
```

`<FunctionName>` is the **physical** Lambda name created by the stack (e.g. `mnemospark-staging-PriceStorageFunction-xyz`). In CloudWatch → Log groups, filter by `/aws/lambda/` and your stack name to find them.

**Relevant functions for storage and pricing:**

| Route / behavior            | Lambda (logical ID in template) |
|----------------------------|----------------------------------|
| Wallet/auth validation     | WalletAuthorizerFunction         |
| POST /price-storage        | PriceStorageFunction             |
| POST /storage/upload       | StorageUploadFunction            |
| POST /storage/ls           | StorageLsFunction                |
| POST /storage/download     | StorageDownloadFunction          |
| POST /storage/delete       | StorageDeleteFunction            |

**What you see:** Whatever the Lambda code writes to stdout/stderr (e.g. `print()`, `logging`, tracebacks). So you can see **request parsing, wallet proof checks, backend errors, and stack traces** in the log stream for that function.

**How to open:** AWS Console → CloudWatch → Log groups → `/aws/lambda/` → pick the function that backs the route you care about → open the latest log stream (or search Logs Insights across the group).

---

## 3. Quick reference

| Goal                                      | Where to look |
|-------------------------------------------|----------------|
| “Did the request reach the API? What path and status?” | API Gateway access log group: `/aws/apigateway/<StackName>-<StageName>-access` |
| “Why did /price-storage or /storage/… fail?”           | Lambda log group for that route (e.g. PriceStorageFunction, StorageUploadFunction) |
| “Wallet / auth errors”                    | WalletAuthorizerFunction log group and the Lambda for the route that returned 403 |

**Region:** Use the same region as the stack (e.g. `us-east-1`). Stack outputs in the AWS Console (CloudFormation → stack → Outputs) list the API URL and, where defined, the **ApiGatewayAccessLogGroupName**; the actual log group **name** is the pattern above.

**CLI example (list recent access log streams):**

```bash
aws logs describe-log-streams \
  --log-group-name "/aws/apigateway/mnemospark-staging-prod-access" \
  --order-by LastEventTime \
  --descending \
  --max-items 5
```

Then read a stream with `aws logs get-log-events --log-group-name ... --log-stream-name ...`.
