variable "aws_region" {
  description = "AWS region for the S3 bucket. CloudFront itself is a global service. us-east-1 is the conventional default for buckets that back a CloudFront origin."
  type        = string
  default     = "us-east-1"
}
