# End-to-end Configuration Example

This example demonstrates how to manage configurations across different environments (development and production) using Cloudentity Configuration as Code (CAC).

## Directory Structure

```
e2e/
├── dev/
│   └── .env      # Development environment variables
├── prod/
│   └── .env      # Production environment variables 
├── config.yaml   # Main configuration file with profiles
├── data/         # Production configuration files
│   └── workspaces/
│       └── customer-apps/
└── data-dev/     # Development configuration files
    └── workspaces/
        └── customer-apps/
```

## Usage

You select an environment by sourcing its `.env` file (`dev/.env` or `prod/.env`);
those variables override `config.yaml`. There is no `--profile` flag.

### Pull Configurations

To pull configuration from the development environment:

```bash
export $(xargs < dev/.env) && cac pull --config config.yaml --workspace customer-apps
```

To pull configuration from the production environment:

```bash
export $(xargs < prod/.env) && cac pull --config config.yaml --workspace customer-apps
```

### Compare Against the Live Environment

To see what merging your local config would change on an environment (this is
what the PR diff job runs):

```bash
export $(xargs < dev/.env) && cac diff --config config.yaml --workspace customer-apps --source merged --target remote
```

Swap `dev/.env` for `prod/.env` to compare against production.

### Promote Changes

To promote changes to production:

1. Review the differences:
```bash
export $(xargs < prod/.env) && cac diff --config config.yaml --workspace customer-apps --source merged --target remote
```

2. Push the changes to production:
```bash
export $(xargs < prod/.env) && cac push --config config.yaml --workspace customer-apps --method patch
```

## Configuration File Structure

`config.yaml` holds a single default profile with empty placeholder values. Each
environment's `dev/.env` / `prod/.env` supplies the actual values as environment
variables that override the config (`CLIENT_ISSUER_URL`, `CLIENT_CLIENT_ID`,
`CLIENT_TENANT_ID`, `STORAGE_DIR_PATH`, `LOGGING_LEVEL`), plus the
`CLIENT_CLIENT_SECRET` (provided in CI by the `CAC_CLIENT_SECRET` secret).

Check the main [README.md](../../README.md) for more details about configuration options and available

## CI/CD

Two GitHub Actions workflows automate environment management:

- **PR Config Diff** (`.github/workflows/pr-diff.yml`) — on every pull request,
  posts (and keeps updated) one sticky comment per affected environment and
  workspace showing the live `cac diff --source merged --target remote`,
  i.e. exactly what merging would apply. A workspace that does not yet exist on
  the target environment is flagged as **new — will be imported**.
- **Deploy Config** (`.github/workflows/deploy.yml`) — on merge to `main`,
  pushes each environment touched by the change. The push method is resolved
  per workspace: existing workspaces are updated with `--method patch`, while a
  workspace that does not yet exist on the environment is created with
  `--method import`.

### Directory → environment mapping

| Changed path | Affects |
|---|---|
| `dev/workspaces/<ws>/**` | dev |
| `prod/workspaces/<ws>/**` | prod |
| `base/workspaces/<ws>/**` | dev **and** prod |
| `config.yaml`, `vars.yaml` | all environments and workspaces |

### One-time setup

1. Create GitHub Environments `dev` and `prod`
   (Settings → Environments).
2. In each environment, add a secret `CAC_CLIENT_SECRET` containing the
   system workspace client secret for that tenant (client IDs and issuer URLs
   are read from `config.yaml`).
3. Optional: add required reviewers to the `prod` environment to gate
   production deploys. Note: the PR diff job uses the same environment, so
   PR diffs against prod will then also wait for approval.