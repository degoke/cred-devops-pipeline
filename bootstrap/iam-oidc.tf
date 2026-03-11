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
      values   = [
        "repo:${var.github_repository}:ref:refs/heads/main",
        "repo:${var.github_repository}:pull_request/*",
        "repo:${var.github_repository}:environment:production"
      ]
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
          "ecs:*",
          "iam:GetRole",
          "iam:CreateRole",
          "iam:DeleteRole",
          "iam:UpdateRole",
          "iam:PutRolePolicy",
          "iam:GetRolePolicy",
          "iam:DeleteRolePolicy",
          "iam:ListRolePolicies",
          "iam:AttachRolePolicy",
          "iam:DetachRolePolicy",
          "iam:ListAttachedRolePolicies",
          "iam:ListInstanceProfilesForRole",
          "iam:TagRole",
          "iam:UntagRole",
          "iam:PassRole",
          "cloudwatch:PutMetricData",
          "logs:*",
          "elasticloadbalancing:*",
          "ec2:*",
          "rds:*",
          "acm:*",
          "route53:*",
          "s3:*",
          "dynamodb:*",
          "cloudfront:*"
        ],
        Resource = "*"
      },
      {
        Effect = "Allow",
        Action = [
          "secretsmanager:CreateSecret",
          "secretsmanager:DeleteSecret",
          "secretsmanager:DescribeSecret",
          "secretsmanager:GetSecretValue",
          "secretsmanager:PutSecretValue",
          "secretsmanager:UpdateSecret",
          "secretsmanager:GetResourcePolicy",
          "secretsmanager:TagResource",
          "secretsmanager:UntagResource"
        ],
        Resource = "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:${var.project_name}-*"
      }
    ]
  })
}
