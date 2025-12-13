# GitHub DevOps Pipeline Skill

**Category:** DevOps
**Dependencies:** GitHub Actions, Docker, git
**Token Budget:** ~3500 tokens

## Purpose

Create and manage comprehensive CI/CD pipelines using GitHub Actions for the Harbor Homelab environment. Automate build, test, security scanning, deployment, and monitoring workflows with integration into Proxmox, Docker, and cloud services.

## When to Use

- Setting up CI/CD pipelines for repositories
- Automating build and test workflows
- Deploying applications to Harbor infrastructure
- Running security scans and compliance checks
- Automating release management
- Monitoring deployment health

## Capabilities

### CI/CD Pipeline Creation
- Multi-stage build pipelines
- Parallel test execution
- Matrix builds for multiple environments
- Dependency caching
- Artifact management
- Release automation

### Testing & Quality
- Unit and integration tests
- E2E testing with Playwright
- Code coverage reporting
- Lint and type checking
- Security vulnerability scanning
- Performance benchmarking

### Deployment Automation
- Deploy to Docker VM
- Deploy to Proxmox LXC containers
- Deploy to cloud platforms
- Blue-green deployments
- Canary releases
- Rollback automation

### Security & Compliance
- SAST (Static Application Security Testing)
- Dependency vulnerability scanning
- Secret scanning
- License compliance checking
- Container image scanning
- Security policy enforcement

## Usage Examples

### Basic CI Pipeline

```yaml
# .github/workflows/ci.yml
name: CI Pipeline

on:
  push:
    branches: [main, develop]
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Lint
        run: pnpm lint

      - name: Type check
        run: pnpm type-check

  test:
    runs-on: ubuntu-latest
    needs: lint
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run tests
        run: pnpm test:coverage

      - name: Upload coverage
        uses: codecov/codecov-action@v4
        with:
          token: ${{ secrets.CODECOV_TOKEN }}

  build:
    runs-on: ubuntu-latest
    needs: test
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Build
        run: pnpm build

      - name: Upload build artifacts
        uses: actions/upload-artifact@v4
        with:
          name: dist
          path: dist/
```

### Docker Build & Push Pipeline

```yaml
# .github/workflows/docker.yml
name: Build & Push Docker Image

on:
  push:
    branches: [main]
    tags: ['v*']

env:
  REGISTRY: ghcr.io
  IMAGE_NAME: ${{ github.repository }}

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to Container Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ${{ env.REGISTRY }}/${{ env.IMAGE_NAME }}
          tags: |
            type=ref,event=branch
            type=ref,event=pr
            type=semver,pattern={{version}}
            type=semver,pattern={{major}}.{{minor}}
            type=sha

      - name: Build and push
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

### Deploy to Harbor Infrastructure

```yaml
# .github/workflows/deploy.yml
name: Deploy to Harbor

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: production

    steps:
      - uses: actions/checkout@v4

      - name: Setup SSH
        uses: webfactory/ssh-agent@v0.9.0
        with:
          ssh-private-key: ${{ secrets.HARBOR_SSH_KEY }}

      - name: Add Harbor to known hosts
        run: |
          mkdir -p ~/.ssh
          ssh-keyscan -H harbor.fyi >> ~/.ssh/known_hosts

      - name: Deploy to Docker VM
        run: |
          ssh root@harbor.fyi "
            cd /opt/apps/${{ github.event.repository.name }} &&
            git pull origin main &&
            docker-compose pull &&
            docker-compose up -d --remove-orphans
          "

      - name: Health check
        run: |
          sleep 15
          curl -f https://${{ github.event.repository.name }}.harbor.fyi/health || exit 1

      - name: Notify deployment
        if: always()
        uses: slackapi/slack-github-action@v1
        with:
          webhook-url: ${{ secrets.SLACK_WEBHOOK }}
          payload: |
            {
              "text": "Deployment ${{ job.status }}: ${{ github.repository }}@${{ github.sha }}",
              "blocks": [
                {
                  "type": "section",
                  "text": {
                    "type": "mrkdwn",
                    "text": "*Deployment Status:* ${{ job.status }}\n*Repository:* ${{ github.repository }}\n*Commit:* ${{ github.sha }}\n*Author:* ${{ github.actor }}"
                  }
                }
              ]
            }
```

### Security Scanning Pipeline

```yaml
# .github/workflows/security.yml
name: Security Scan

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  secret-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: TruffleHog Secret Scan
        uses: trufflesecurity/trufflehog@v3
        with:
          path: ./
          base: ${{ github.event.repository.default_branch }}
          head: HEAD

  dependency-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Audit dependencies
        run: pnpm audit --audit-level=moderate

      - name: Check for vulnerable dependencies
        uses: snyk/actions/node@master
        env:
          SNYK_TOKEN: ${{ secrets.SNYK_TOKEN }}

  code-scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: CodeQL Analysis
        uses: github/codeql-action/init@v3
        with:
          languages: javascript, typescript

      - name: Autobuild
        uses: github/codeql-action/autobuild@v3

      - name: Perform CodeQL Analysis
        uses: github/codeql-action/analyze@v3

  container-scan:
    runs-on: ubuntu-latest
    if: github.event_name == 'push'
    steps:
      - uses: actions/checkout@v4

      - name: Build image
        run: docker build -t test-image .

      - name: Scan with Trivy
        uses: aquasecurity/trivy-action@master
        with:
          image-ref: test-image
          format: 'sarif'
          output: 'trivy-results.sarif'

      - name: Upload Trivy results
        uses: github/codeql-action/upload-sarif@v3
        with:
          sarif_file: 'trivy-results.sarif'
