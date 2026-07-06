# GitHub Actions → AWS ECS — CI/CD with Security Scanning & Monitoring

A complete, production-style pipeline that takes code from your laptop to the cloud automatically — with security checks built in at every step.

---

## What This Project Does

Every time you push code to GitHub, a fully automated pipeline runs. It checks your code for security problems, packages it into a container, runs more security checks on the container, and then deploys it to AWS — all without you doing anything manually.

Think of it like a strict security gate at an airport. Your code goes through multiple checkpoints before it's allowed to fly into production.

---

## The Pipeline at a Glance

```
You push code to GitHub
         |
         v
+--------+--------+--------+
|        |        |        |
Bandit  pip-audit  Gitleaks    <-- 3 security scans run at the same time
(code)  (libraries) (secrets)
|        |        |        |
+--------+--------+--------+
         |
         v
   Build Docker Image
   Push to AWS ECR (image storage)
         |
         v
   Trivy Scan (scan the image itself)
         |
         v
   Deploy to AWS ECS (your app goes live)
         |
         v
   Prometheus collects metrics
   Grafana shows dashboards
```

---

## Project Structure

```
.
├── app/
│   ├── app.py              # The web application (Python/Flask)
│   ├── requirements.txt    # Python libraries the app needs
│   ├── Dockerfile          # Instructions to package the app into a container
│   └── .dockerignore       # Files to exclude from the container
│
├── .github/
│   └── workflows/
│       ├── ci-cd.yml       # Main pipeline — runs on every push to main
│       └── pr-checks.yml   # Runs lint and tests on pull requests
│
├── terraform/
│   ├── main.tf             # All AWS infrastructure defined as code
│   ├── variables.tf        # Configurable inputs
│   └── outputs.tf          # Values printed after setup (URLs, ARNs)
│
├── monitoring/
│   ├── prometheus/
│   │   └── prometheus.yml  # Tells Prometheus where to collect data from
│   └── grafana/
│       └── provisioning/   # Auto-configures Grafana on startup
│
├── scripts/
│   └── setup-oidc.sh       # One-time script to connect GitHub to AWS securely
│
└── docker-compose.yml      # Run the full stack locally for development
```

---

## Technology Glossary

Before diving in, here is plain-English meaning of every tool used.

| Term | What it actually is |
|------|---------------------|
| **GitHub Actions** | A built-in GitHub feature that runs automated tasks when you push code |
| **Docker** | A way to package an app and everything it needs into one portable box (called a container) |
| **AWS ECR** | Amazon's private storage for Docker containers — like Google Drive, but for containers |
| **AWS ECS Fargate** | Amazon's service that runs your containers without you needing to manage any servers |
| **ALB** | Application Load Balancer — the front door of your app; routes internet traffic to your containers |
| **Terraform** | A tool that creates cloud infrastructure by reading config files — no clicking in the AWS console |
| **OIDC** | A secure handshake method that lets GitHub talk to AWS without storing any passwords |
| **Bandit** | Scans Python code for common security mistakes |
| **pip-audit** | Checks if any of your Python libraries have known vulnerabilities |
| **Gitleaks** | Searches your entire git history for accidentally committed secrets (API keys, passwords) |
| **Trivy** | Scans the final Docker image for vulnerabilities in the operating system and libraries |
| **Prometheus** | Collects numbers from your app over time (request count, response time, etc.) |
| **Grafana** | Turns Prometheus numbers into visual dashboards and charts |
| **SARIF** | A standard file format for security scan results — GitHub reads these and shows them in the Security tab |

---

## The Application

The app is a minimal Python web server with three pages:

| Endpoint | What it returns |
|----------|----------------|
| `/` | A JSON response confirming the app is running |
| `/health` | A health check — ECS uses this to know if your container is alive |
| `/metrics` | Live numbers in Prometheus format — request counts, response times |

---

## Security Scans Explained

### Bandit — Code Scanner
Bandit reads your Python source code and looks for patterns that are known to be dangerous. For example: hardcoded passwords, use of old encryption functions, or code that could be exploited by attackers.

### pip-audit — Dependency Scanner
Your app uses libraries written by other people (Flask, gunicorn). Those libraries can have vulnerabilities discovered after you installed them. pip-audit checks against public databases of known vulnerabilities (CVEs).

