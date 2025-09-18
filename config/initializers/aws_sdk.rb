# typed: ignore

require "aws-sdk-s3"

# Configure global AWS S3 client to use a custom endpoint (e.g., GCP S3-compatible API)
Aws.config.update({
  region: ENV["AWS_REGION"],
  s3: {
    endpoint: ENV["S3_ENDPOINT"],
    force_path_style: true,
  },
})
