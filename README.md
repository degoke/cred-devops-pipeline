# cred-devops-pipeline

A Node.js API backed by PostgreSQL, deployed to AWS ECS Fargate with Terraform and GitHub Actions.

---

## Running Locally

Everything runs through Docker Compose — no need to install Node or Postgres on your machine.

```bash
docker compose up
```

That's it. The app starts on **port 3000** and a local Postgres database spins up alongside it.

If you prefer running Node directly:

```bash
npm install
npm run dev
```

You'll need a `DATABASE_URL` environment variable pointing at a Postgres instance (e.g. `postgres://postgres:postgres@localhost:5432/appdb`).

---

## Accessing the App

Once it's running locally, you have three endpoints:

| Endpoint | What it does |
|----------|--------------|
| `GET /health` | Quick health check — returns `{ "status": "healthy" }` |
| `GET /status` | Uptime, version, and whether the database is reachable |
| `POST /process` | Send `{ "payload": "..." }` — it gets stored in the DB and returned back processed |

Locally: `http://localhost:3000/health`

In production, the app is served through CloudFront, so you'd access it at the CloudFront URL that Terraform outputs (something like `https://d1234abcdef.cloudfront.net/health`).

---

## Deploying the Application

### First time (fresh AWS account)

**1. Set up the AWS CLI**

Before anything else, make sure you have the [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) installed and you're logged in:

```bash
aws login
```

This is how Terraform will talk to your AWS account. You need valid credentials before any of the next steps will work.

**2. Bootstrap AWS resources**

The `bootstrap/` folder sets up the foundational AWS resources your project needs before anything else can run. You can either use the Terraform configs provided, or create these resources manually through the AWS Console — the end result is the same.

Resources created by bootstrap:

- An **S3 bucket** to store Terraform state — this is how Terraform remembers what infrastructure it's already created, so it doesn't try to recreate everything on every run.
- A **DynamoDB table** for state locking — this prevents two people (or two CI runs) from modifying infrastructure at the same time.
- An **OIDC provider and IAM role** for GitHub Actions — this lets the CI/CD pipeline authenticate to AWS without storing any long-lived access keys as secrets.
- A **Secrets Manager secret** for GHCR credentials — ECS needs to authenticate with GitHub Container Registry to pull your Docker images (since GHCR repos are private by default).

To bootstrap with Terraform, copy the example variables and fill in your values:

```bash
cd bootstrap
cp terraform.tfvars.example terraform.tfvars
```

The bootstrap variables are:

| Variable | What to put |
|----------|-------------|
| `aws_region` | The AWS region you want everything in (e.g. `us-east-1`) |
| `state_bucket_name` | A globally unique S3 bucket name for Terraform state |
| `lock_table_name` | Name for the DynamoDB lock table |
| `project_name` | Your project name (e.g. `cred-devops`) |
| `github_repository` | Your GitHub repo in `owner/repo` format (e.g. `degoke/cred-devops-pipeline`) |
| `ghcr_username` | Your GitHub username |
| `ghcr_pat` | A GitHub Personal Access Token with `read:packages` scope (see step 3) |

**3. Create a GitHub PAT**

ECS Fargate needs credentials to pull images from GitHub Container Registry. Before running bootstrap, go to [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens) and create a new token (classic) with the `read:packages` scope. Paste the username and token into your `terraform.tfvars`.

The PAT is marked as `sensitive` in Terraform so it won't show up in plan/apply output, but keep in mind it will be stored in the Terraform state file — make sure your state bucket is properly secured (bootstrap enables versioning and encryption by default).

Then run:

```bash
terraform init
terraform apply
```

This creates all the bootstrap resources including the GHCR credentials secret in AWS Secrets Manager, pre-populated with your GitHub PAT. You only need to do this once.

**4. Copy the OIDC role ARN into the workflow**

Grab the role ARN that bootstrap created:

```bash
terraform output gha_oidc_role_arn
```

Open `.github/workflows/deploy.yml` and paste that ARN as the value of `AWS_OIDC_ROLE_ARN`:

```yaml
env:
  AWS_OIDC_ROLE_ARN: arn:aws:iam::123456789012:role/cred-devops-gha-oidc-role
```

This is what allows GitHub Actions to assume an AWS role and deploy on your behalf — without it, the pipeline can't reach AWS.

**5. Terraform variables**

In **CI**, the workflow sets them automatically via `-var` flags in `.github/workflows/deploy.yml` (`aws_region`, `project_name`, `image_name`, `image_tag`), so you don't need a `terraform.tfvars` file for the pipeline.

For **local** Terraform runs (e.g. `terraform plan`), copy the example and edit as needed:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