### Gitleaks — Secret Scanner
Developers sometimes accidentally commit passwords or API keys into git. Even if you delete the file later, git keeps the history. Gitleaks scans every commit, ever, to find secrets that should not be there.

### Trivy — Container Image Scanner
After the Docker image is built, Trivy scans it. This catches vulnerabilities at the operating system level — things that Bandit and pip-audit would miss because they only look at Python code.

---

## Prerequisites

Install these tools on your computer before starting.

| Tool | Purpose | Download |
|------|---------|----------|
| AWS CLI | Lets your terminal talk to AWS | https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html |
| Terraform | Creates AWS infrastructure from config files | https://developer.hashicorp.com/terraform/install |
| Docker | Builds and runs containers locally | https://docs.docker.com/get-docker/ |
| Git | Version control | https://git-scm.com |

---

## Setup Guide

Work through these phases in order. Each phase builds on the previous one.

---

### Phase 1 — Run the App Locally

This phase has nothing to do with AWS. You are just making sure the application works on your machine before touching any cloud services.

**Step 1 — Install Python dependencies and start the app**

```bash
cd app
pip install -r requirements.txt
python app.py
```

Open your browser and visit:
- `http://localhost:5000` — you should see a JSON message
- `http://localhost:5000/health` — you should see `{"status": "healthy"}`
- `http://localhost:5000/metrics` — you should see raw text with numbers

**Step 2 — Run the full local monitoring stack**

This starts your app, Prometheus, and Grafana all at once using Docker Compose.

```bash
# From the project root directory
docker-compose up --build
```

- `http://localhost:5000` — Flask app
- `http://localhost:9090` — Prometheus (data collector)
- `http://localhost:3000` — Grafana (dashboards) — login: `admin` / `admin123`

Hit your app endpoint a few times, then go to Prometheus and search for `app_request_count_total`. You will see the number climbing. This is Prometheus collecting metrics from your app.

---

### Phase 2 — Set Up AWS

**Step 3 — Configure the AWS CLI**

```bash
aws configure
```

Enter your AWS Access Key ID and Secret Access Key when prompted. You can create these in the AWS console under IAM → your user → Security credentials.

Set the default region to `ap-south-1` (Mumbai).

**Step 4 — Create the GitHub–AWS trust relationship (run once)**

By default, GitHub has no way to talk to AWS. This step creates a trust relationship using OIDC — a cryptographic handshake — so GitHub Actions can request temporary AWS credentials without storing any passwords.

```bash
chmod +x scripts/setup-oidc.sh
./scripts/setup-oidc.sh
```

You only ever need to run this once per AWS account.

**Step 5 — Create all AWS infrastructure with Terraform**

Terraform reads the files in the `terraform/` folder and creates everything your app needs in AWS: the network, the container registry, the load balancer, the ECS cluster, and the IAM roles.

```bash
cd terraform

# Download the AWS provider
terraform init

# Preview everything that will be created — read this output carefully
terraform plan \
  -var="github_org=Lakshya6373" \
  -var="github_repo=Github_Action_AWS"

# Create all resources (takes around 3 minutes)
terraform apply \
  -var="github_org=Lakshya6373" \
  -var="github_repo=Github_Action_AWS"
```

After it finishes, you will see output like this:

```
alb_dns_name            = "http://xxxx.ap-south-1.elb.amazonaws.com"
ecr_repository_url      = "123456789.dkr.ecr.ap-south-1.amazonaws.com/..."
github_actions_role_arn = "arn:aws:iam::123456789:role/..."
```

Copy the `github_actions_role_arn` value. You need it in the next step.

---

### Phase 3 — Connect GitHub to AWS

**Step 6 — Add the IAM Role ARN as a GitHub secret**

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** → **New repository secret**

| Secret name | Value |
|-------------|-------|
| `AWS_ROLE_ARN` | The `github_actions_role_arn` value from Step 5 |

This is the only secret you need. There are no AWS access keys stored in GitHub. The OIDC trust you set up in Step 4 handles authentication — GitHub proves its identity, AWS issues a temporary token that expires after one hour.

---

### Phase 4 — Deploy

**Step 7 — Push code and watch the pipeline run**

```bash
git add .
git commit -m "initial deployment"
git push origin main
```

Go to your GitHub repository → **Actions** tab.

You will see the pipeline running. Here is what each job does and roughly how long it takes:

