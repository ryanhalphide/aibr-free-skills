---
name: discovery
description: Enter read-only platform mapping mode. Captures UI, APIs, integrations, and competitive intelligence without modifying any target system. Use when starting any platform analysis, reverse engineering, or integration research.
allowed_tools:
  - Read
  - Bash
  - Glob
  - Grep
  - WebFetch
  - WebSearch
---

# Discovery Mode

Enter read-only platform mapping mode. No writes, no form submissions, no account creation. Everything observed is logged.

## Rules for This Session

- **Read-only absolute**: no writes to target systems, no form submissions, no account creation, no purchases
- **Log everything**: every URL accessed, every API endpoint observed, every assumption made
- **Cite everything**: no undocumented claims — every data point needs a source
- **Stop and flag**: if anything requires auth to proceed, note it as "auth-gated" and move on

## Workflow

### 1. Setup

Confirm target platform and create output directory:
```bash
mkdir -p ~/knowledge-base/discovery/{platform-name}
mkdir -p ~/knowledge-base/discovery/{platform-name}/screenshots
```

Create a session log file:
```
~/knowledge-base/discovery/{platform-name}/session-{YYYY-MM-DD}.md
```

### 2. Surface Mapping

Navigate the platform and capture:
- Homepage and value proposition
- Pricing and plan structure
- Feature list and capability inventory
- Integrations/marketplace page
- API documentation (if publicly accessible)
- Developer portal or SDK page

For each page: note URL, extract key text and structure.

### 3. API Discovery

Observe network requests to identify:
- API base URL and versioning
- Auth header patterns (Bearer, API-Key, Cookie)
- Endpoint naming conventions
- Response envelope structure
- Rate limit and infrastructure headers

### 4. Integration Inventory

Identify:
- OAuth providers and SSO options
- Webhook capabilities (inbound/outbound)
- Native integrations listed
- Embedded third-party services (from script sources)
- iPaaS connectors (Zapier, Make, n8n)

### 5. Wrap Up

At end of discovery session, update the session log with:
- Pages visited (with URLs and dates)
- Key findings per category
- Auth-gated areas (couldn't access)
- Open questions requiring follow-up
- Recommended next phase actions

## Session Log Format

```markdown
# Discovery: {Platform Name}
Date: {YYYY-MM-DD}

## Key Findings

### API
- Base URL: {url}
- Auth: {method}
- Endpoints observed: {list}

### Integrations
- {integration}: {notes}

### Pricing
- Plans: {list}
- API access: {tier}

## Auth-Gated Areas
- {area}: requires {auth type}

## Open Questions
- {question}

## Recommended Next Steps
- {action}
```
