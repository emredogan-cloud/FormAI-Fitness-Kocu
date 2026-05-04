variable "domain_name" {
  description = "Apex domain that hosts the legal pages (e.g. formai.app). The ACM certificate is issued for this name and the *.<domain_name> wildcard."
  type        = string
  default     = "formai.app"
}

variable "aws_region" {
  description = "AWS region for the S3 bucket and Route53 records. CloudFront is global, but its ACM certificate MUST live in us-east-1 — keep this value as us-east-1 unless you explicitly split the cert into a separate provider alias."
  type        = string
  default     = "us-east-1"
}
