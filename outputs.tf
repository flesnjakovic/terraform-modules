output "s3_bucket_arn" {
  description = "The ARN of the bucket."
  value       = aws_s3_bucket.bucket.arn
}

output "s3_bucket_id" {
  description = "The name of the bucket."
  value       = aws_s3_bucket.bucket.id
}

output "s3_bucket_region" {
  description = "The AWS region this bucket resides in."
  value       = aws_s3_bucket.bucket.region
}
