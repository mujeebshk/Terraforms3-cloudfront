# Print the files processed so far
output "fileset-results" {
  value = fileset("/Users/shaikmujeeb273gmail.com/Documents/Projects/Terraform practices/static/", "**/*")
}

# to get the Cloud front URL if doamin/alias is not configured
output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.s3_distribution.domain_name
}
