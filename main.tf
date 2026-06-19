terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

variable "aws_region" {
  type    = string
  default = "ap-southeast-1"
}

variable "alert_email" {
  type        = string
  description = "The email address to receive alerts"
  default     = "rondepzai9@gmail.com"
}

resource "random_id" "bucket_suffix" {
  byte_length = 6
}

resource "aws_s3_bucket" "macie_bucket" {
  bucket        = "macie-demo-bucket-${random_id.bucket_suffix.hex}"
  force_destroy = true
}

resource "aws_s3_object" "sensitive_file" {
  bucket = aws_s3_bucket.macie_bucket.id
  key    = "sensitive_data.txt"
  source = "${path.module}/sensitive_data.txt"
  etag   = filemd5("${path.module}/sensitive_data.txt")
}

import {
  to = aws_macie2_account.macie
  id = "783459135560"
}

# Enable Amazon Macie
resource "aws_macie2_account" "macie" {
  finding_publishing_frequency = "FIFTEEN_MINUTES"
  status                       = "ENABLED"
}

# Create SNS Topic for findings
resource "aws_sns_topic" "macie_alerts" {
  name = "macie-alerts-topic"
}

# SNS Subscription for Email
resource "aws_sns_topic_subscription" "email_sub" {
  topic_arn = aws_sns_topic.macie_alerts.arn
  protocol  = "email"
  endpoint  = var.alert_email
}

# SNS Topic Policy to allow EventBridge to publish to the topic
resource "aws_sns_topic_policy" "sns_publish_policy" {
  arn    = aws_sns_topic.macie_alerts.arn
  policy = data.aws_iam_policy_document.sns_publish_policy_doc.json
}

data "aws_iam_policy_document" "sns_publish_policy_doc" {
  statement {
    effect = "Allow"
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
    actions   = ["SNS:Publish"]
    resources = [aws_sns_topic.macie_alerts.arn]
  }
}

# EventBridge Rule for Macie Findings
resource "aws_cloudwatch_event_rule" "macie_rule" {
  name        = "macie-findings-rule"
  description = "Triggers when Macie detects sensitive data"
  event_pattern = jsonencode({
    source      = ["aws.macie"]
    detail-type = ["Macie Finding"]
  })
}

# EventBridge Target to SNS
resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.macie_rule.name
  target_id = "SendToSNS"
  arn       = aws_sns_topic.macie_alerts.arn
}

data "aws_caller_identity" "current" {}

# Amazon Macie Classification Job
resource "aws_macie2_classification_job" "macie_job" {
  job_type = "ONE_TIME"
  name     = "macie-sensitive-data-discovery-${random_id.bucket_suffix.hex}"
  
  # Ensure the job runs after Macie is enabled and file is uploaded
  depends_on = [
    aws_macie2_account.macie,
    aws_s3_object.sensitive_file
  ]

  s3_job_definition {
    bucket_definitions {
      account_id = data.aws_caller_identity.current.account_id
      buckets    = [aws_s3_bucket.macie_bucket.id]
    }
  }
}

output "bucket_name" {
  value = aws_s3_bucket.macie_bucket.id
}

output "sns_topic_arn" {
  value = aws_sns_topic.macie_alerts.arn
}
