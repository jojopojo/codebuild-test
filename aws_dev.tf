terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      #version = "~> 5.5.0"
      version = "~> 5"
    }
    archive = {
      source  = "hashicorp/archive"
      version = "~> 2.4"
    }
  }
}

locals {
  aws_access_key_id     = var.aws_access_key
  aws_secret_access_key = var.aws_secret_key
  aws_session_token     = var.aws_token
  bucket_name           = var.bucket_name

  github_owner  = var.github_user
  github_repo   = var.github_repo
  github_branch = var.github_branch
  github_token  = var.github_token
}

provider "aws" {
  region = "eu-north-1"  # Update to your AWS region
  access_key = local.aws_access_key_id
  secret_key = local.aws_secret_access_key
  token      = local.aws_session_token
}

### S3 bucket for development release ###

resource "aws_s3_bucket" "bucket" {
  bucket = local.bucket_name  # Make sure the bucket name is globally unique

  tags = {
    Name = "blog-dev-bucket"
    Environment = "Dev"
  }

}

resource "aws_s3_bucket_policy" "s3_bucket_policy" {
  bucket = aws_s3_bucket.bucket.id
  policy = jsonencode({
    Version: "2012-10-17",
    Id: "Policy",
    Statement: [
      {
        Sid: "Stmt",
        Effect: "Allow",
        Principal: {
          AWS: "arn:aws:iam::cloudfront:user/CloudFront Origin Access Identity ${aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn}"
        },
        Action: "s3:GetObject",
        Resource: "arn:aws:s3:::${local.bucket_name}/*"
      }
    ]
  })
}

/*
resource "aws_s3_bucket_acl" "bucket_acl" {
    bucket = aws_s3_bucket.bucket.id
    acl    = "private"
}
*/
### Lambda@Edge to restrict website access ###

provider "aws" {
  alias = "us-east"
  region = "us-east-1" # Lambda@Edge must be created in us-east-1
  access_key = local.aws_access_key_id
  secret_key = local.aws_secret_access_key
  token      = local.aws_session_token
}

/*
data "aws_iam_policy_document" "lambda_assume_role_policy" {
  provider = aws.us-east
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com", "edgelambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "lambda_edge_iam_role" {
  provider           = aws.us-east
  name               = "lambda_edge_iam_role"
  assume_role_policy = data.aws_iam_policy_document.lambda_assume_role_policy.json
}

resource "aws_iam_policy" "lambda_policy" {
  provider    = aws.us-east
  name        = "lambda_policy"
  description = "Policy for Lambda@Edge function for developer-blog-dev"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
        ],
        Resource = "arn:aws:logs:*:*:*",
      },
    ],
  })

}

resource "aws_iam_policy_attachment" "lambda_policy_attachment" {
  provider   = aws.us-east
  name       = "lambda_policy_attachment"
  roles      = [aws_iam_role.lambda_edge_iam_role.name]
  policy_arn = "arn:aws:iam::aws:policy/AWSLambda_FullAccess"
  # policy_arn = aws_iam_policy.lambda_policy.arn
}

data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "${path.module}/lambda_edge_auth.js"
  output_path = "${path.module}/lambda_edge_auth.zip"
}

resource "aws_lambda_function" "edge_function" {
  provider      = aws.us-east 
  filename      = data.archive_file.lambda_zip.output_path
  function_name = "edge_function"
  role          = aws_iam_role.lambda_edge_iam_role.arn
  handler       = "lambda_edge_auth.handler" # your handler goes here
  runtime       = "nodejs14.x"    # your runtime goes here

  source_code_hash = filebase64sha256(data.archive_file.lambda_zip.output_path)

  publish = true

  lifecycle {
    ignore_changes = [
      filename,
    ]
  }
}

*/

