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

**2. Bootstrap the Terraform backend**

The `bootstrap/` folder sets up two things your project needs before anything else can run:

- An **S3 bucket** to store Terraform state — this is how Terraform remembers what infrastructure it's already created, so it doesn't try to recreate everything on every run.
- A **DynamoDB table** for state locking — this prevents two people (or two CI runs) from modifying infrastructure at the same time.
- An **OIDC provider and IAM role** for GitHub Actions — this lets the CI/CD pipeline authenticate to AWS without storing any long-lived access keys as secrets.

Copy the example variables and fill in your values:

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

Then run:

```bash
terraform init
terraform apply
```

**3. Copy the OIDC role ARN into the workflow**

After bootstrap finishes, grab the role ARN it created:

```bash
terraform output gha_oidc_role_arn
```

Open `.github/workflows/infra.yml` and `.github/workflows/deploy.yml` and paste that ARN as the value of `AWS_OIDC_ROLE_ARN` in both:

```yaml
env:
  AWS_OIDC_ROLE_ARN: arn:aws:iam::123456789012:role/cred-devops-gha-oidc-role
```

This is what allows GitHub Actions to assume an AWS role and deploy on your behalf — without it, the pipelines can't reach AWS.

**4. Terraform variables**

In **CI**, the workflows set them automatically via `-var` flags in `.github/workflows/infra.yml` (`aws_region`, `project_name`, `image_name`, `image_tag`), so you don't need a `terraform.tfvars` file for the pipeline.

For **local** Terraform runs (e.g. `terraform plan`), copy the example and edit as needed:

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

**5. Push to `main`**

Once everything is configured, push to `main` and GitHub Actions takes over. Two workflows run:

- **Infrastructure** (`infra.yml`) — only triggers when `terraform/` files change. Runs `terraform apply` to update AWS resources.
- **Deploy** (`deploy.yml`) — triggers on every push to `main` *and* after the Infrastructure workflow completes. Runs tests, builds the Docker image, pushes it to GHCR, reads ECS details from Terraform outputs, and deploys to ECS.

On the very first push, both workflows run: Infrastructure creates the resources, then Deploy picks up the outputs and deploys the app.

### Pull requests

When you open a PR against `main`, two things happen automatically:

- **Tests run** — the Deploy workflow triggers and runs `npm test` to catch any broken code early.
- **Terraform plan** — if your PR includes changes to `terraform/` files, the Infrastructure workflow runs `terraform plan` so you can review exactly what infrastructure changes will be made before merging. Nothing is applied until the PR is merged.

### Subsequent deploys

Just push to `main`. If you only changed app code, only the Deploy workflow runs. If you changed Terraform files, Infrastructure runs first and Deploy follows automatically once it completes.

---

## Key Decisions

### Security

- **No secrets in plain text.** The database password is generated by Terraform using `random_password` and stored in AWS Secrets Manager. The full connection URL is also in Secrets Manager. ECS pulls these at runtime — nothing sensitive lives in code, environment variables, or task definitions.

- **No long-lived AWS credentials.** GitHub Actions authenticates via OIDC, so there are no access keys to rotate or leak.

- **Private by default.** The app and database both live in private subnets. Only the ALB is public-facing. The database is only reachable from the ECS tasks, and the ECS tasks are only reachable from the ALB. Each layer has its own security group with minimal rules.

- **HTTPS without a custom domain.** We don't own a domain for this project, but the app still needs to be served over HTTPS. Rather than buying a domain and setting up ACM certificates + Route53 DNS, we put CloudFront in front of the ALB. CloudFront comes with a free AWS-managed TLS certificate on its `*.cloudfront.net` URL, so we get HTTPS out of the box CloudFront also automatically redirects HTTP to HTTPS.

- **Non-root container.** The Docker image runs as `appuser`, not root.

### CI/CD

- **Test on every push and PR.** Tests always run first — nothing gets deployed if they fail.

- **Separate Infrastructure and Deploy workflows.** Terraform plan/apply lives in `infra.yml` and only runs when `terraform/` files change. The Deploy workflow (`deploy.yml`) handles testing, building, and deploying the app. Deploy automatically triggers after Infrastructure completes via `workflow_run`, so infra is always up to date before a deploy goes out.

- **Plan on PRs, apply on merge.** Pull requests get a `terraform plan` so you can review infrastructure changes before they go live. Merging to `main` triggers the actual apply.

- **Production environment gate.** Both `terraform-apply` and `deploy-production` use GitHub's `production` environment, so you can optionally require manual approval before changes go out.

### Infrastructure

- **ECS Fargate** — no servers to manage. Tasks run with 256 CPU / 512 MiB memory. The service keeps 2 tasks running and does rolling deploys (min 100%, max 200%).

- **CloudFront + ALB** — CloudFront is the public entry point (HTTPS), forwarding traffic to an internal ALB which routes to the ECS tasks. This keeps the ALB simple (HTTP only) and lets CloudFront handle TLS termination.

- **VPC with public and private subnets** across two availability zones. A NAT Gateway lets private resources reach the internet without being directly exposed.

- **RDS Postgres 16** on `db.t3.micro` with 7-day backup retention, sitting in private subnets.

- **Terraform state** is stored in S3 with versioning and encryption, locked via DynamoDB. The bootstrap step sets this up so the rest of the team shares one source of truth.

- **Logs** go to CloudWatch under `/ecs/cred-devops-{workspace}-app` with 7-day retention.