| Job | What it does | Time |
|-----|-------------|------|
| Bandit SAST | Scans Python source code | ~30 seconds |
| pip-audit SCA | Checks library vulnerabilities | ~30 seconds |
| Gitleaks | Scans git history for secrets | ~20 seconds |
| Build & Push | Builds Docker image, pushes to ECR | ~2 minutes |
| Trivy Image Scan | Scans the Docker image | ~1 minute |
| Deploy to ECS | Updates ECS to run the new image | ~2 minutes |

Total time from push to live: approximately 6–8 minutes.

**Step 8 — Verify the deployment**

```bash
# Check that ECS is running your container
aws ecs describe-services \
  --cluster github-actions-cluster \
  --services github-actions-service \
  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount}'

# Get your app's public URL
aws elbv2 describe-load-balancers \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

Open `http://YOUR_ALB_DNS` in a browser. Your app is live.

---

### Phase 5 — Set Up Monitoring

**Step 9 — Point Prometheus at your live app**

Edit `monitoring/prometheus/prometheus.yml` and replace `YOUR_ALB_DNS_OR_LOCALHOST` with your ALB DNS name from Step 8.

```yaml
static_configs:
  - targets: ['your-alb-dns.ap-south-1.elb.amazonaws.com:80']
```

For local development, keep it as `localhost:5000` when running docker-compose.

**Step 10 — Build a Grafana dashboard**

1. Open `http://localhost:3000` and log in with `admin` / `admin123`
2. Go to **Dashboards** → **New** → **New Dashboard** → **Add visualization**
3. Select **Prometheus** as the data source
4. Add the following panels:

| Panel title | Query to paste |
|-------------|---------------|
| Request Rate | `rate(app_request_count_total[5m])` |
| Error Rate | `rate(app_request_count_total{status!="200"}[5m])` |
| Response Time (p99) | `histogram_quantile(0.99, rate(app_request_latency_seconds_bucket[5m]))` |
| Total Requests | `sum(app_request_count_total)` |

5. Save the dashboard as "App Overview"

---

## Day-to-Day Workflow

Once setup is complete, your workflow is just this:

```bash
# Make a change to any file
git add .
git commit -m "describe your change"
git push origin main
```

The pipeline handles everything else automatically. Your change will be live in around 6 minutes.

---

## Checking Logs

If something goes wrong, look at the container logs in AWS:

```bash
aws logs tail /ecs/github-actions-ecs --follow
```

---

## Cleaning Up (Removing All AWS Resources)

To avoid ongoing AWS charges, destroy all resources when you are done:

```bash
cd terraform
terraform destroy \
  -var="github_org=Lakshya6373" \
  -var="github_repo=Github_Action_AWS"
```

This removes everything Terraform created. Your GitHub repository and local files are not affected.

---

## Common Issues

**Pipeline fails with "not authorized to perform sts:AssumeRoleWithWebIdentity"**
The `AWS_ROLE_ARN` secret in GitHub does not match the role ARN from Terraform. Double-check you copied the full ARN exactly.

**ECS task keeps stopping**
The container is probably failing its health check. Look at the logs:
```bash
aws logs tail /ecs/github-actions-ecs --follow
```

**ALB returns a 503 error**
Wait 2–3 minutes after deployment. ECS needs time to start the container and pass health checks before the ALB routes traffic to it.

**"OIDC provider already exists" error when running setup-oidc.sh**
The provider was already created. This is fine — skip that script and go straight to Terraform.

---

## What Comes Next

This project is intentionally minimal so you can understand every piece. Future additions planned:

- Add a PostgreSQL database (Amazon RDS)
- Add caching with Redis (Amazon ElastiCache)
- Add HTTPS with a real certificate (Amazon ACM)
- Add auto-scaling so the app handles more traffic automatically
- Add blue/green deployments for zero-downtime releases
- Add a Web Application Firewall (AWS WAF)

---

## References

- GitHub Actions documentation — https://docs.github.com/en/actions
- AWS ECS documentation — https://docs.aws.amazon.com/ecs/
- Terraform AWS provider — https://registry.terraform.io/providers/hashicorp/aws/latest/docs
- Prometheus documentation — https://prometheus.io/docs/
- Grafana documentation — https://grafana.com/docs/
- Trivy documentation — https://aquasecurity.github.io/trivy/
- Bandit documentation — https://bandit.readthedocs.io/