### CloudFront ###

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "OAI for ${local.bucket_name} bucket"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.bucket.bucket_regional_domain_name
    origin_id   = aws_s3_bucket.bucket.id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "Cloudfront Distribution for ${local.bucket_name} bucket"
  default_root_object = "index.html"

  default_cache_behavior {
    allowed_methods  = ["HEAD", "DELETE", "POST", "GET", "OPTIONS", "PUT", "PATCH"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = aws_s3_bucket.bucket.id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }
/*
    ### Lambda for password access ###
    lambda_function_association {
      event_type   = "viewer-request"
      lambda_arn   = "${aws_lambda_function.edge_function.qualified_arn}"
      include_body = false
    }
*/
    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400

  }

  price_class = "PriceClass_100"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["FI" , "SE"]
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}


data "aws_caller_identity" "current" {}
/*
data "aws_s3_bucket" "bucket" {
  bucket = local.bucket_name
}
*/
resource "aws_s3_bucket" "codepipeline_bucket" {
  bucket = "${local.bucket_name}-artifact"
}

resource "aws_codepipeline" "pipeline" {
  name     = "${local.bucket_name}-pipeline"
  role_arn = aws_iam_role.codepipeline_role.arn
  # role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.bucket_name}-codepipeline-role"

  artifact_store {
    location = aws_s3_bucket.codepipeline_bucket.bucket
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "ThirdParty"
      provider         = "GitHub"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        Owner  = local.github_owner
        Repo   = local.github_repo
        Branch = local.github_branch
        OAuthToken = local.github_token
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]
      version          = "1"

      configuration = {
        # ProjectName = aws_codebuild_project.example.name
        ProjectName = "devBuild"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "S3"
      input_artifacts = ["build_output"]
      version         = "1"

      configuration = {
        BucketName = aws_s3_bucket.bucket.bucket
        Extract    = "true"
      }
    }
  }
}

resource "aws_codebuild_project" "code_build" {
  name          = "${local.bucket_name}_codebuild"
  description   = "builds project"
  build_timeout = "5"
  service_role  = aws_iam_role.codebuild_role.arn
  # service_role  = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/${local.bucket_name}-codebuild-role"

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/ubuntu-base:14.04"
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  source {
    type      = "CODEPIPELINE"
    buildspec = file("dev_buildspec.yml")
  }
}

# IAM Role for CodePipeline
resource "aws_iam_role" "codepipeline_role" {
  name = "${var.codepipeline_name}_codepipeline_service_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codepipeline.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

# IAM Role for CodeBuild
resource "aws_iam_role" "codebuild_role" {
  name = "${var.codepipeline_name}_codebuild_service_role"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}


resource "aws_iam_policy" "codebuild_s3_access" {
  name        = "CodeBuildS3Access"
  description = "Grant CodeBuild access to S3"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "CodeBuildS3Access",
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*",
                "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}",
                "arn:aws:s3:::${aws_s3_bucket.codepipeline_bucket.bucket}/*",
                "arn:aws:s3:::${aws_s3_bucket.codepipeline_bucket.bucket}"
            ]
        }
    ]
}
EOF
}

resource "aws_iam_policy" "codedeploy_s3_access" {
  name        = "CodeDeployS3Access"
  description = "Grant CodeDeploy access to S3"

  policy = jsonencode({
    Version: "2012-10-17",
    Statement: [
        {
            Sid: "CodeDeployS3Access",
            Effect: "Allow",
            Action: [
                "s3:GetObject",
                "s3:GetObjectVersion",
                "s3:PutObject",
                "s3:ListBucket"
            ],
            Resource: [
                "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}/*",
                "arn:aws:s3:::${aws_s3_bucket.bucket.bucket}",
                "arn:aws:s3:::${aws_s3_bucket.codepipeline_bucket.bucket}/*",
                "arn:aws:s3:::${aws_s3_bucket.codepipeline_bucket.bucket}"
            ]
        }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "codebuild_s3_access" {
  role       = aws_iam_role.codebuild_role.name
  policy_arn = aws_iam_policy.codebuild_s3_access.arn
}

resource "aws_iam_role_policy_attachment" "codedeploy_s3_access" {
  role       = aws_iam_role.codepipeline_role.name
  policy_arn = aws_iam_policy.codedeploy_s3_access.arn
}
