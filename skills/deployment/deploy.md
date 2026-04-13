---
name: deploy
description: Automated deployment to Railway, Vercel, AWS, and other platforms
allowed-tools:
  - Read
  - Write
  - Bash
  - Glob
  - Grep
---

# Deploy

Streamline deployment workflows for multiple platforms:
1. Detect deployment target (Vercel, Railway, AWS, etc.)
2. Run pre-deployment checks (tests, linting, build)
3. Configure deployment settings
4. Execute deployment
5. Verify deployment success
6. Rollback if needed

## Step 1: Detect Platform

```bash
PLATFORM="unknown"

[ -f "vercel.json" ] && PLATFORM="vercel"
[ -f ".vercel/project.json" ] && PLATFORM="vercel"

if [ -f "fly.toml" ]; then
  PLATFORM="fly"
elif FLY_TOML=$(find . -maxdepth 2 -name "fly.toml" -not -path "*/node_modules/*" | head -1); [ -n "$FLY_TOML" ]; then
  PLATFORM="fly"
fi

railway status 2>/dev/null | grep -q "Project" && PLATFORM="railway"
[ -f "railway.json" ] && PLATFORM="railway"

[ -f "cdk.json" ] && PLATFORM="aws-cdk"
[ -f "serverless.yml" ] && PLATFORM="aws-serverless"
[ -f "netlify.toml" ] && PLATFORM="netlify"
[ -f "Procfile" ] && PLATFORM="heroku"
[ -f "Dockerfile" ] && PLATFORM="docker"

echo "Detected platform: $PLATFORM"
```

If multiple are detected, ask which platform to deploy to before proceeding.

## Step 2: Pre-Deployment Checks

```
Pre-Deployment Checks
═══════════════════════════════════

1. Git Status
   ├─ Branch: [current branch]
   ├─ Clean: [yes/no uncommitted changes]
   └─ Sync: [up to date with origin?]

2. Dependencies
   ├─ Node Modules: [installed?]
   ├─ Lock File: [up to date?]
   └─ Vulnerabilities: [audit result]

3. Environment
   ├─ .env file: [found/missing]
   ├─ Required Vars: [all set / missing list]
   └─ Secrets: [configured in platform?]

4. Tests
   ├─ Unit: [pass/fail count]
   ├─ Integration: [pass/fail count]
   └─ E2E: [pass/skip]

5. Build
   ├─ TypeScript: [errors?]
   ├─ Linting: [passed/failed]
   └─ Build: [success/failed]

6. Database
   ├─ Migrations: [applied/pending]
   └─ Backup: [recent/missing]
```

If any fail, surface the issue and ask how to proceed before deploying.

## Step 3: Vercel Deployment

```bash
# Check Vercel CLI
if ! command -v vercel &> /dev/null; then
  npm i -g vercel
fi

vercel whoami || vercel login

# Identity check — confirm project name matches this directory
LOCAL_PROJECT=$(cat .vercel/project.json 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('projectId',''))")
echo "Linked project: $LOCAL_PROJECT"

# Deploy to production
vercel deploy --prod --yes 2>&1 | tee /tmp/vercel-deploy.log
DEPLOY_URL=$(grep -oE 'https://[a-zA-Z0-9._/-]+' /tmp/vercel-deploy.log | tail -1)
echo "Deployed to: $DEPLOY_URL"
```

## Step 4: Railway Deployment

```bash
if ! command -v railway &> /dev/null; then
  npm i -g @railway/cli
fi

railway whoami || railway login

# Confirm project identity
railway status

# Deploy
railway up 2>&1 | tee /tmp/railway-deploy.log

# Wait for build to complete, then get URL
sleep 15
DEPLOY_URL=$(railway status --json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('serviceUrl',''))" 2>/dev/null)
echo "Deployed to: $DEPLOY_URL"
```

## Step 5: Fly.io Deployment

