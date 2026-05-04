terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# ---------------------------------------------------------------------------
# Locals
# ---------------------------------------------------------------------------

locals {
  # Globally unique S3 bucket name. If you fork this template and the name
  # is already taken, append your own suffix (e.g. -<initials>).
  bucket_name = "formai-legal-pages-bucket-unique"
  tags = {
    Project   = "FormAI"
    Component = "legal-pages"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# S3 — static website bucket holding terms.html / privacy.html
# ---------------------------------------------------------------------------

resource "aws_s3_bucket" "legal_pages" {
  bucket = local.bucket_name
  tags   = local.tags
}

resource "aws_s3_bucket_website_configuration" "legal_pages" {
  bucket = aws_s3_bucket.legal_pages.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "404.html"
  }
}

resource "aws_s3_bucket_ownership_controls" "legal_pages" {
  bucket = aws_s3_bucket.legal_pages.id

  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "legal_pages" {
  bucket = aws_s3_bucket.legal_pages.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "legal_pages_public_read" {
  bucket = aws_s3_bucket.legal_pages.id

  depends_on = [
    aws_s3_bucket_public_access_block.legal_pages,
    aws_s3_bucket_ownership_controls.legal_pages,
  ]

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.legal_pages.arn}/*"
      }
    ]
  })
}

# ---------------------------------------------------------------------------
# S3 objects — the actual HTML files. etag = filemd5() ensures Terraform
# re-uploads whenever the file content changes.
# ---------------------------------------------------------------------------

resource "aws_s3_object" "terms" {
  bucket        = aws_s3_bucket.legal_pages.id
  key           = "terms.html"
  source        = "${path.module}/../../web/public/terms.html"
  etag          = filemd5("${path.module}/../../web/public/terms.html")
  content_type  = "text/html"
  cache_control = "public, max-age=300"

  depends_on = [aws_s3_bucket_policy.legal_pages_public_read]
}

resource "aws_s3_object" "privacy" {
  bucket        = aws_s3_bucket.legal_pages.id
  key           = "privacy.html"
  source        = "${path.module}/../../web/public/privacy.html"
  etag          = filemd5("${path.module}/../../web/public/privacy.html")
  content_type  = "text/html"
  cache_control = "public, max-age=300"

  depends_on = [aws_s3_bucket_policy.legal_pages_public_read]
}

# ---------------------------------------------------------------------------
# CloudFront — fronts the S3 website endpoint and terminates TLS using
# the default *.cloudfront.net certificate (zero cost; no custom domain).
# Redirects all HTTP traffic to HTTPS.
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "legal_pages" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "FormAI legal pages (terms + privacy)"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  origin {
    domain_name = aws_s3_bucket_website_configuration.legal_pages.website_endpoint
    origin_id   = "s3-website-${aws_s3_bucket.legal_pages.id}"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    target_origin_id       = "s3-website-${aws_s3_bucket.legal_pages.id}"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    min_ttl     = 0
    default_ttl = 300
    max_ttl     = 3600
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = local.tags
}
