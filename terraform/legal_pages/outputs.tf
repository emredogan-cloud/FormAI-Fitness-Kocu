output "cloudfront_domain_name" {
  description = "CloudFront distribution domain (e.g. dxxxxxxxx.cloudfront.net). This is the live HTTPS hostname for the legal pages — paste it into App Store Connect / Play Console listings."
  value       = aws_cloudfront_distribution.legal_pages.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID — needed for `aws cloudfront create-invalidation` after editing the HTML."
  value       = aws_cloudfront_distribution.legal_pages.id
}

output "s3_bucket_name" {
  description = "Name of the S3 bucket holding the rendered HTML pages."
  value       = aws_s3_bucket.legal_pages.bucket
}

output "s3_website_endpoint" {
  description = "Direct S3 website endpoint (HTTP only). Useful for debugging origin issues independently of CloudFront."
  value       = aws_s3_bucket_website_configuration.legal_pages.website_endpoint
}

output "terms_url" {
  description = "Public HTTPS URL of the Terms of Use page (served via the default CloudFront domain — ready to click as soon as the distribution is deployed)."
  value       = "https://${aws_cloudfront_distribution.legal_pages.domain_name}/terms.html"
}

output "privacy_url" {
  description = "Public HTTPS URL of the Privacy Policy page (served via the default CloudFront domain — ready to click as soon as the distribution is deployed)."
  value       = "https://${aws_cloudfront_distribution.legal_pages.domain_name}/privacy.html"
}