```

### Release Automation

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags: ['v*']

jobs:
  release:
    runs-on: ubuntu-latest
    permissions:
      contents: write

    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Generate changelog
        id: changelog
        run: |
          PREVIOUS_TAG=$(git describe --tags --abbrev=0 HEAD^ 2>/dev/null || echo "")
          if [ -z "$PREVIOUS_TAG" ]; then
            CHANGELOG=$(git log --pretty=format:"- %s (%h)" HEAD)
          else
            CHANGELOG=$(git log --pretty=format:"- %s (%h)" ${PREVIOUS_TAG}..HEAD)
          fi
          echo "changelog<<EOF" >> $GITHUB_OUTPUT
          echo "$CHANGELOG" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT

      - name: Build artifacts
        run: |
          pnpm install --frozen-lockfile
          pnpm build
          tar -czf dist-${{ github.ref_name }}.tar.gz dist/

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          body: |
            ## Changes
            ${{ steps.changelog.outputs.changelog }}

            ## Installation
            ```bash
            wget https://github.com/${{ github.repository }}/releases/download/${{ github.ref_name }}/dist-${{ github.ref_name }}.tar.gz
            tar -xzf dist-${{ github.ref_name }}.tar.gz
            ```
          files: dist-${{ github.ref_name }}.tar.gz
          draft: false
          prerelease: false
```

### Matrix Testing

```yaml
# .github/workflows/matrix.yml
name: Matrix Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ${{ matrix.os }}
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, macos-latest]
        node: [18, 20, 21]
        exclude:
          - os: macos-latest
            node: 18

    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js ${{ matrix.node }}
        uses: actions/setup-node@v4
        with:
          node-version: ${{ matrix.node }}
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run tests
        run: pnpm test
```

### Performance Benchmarking

```yaml
# .github/workflows/benchmark.yml
name: Performance Benchmark

on:
  pull_request:
    branches: [main]

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'pnpm'

      - name: Install dependencies
        run: pnpm install --frozen-lockfile

      - name: Run benchmarks
        run: pnpm benchmark --json > benchmark-results.json

      - name: Compare with baseline
        uses: benchmark-action/github-action-benchmark@v1
        with:
          tool: 'customBiggerIsBetter'
          output-file-path: benchmark-results.json
          github-token: ${{ secrets.GITHUB_TOKEN }}
          auto-push: true
          alert-threshold: '150%'
          comment-on-alert: true
```

## Configuration

### Reusable Workflows

```yaml
# .github/workflows/_deploy.yml (reusable)
name: Deploy

on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
      image:
        required: true
        type: string
    secrets:
      ssh-key:
        required: true

jobs:
  deploy:
    runs-on: ubuntu-latest
    environment: ${{ inputs.environment }}
    steps:
      - name: Deploy
        run: |
          # Deployment logic here
```

```yaml
# Use reusable workflow
name: Deploy to Production
on:
  push:
    branches: [main]

jobs:
  deploy:
    uses: ./.github/workflows/_deploy.yml
    with:
      environment: production
      image: ghcr.io/owner/repo:latest
    secrets:
      ssh-key: ${{ secrets.HARBOR_SSH_KEY }}
```

### Composite Actions

```yaml
# .github/actions/setup-project/action.yml
name: Setup Project
description: Setup Node.js and install dependencies

runs:
  using: composite
  steps:
    - name: Setup Node.js
      uses: actions/setup-node@v4
      with:
        node-version: '20'
        cache: 'pnpm'

    - name: Install dependencies
      shell: bash
      run: pnpm install --frozen-lockfile
```

## Integration Points

- **Harbor Docker VM**: Primary deployment target
- **GitHub Container Registry**: Docker image storage
- **Codecov**: Code coverage reporting
- **Snyk/Trivy**: Security scanning
- **Slack**: Deployment notifications
- **Cortex**: Log pipeline execution
- **NocoDB**: Track deployment metrics

## Environment Secrets

```bash
# Required secrets in GitHub repository settings
HARBOR_SSH_KEY          # SSH key for Harbor infrastructure
CODECOV_TOKEN           # Codecov API token
SNYK_TOKEN              # Snyk API token
SLACK_WEBHOOK           # Slack webhook URL
CLOUDFLARE_API_TOKEN    # Cloudflare API token (for DNS updates)
DOCKER_USERNAME         # Docker registry username
DOCKER_PASSWORD         # Docker registry password
```

## Best Practices

1. **Fast Feedback**: Fail fast with early validation
2. **Caching**: Cache dependencies and build artifacts
3. **Parallelization**: Run independent jobs in parallel
4. **Security**: Scan for vulnerabilities early
5. **Notifications**: Alert on failures
6. **Versioning**: Use semantic versioning
7. **Artifacts**: Store build artifacts
8. **Environments**: Use GitHub environments for approvals

## Scripts Location

- **Pipeline Templates**: `infrastructure-ops/github-workflows/`
- **Deploy Scripts**: `infrastructure-ops/scripts/deploy-*.sh`
- **Health Checks**: `infrastructure-ops/scripts/health-check.sh`

## Related Skills

- `infrastructure-git-ops` - GitOps workflows
- `docker-deploy` - Docker deployments
- `github-workflow-automation` - Git automation

## References

- [GitHub Actions](https://docs.github.com/en/actions)
- [Workflow Syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [Security Hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
