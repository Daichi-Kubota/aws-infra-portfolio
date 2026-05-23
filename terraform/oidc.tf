# GitHub Actions OIDC Provider
# 長期クレデンシャル（アクセスキー）不要で GitHub Actions から AWS を操作できる
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub Actions の OIDC トークン署名に使われる証明書のサムプリント
  # https://docs.github.com/en/actions/security-for-github-actions/security-hardening-your-deployments/configuring-openid-connect-in-amazon-web-services
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = {
    Name    = "github-actions-oidc"
    Project = var.project_name
  }
}

# GitHub Actions が assume する IAM Role
resource "aws_iam_role" "github_actions" {
  name = "${var.project_name}-github-actions-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # var.github_repository で制限（terraform.tfvars で設定）
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_repository}:*"
        }
      }
    }]
  })

  tags = {
    Name    = "${var.project_name}-github-actions-role"
    Project = var.project_name
  }
}

# CI に必要な最小権限ポリシー（read-only + tfstate アクセス）
resource "aws_iam_role_policy" "github_actions_ci" {
  name = "${var.project_name}-github-actions-ci-policy"
  role = aws_iam_role.github_actions.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # terraform plan に必要な読み取り権限
        Sid    = "TerraformReadOnly"
        Effect = "Allow"
        Action = [
          "ec2:Describe*",
          "vpc:Describe*",
          "iam:Get*",
          "iam:List*",
          "s3:GetObject",
          "s3:ListBucket",
          "cloudwatch:Describe*",
          "cloudwatch:Get*",
          "logs:Describe*",
          "sns:GetTopicAttributes",
          "sns:ListTopics",
          "route53:Get*",
          "route53:List*",
          "dynamodb:DescribeTable",
          "sts:GetCallerIdentity"
        ]
        Resource = "*"
      },
      {
        # tfstate の読み書き
        Sid    = "TFStateAccess"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}",
          "arn:aws:s3:::${var.project_name}-tfstate-${data.aws_caller_identity.current.account_id}/*"
        ]
      }
    ]
  })
}

output "github_actions_role_arn" {
  description = "GitHub Actions が assume する IAM Role ARN（GitHub Secrets に設定）"
  value       = aws_iam_role.github_actions.arn
}
