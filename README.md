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

### Pull Configurations

To pull configuration from development environment:

```bash
export $(xargs < dev/.env) && cac pull --config config.yaml --workspace customer-apps --profile dev
```

To pull configuration from production environment:

```bash
export $(xargs < prod/.env) && cac pull --config config.yaml --workspace customer-apps
```

### Compare Environments

To compare development and production configurations:

```bash
export $(xargs < prod/.env) && cac diff --config config.yaml --source dev --target prod --workspace customer-apps
```

### Promote Changes

To promote changes from development to production:

1. Review the differences:
```bash
export $(xargs < prod/.env) && cac diff --config config.yaml --source dev --target prod --workspace customer-apps
```

2. Push the changes to production:
```bash
export $(xargs < prod/.env) && cac push --config config.yaml --workspace customer-apps --method patch
```

## Configuration File Structure

The `config.yaml` file contains profiles for both development and production environments. The default profile is used for production, while the `dev` profile is used for development environment.

Check the main [README.md](../../README.md) for more details about configuration options and available

## CI/CD

Two GitHub Actions workflows automate environment management:

- **PR Config Diff** (`.github/workflows/pr-diff.yml`) — on every pull request,
  posts (and keeps updated) one sticky comment per affected environment and
  workspace showing the live `cac diff --source merged --target remote`,
  i.e. exactly what merging would apply.
- **Deploy Config** (`.github/workflows/deploy.yml`) — on merge to `main`,
  runs `cac push --method patch` against each environment touched by the change.

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