# NOTE: Often created once per account; here for completeness.

data "aws_caller_identity" "current" {}

data "aws_iam_policy_document" "gha_oidc_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    actions = ["sts:AssumeRoleWithWebIdentity"]

    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_repository}:ref:refs/heads/main", "repo:${var.github_repository}:pull_request/*"]
    }
  }
}

resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  thumbprint_list = [
    "9e99a48a9960b14926bb7f3b02e22da2b0ab7280" # GitHub Actions root CA
  ]
}

variable "github_repository" {
  description = "GitHub owner/repo for OIDC trust"
  type        = string
}

resource "aws_iam_role" "gha_oidc" {
  name               = "${var.project_name}-gha-oidc-role"
  assume_role_policy = data.aws_iam_policy_document.gha_oidc_trust.json
}

resource "aws_iam_role_policy" "gha_oidc" {
  name = "${var.project_name}-gha-oidc-policy"
  role = aws_iam_role.gha_oidc.id

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "ecs:Describe*",
          "ecs:UpdateService",
          "ecs:RegisterTaskDefinition",
          "iam:PassRole",
          "cloudwatch:PutMetricData",
          "logs:*",
          "elasticloadbalancing:*",
          "ec2:Describe*",
          "rds:*",
          "acm:*",
          "route53:*",
          "s3:*",
          "dynamodb:*"
        ],
        Resource = "*"
      }
    ]
  })
}
