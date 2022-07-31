terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }

  required_version = ">= 0.12.31"
}



resource "aws_s3_bucket" "mujju" {
  bucket = var.aws_s3_bucket
  acl    = "private"
  # Add specefic S3 policy in the s3-policy.json on the same directory
  # policy = file("s3-policy.json")

  versioning {
    enabled = false
  }

  website {
    index_document = "index.html"
    error_document = "error.html"
	
	# Add routing rules if required
    #routing_rules = <<EOF
    #                [{
    #                    "Condition": {
    #                        "KeyPrefixEquals": "docs/"
    #                    },
    #                    "Redirect": {
    #                        "ReplaceKeyPrefixWith": "documents/"
    #                    }
    #                }]
    #                EOF
  }

  tags = {
    Environment = "development"
    Name        = "my-tag"
  }

}

#Upload files of your static website
resource "aws_s3_object" "html" {
  for_each = fileset("./static/", "**/*.html")

  bucket = var.aws_s3_bucket
  key    = each.value
  source = "./static/${each.value}"
  etag   = filemd5("./static/${each.value}")
  content_type = "text/html"
}

resource "aws_s3_bucket_object" "svg" {
  for_each = fileset("./static/", "**/*.svg")

  bucket = var.aws_s3_bucket
  key    = each.value
  source = "./static/${each.value}"
  etag   = filemd5("./static/${each.value}")
  content_type = "image/svg+xml"
}

resource "aws_s3_bucket_object" "css" {
  for_each = fileset("./static/", "**/*.css")

  bucket = var.aws_s3_bucket
  key    = each.value
  source = "./static/${each.value}"
  etag   = filemd5("./static/${each.value}")
  content_type = "text/css"
}

resource "aws_s3_bucket_object" "js" {
  for_each = fileset("./static/", "**/*.js")

  bucket = var.aws_s3_bucket
  key    = each.value
  source = "./static/${each.value}"
  etag   = filemd5("./static/${each.value}")
  content_type = "application/javascript"
}


resource "aws_s3_bucket_object" "images" {
  for_each = fileset("./static/", "**/*.png")

  bucket = var.aws_s3_bucket
  key    = each.value
  source = "./static/${each.value}"
  etag   = filemd5("./static/${each.value}")
  content_type = "image/png"
}

resource "aws_s3_bucket_object" "json" {
  for_each = fileset("./static/", "**/*.json")

  bucket = var.aws_s3_bucket
  key    = each.value
  source = "./static/${each.value}"
  etag   = filemd5("./static/${each.value}")
  content_type = "application/json"
}
# Add more aws_s3_bucket_object for the type of files you want to upload
# The reason for having multiple aws_s3_bucket_object with file type is to make sure
# we add the correct content_type for the file in S3. Otherwise website load may have issues

locals {
  s3_origin_id = "s3-my-webapp.example.com"
}

resource "aws_cloudfront_origin_access_identity" "origin_access_identity" {
  comment = "s3-my-webapp"
}

resource "aws_cloudfront_distribution" "s3_distribution" {
  origin {
    domain_name = aws_s3_bucket.mujju.bucket_regional_domain_name
    origin_id   = local.s3_origin_id

    s3_origin_config {
      origin_access_identity = aws_cloudfront_origin_access_identity.origin_access_identity.cloudfront_access_identity_path
    }
  }

  enabled             = true
  is_ipv6_enabled     = true
  comment             = "my-cloudfront"
  default_root_object = "index.html"

  # Configure logging here if required 	
  #logging_config {
  #  include_cookies = false
  #  bucket          = "mylogs.s3.amazonaws.com"
  #  prefix          = "myprefix"
  #}

  # If you have domain configured use it here 
  #aliases = ["mywebsite.example.com", "s3-static-web-dev.example.com"]

  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # Cache behavior with precedence 0
  ordered_cache_behavior {
    path_pattern     = "/content/immutable/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD", "OPTIONS"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false
      headers      = ["Origin"]

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 86400
    max_ttl                = 31536000
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  # Cache behavior with precedence 1
  ordered_cache_behavior {
    path_pattern     = "/content/*"
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = local.s3_origin_id

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true
    viewer_protocol_policy = "redirect-to-https"
  }

  price_class = "PriceClass_200"

  restrictions {
    geo_restriction {
      restriction_type = "whitelist"
      locations        = ["US", "CA", "GB", "DE", "IN", "IR"]
    }
  }

  tags = {
    Environment = "development"
    Name        = "my-tag"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

data "aws_iam_policy_document" "s3_policy" {
  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.mujju.arn}/*"]

    principals {
      type        = "AWS"
      identifiers = [aws_cloudfront_origin_access_identity.origin_access_identity.iam_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "mybucket" {
  bucket = aws_s3_bucket.mujju.id
  policy = data.aws_iam_policy_document.s3_policy.json
}

resource "aws_s3_bucket_public_access_block" "mybucket" {
  bucket = aws_s3_bucket.mujju.id

  block_public_acls       = true
  block_public_policy     = true
  //ignore_public_acls      = true
  //restrict_public_buckets = true
}