**6. Push to `main`**

Once everything is configured, push to `main` and GitHub Actions takes over. A single workflow (`deploy.yml`) runs the full pipeline in order:

1. **Test** — runs `npm test` to catch broken code early.
2. **Build & push** — builds the Docker image and pushes it to GHCR, tagged with the commit SHA.
3. **Terraform apply** — applies infrastructure changes, including the ECS task definition that references the image just built.
4. **Deploy** — forces a new ECS deployment so the service picks up the updated task definition.

The image is always built *before* Terraform runs, so the ECS task definition never references an image that doesn't exist yet.

### Pull requests

When you open a PR against `main`, the same workflow runs but only the relevant jobs:

- **Tests run** — `npm test` catches any broken code early.
- **Terraform plan** — shows exactly what infrastructure changes will be made if the PR is merged. Nothing is applied until the PR lands on `main`.

### Subsequent deploys

Just push to `main`. Every push runs the full pipeline: test, build, apply, deploy.

---

## Key Decisions

### Observability and Monitoring

Below are a few screenshots from the live environment to show what a healthy deployment looks like:

- **ECS service metrics (CPU & memory)**  
  ![ECS service metrics](assets/Screenshot_2026-03-11_at_18.07.33-74bb99bd-5aca-48f0-8b59-b3fb3a25f9e4.png)

- **ECS service logs in CloudWatch**  
  ![ECS service logs](assets/Screenshot_2026-03-11_at_18.06.40-febf213c-9706-4f26-ba08-0cc93e804079.png)

- **CloudFront `/health` endpoint check**  
  ![CloudFront /health request](assets/Screenshot_2026-03-11_at_18.24.00-ceac1578-4470-412c-8873-9447b508b17d.png)

### Security

- **No secrets in plain text.** The database password is generated by Terraform using `random_password` and stored in AWS Secrets Manager. The full connection URL is also in Secrets Manager. GHCR credentials are stored in Secrets Manager too. ECS pulls all of these at runtime — nothing sensitive lives in code, environment variables, or task definitions.

- **No long-lived AWS credentials.** GitHub Actions authenticates via OIDC, so there are no access keys to rotate or leak.

- **Private image registry authentication.** ECS authenticates with GHCR using a GitHub PAT stored in Secrets Manager. The ECS task execution role has a scoped-down policy that only allows reading that specific secret.

- **Private by default.** The app and database both live in private subnets. Only the ALB is public-facing. The database is only reachable from the ECS tasks, and the ECS tasks are only reachable from the ALB. Each layer has its own security group with minimal rules.

- **HTTPS without a custom domain.** We don't own a domain for this project, but the app still needs to be served over HTTPS. Rather than buying a domain and setting up ACM certificates + Route53 DNS, we put CloudFront in front of the ALB. CloudFront comes with a free AWS-managed TLS certificate on its `*.cloudfront.net` URL, so we get HTTPS out of the box. CloudFront also automatically redirects HTTP to HTTPS.

- **Non-root container.** The Docker image runs as `appuser`, not root.

### CI/CD

- **Test on every push and PR.** Tests always run first — nothing gets deployed if they fail.

- **Single pipeline with correct ordering.** Everything lives in one workflow (`deploy.yml`). On push to `main`, the jobs run in order: test → build & push → terraform apply → deploy. This guarantees the Docker image exists before Terraform creates a task definition that references it, and infrastructure is up to date before the ECS deployment rolls out.

- **Plan on PRs, apply on merge.** Pull requests get a `terraform plan` so you can review infrastructure changes before they go live. Merging to `main` triggers the actual apply.

- **Production environment gate.** Both `terraform-apply` and `deploy` use GitHub's `production` environment, so you can optionally require manual approval before changes go out.

### Infrastructure

- **ECS Fargate** — no servers to manage. Tasks run with 256 CPU / 512 MiB memory. The service keeps 2 tasks running and does rolling deploys (min 100%, max 200%).

- **CloudFront + ALB** — CloudFront is the public entry point (HTTPS), forwarding traffic to an internal ALB which routes to the ECS tasks. This keeps the ALB simple (HTTP only) and lets CloudFront handle TLS termination.

- **VPC with public and private subnets** across two availability zones. A NAT Gateway lets private resources reach the internet without being directly exposed.

- **RDS Postgres 16** on `db.t3.micro` with 7-day backup retention, sitting in private subnets.

- **Terraform state** is stored in S3 with versioning and encryption, locked via DynamoDB. The bootstrap step sets this up so the rest of the team shares one source of truth.

- **Logs** go to CloudWatch under `/ecs/cred-devops-{workspace}-app` with 7-day retention.