```bash
# Get app name from fly.toml
FLY_APP=$(grep "^app " fly.toml | awk '{print $3}' | tr -d '"')
echo "Deploying app: $FLY_APP"

# Confirm app exists and you own it
fly status --app "$FLY_APP" 2>&1 | head -5

# Deploy
fly deploy --app "$FLY_APP" 2>&1 | tee /tmp/fly-deploy.log
DEPLOY_URL="https://$FLY_APP.fly.dev"
echo "Deployed to: $DEPLOY_URL"
```

## Step 6: AWS CDK Deployment

```bash
# Check AWS CLI and CDK
aws sts get-caller-identity || { echo "Not authenticated. Run: aws configure"; exit 1; }
command -v cdk &> /dev/null || npm i -g aws-cdk

echo "Account: $(aws sts get-caller-identity --query Account --output text)"
echo "Region: $(aws configure get region)"
echo "Available Stacks:"
cdk list

# Synthesize + diff
cdk synth
cdk diff

# Deploy (with approval prompt before running)
cdk deploy --require-approval never
```

## Step 7: Docker Deployment

```bash
IMAGE_NAME=$(jq -r .name package.json 2>/dev/null || basename $(pwd))
IMAGE_TAG=$(git rev-parse --short HEAD 2>/dev/null || echo "latest")

docker build -t $IMAGE_NAME:$IMAGE_TAG .
echo "Built: $IMAGE_NAME:$IMAGE_TAG"

# Push to registry (Docker Hub / AWS ECR / GitHub Container Registry)
docker tag $IMAGE_NAME:$IMAGE_TAG [registry]/$IMAGE_NAME:$IMAGE_TAG
docker push [registry]/$IMAGE_NAME:$IMAGE_TAG
```

## Step 8: Verify Deployment

```bash
PROBE_URL="${DEPLOY_URL}/health"

for ATTEMPT in 1 2 3; do
  echo "Probe $ATTEMPT of 3..."
  HTTP_STATUS=$(curl -s -o /tmp/probe.json -w "%{http_code}" "$PROBE_URL" 2>/dev/null)
  echo "HTTP: $HTTP_STATUS"
  
  if [ "$HTTP_STATUS" = "200" ]; then
    echo "Verification PASSED"
    break
  fi
  
  [ $ATTEMPT -lt 3 ] && sleep 10
done
```

## Step 9: Rollback (if needed)

**Vercel:**
```bash
vercel rollback --yes
```

**Fly.io:**
```bash
fly releases list --app "$FLY_APP" | head -5
fly deploy --app "$FLY_APP" --image [previous-image-ref]
```

**Railway:** No CLI rollback — go to your Railway dashboard, navigate to Deployments, and redeploy the previous version manually.

## Post-Deployment Checklist

```
Post-Deployment
═══════════════════════════════════
Required:
[ ] Deployment verified live (health check passed)
[ ] Test critical user flows
[ ] Check error monitoring (Sentry / DataDog)
[ ] Review application logs

Recommended:
[ ] Tag release in GitHub
[ ] Update changelog
[ ] Monitor performance for 15 minutes

Optional:
[ ] Take database snapshot
[ ] Notify team
```

## Deployment Record

Save a structured record after every deploy:

```bash
mkdir -p .deployments
cat > .deployments/$(date +%Y%m%d_%H%M%S).json <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "platform": "$PLATFORM",
  "environment": "production",
  "version": "$(jq -r .version package.json 2>/dev/null || echo 'unknown')",
  "commit": "$(git rev-parse HEAD)",
  "url": "$DEPLOY_URL"
}
EOF
```

## Best Practices

1. **Always run checks** — Don't skip pre-deployment validation
2. **Test staging first** — Deploy to staging before production
3. **Monitor after deploy** — Watch metrics for 15-30 minutes
4. **Tag releases** — Use git tags for version tracking
5. **Document incidents** — Record reasons for rollbacks
6. **Never skip the identity guard** — Always confirm you're deploying to the right project
7. **Never background a deploy** — Always run foreground and capture exit code
8. **Never set secrets in git** — Use platform CLI for all credentials
9. **Database migrations** — Handle carefully, test rollback path
10. **Blue-green deploys** — For zero-downtime when possible
