data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

resource "aws_ecr_repository" "repo" {
  name = "${var.team_name}/${var.repo_name}"
}

resource "aws_ecr_lifecycle_policy" "lifecycle_policy" {
  count      = "${var.enable_policy ? 1 : 0}"
  repository = "${aws_ecr_repository.repo.name}"

  policy = <<EOF
{
    "rules": [
        {
            "rulePriority": 2,
            "description": "Expire images over count 100",
            "selection": {
                "tagStatus": "any",
                "countType": "imageCountMoreThan",
                "countNumber": 100
            },
            "action": {
                "type": "expire"
            }
        }
    ]
}
EOF
}

resource "random_id" "user" {
  byte_length = 8
}

resource "aws_iam_user" "user" {
  name = "ecr-user-${random_id.user.hex}"
  path = "/system/ecr-user/${var.team_name}/"
}

resource "aws_iam_access_key" "key" {
  user = "${aws_iam_user.user.name}"
}

data "aws_iam_policy_document" "policy" {
  statement {
    actions = [
      "ecr:GetAuthorizationToken",
      "ecr:DescribeRepositories",
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:ListImages",
      "ecr:DescribeImages",
      "ecr:BatchGetImage",
    ]

    resources = [
      "*",
    ]
  }

  statement {
    actions = [
      "ecr:CompleteLayerUpload",
      "ecr:BatchDeleteImage",
      "ecr:UploadLayerPart",
      "ecr:InitiateLayerUpload",
      "ecr:PutImage",
    ]

    resources = [
      "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.team_name}/*",
    ]
  }
}

resource "aws_iam_user_policy" "policy" {
  name   = "ecr-read-write"
  policy = "${data.aws_iam_policy_document.policy.json}"
  user   = "${aws_iam_user.user.name}"
}
