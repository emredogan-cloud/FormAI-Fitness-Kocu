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
  bucket_name = "${replace(var.domain_name, ".", "-")}-legal-pages"
  tags = {
    Project   = "FormAI"
    Component = "legal-pages"
    ManagedBy = "terraform"
  }
}

# ---------------------------------------------------------------------------
# Route53 — assumes a public hosted zone for var.domain_name already exists.
# Used both for ACM DNS validation and for the CloudFront alias record.
# ---------------------------------------------------------------------------

data "aws_route53_zone" "primary" {
  name         = var.domain_name
  private_zone = false
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
  bucket       = aws_s3_bucket.legal_pages.id
  key          = "terms.html"
  source       = "${path.module}/../../web/public/terms.html"
  etag         = filemd5("${path.module}/../../web/public/terms.html")
  content_type = "text/html"
  cache_control = "public, max-age=300"

  depends_on = [aws_s3_bucket_policy.legal_pages_public_read]
}

resource "aws_s3_object" "privacy" {
  bucket       = aws_s3_bucket.legal_pages.id
  key          = "privacy.html"
  source       = "${path.module}/../../web/public/privacy.html"
  etag         = filemd5("${path.module}/../../web/public/privacy.html")
  content_type = "text/html"
  cache_control = "public, max-age=300"

  depends_on = [aws_s3_bucket_policy.legal_pages_public_read]
}

# ---------------------------------------------------------------------------
# ACM certificate — must be in us-east-1 to be usable by CloudFront.
# Covers the apex (formai.app) and the wildcard (*.formai.app).
# ---------------------------------------------------------------------------

resource "aws_acm_certificate" "legal_pages" {
  domain_name               = var.domain_name
  subject_alternative_names = ["*.${var.domain_name}"]
  validation_method         = "DNS"

  tags = local.tags

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = {
    for dvo in aws_acm_certificate.legal_pages.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = data.aws_route53_zone.primary.zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]

  allow_overwrite = true
}

resource "aws_acm_certificate_validation" "legal_pages" {
  certificate_arn         = aws_acm_certificate.legal_pages.arn
  validation_record_fqdns = [for r in aws_route53_record.acm_validation : r.fqdn]
}

# ---------------------------------------------------------------------------
# CloudFront — fronts the S3 website endpoint, terminates TLS using the
# ACM cert, redirects all HTTP traffic to HTTPS.
# ---------------------------------------------------------------------------

resource "aws_cloudfront_distribution" "legal_pages" {
  enabled             = true
  is_ipv6_enabled     = true
  comment             = "FormAI legal pages (terms + privacy)"
  default_root_object = "index.html"
  price_class         = "PriceClass_100"

  aliases = [var.domain_name]

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
    acm_certificate_arn      = aws_acm_certificate_validation.legal_pages.certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = local.tags
}

# ---------------------------------------------------------------------------
# Route53 alias — point apex domain (formai.app) at the CloudFront dist.
# CloudFront's hosted zone ID is the global constant Z2FDTNDATAQYW2.
# ---------------------------------------------------------------------------

resource "aws_route53_record" "apex_alias" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.legal_pages.domain_name
    zone_id                = aws_cloudfront_distribution.legal_pages.hosted_zone_id
    evaluate_target_health = false
  }
}
