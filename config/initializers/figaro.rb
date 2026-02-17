# Skip strict Figaro requirements during asset precompilation
if ENV["SKIP_FIGARO_REQUIRE_KEYS"] == "1"
  return
end

# This is the salt value used to encrypt various things, you can generate one by running
# `rails secret`
Figaro.require_keys("KEY_ENCRYPTION_SALT")

# The URL and auth key for Hypatia
Figaro.require_keys("HYPATIA_SERVER_URL")
Figaro.require_keys("HYPATIA_AUTH_KEY")

# The host names for the apps, used for routing requests to the appropriate app
Figaro.require_keys("FACT_CHECK_INSIGHTS_HOST")
Figaro.require_keys("MEDIA_VAULT_HOST")
Figaro.require_keys("AUTH_BASE_HOST") # This is used by MFA as the site id

# Settings for sending email
Figaro.require_keys("MAIL_DOMAIN")
Figaro.require_keys("MAILGUN_API_KEY")

# reCAPTCHA Enterprise
Figaro.require_keys("RECAPTCHA_SITE_KEY")
Figaro.require_keys("RECAPTCHA_PROJECT_ID")

# Public links
Figaro.require_keys("PUBLIC_LINK_HOST")

# Figaro.require_keys("NEO4J_URL")
# Figaro.require_keys("NEO4J_USERNAME")
# Figaro.require_keys("NEO4J_PASSWORD")

if Figaro.env.USE_S3_DEV_TEST == "true" || Rails.env == "production"
  Figaro.require_keys("AWS_REGION")
  Figaro.require_keys("AWS_S3_BUCKET_NAME")
  Figaro.require_keys("AWS_ACCESS_KEY_ID")
  Figaro.require_keys("AWS_SECRET_ACCESS_KEY")
  Figaro.require_keys("S3_ENDPOINT")
end

if Rails.env == "production"
  Figaro.require_keys("MEMCACHIER_SERVERS")
  unless Figaro.env.ON_DOCKER == "yes"
    Figaro.require_keys("MEMCACHIER_USERNAME")
    Figaro.require_keys("MEMCACHIER_PASSWORD")
  end
end

if Figaro.env.HONEYBADGER_API_KEY.blank? == false
  Figaro.require_keys("HONEYBADGER_API_KEY_GOOGLE_CHECK_IN_ADDRESS")
  Figaro.require_keys("HONEYBADGER_API_KEY_CSV_JSON_GENERATION_ADDRESS")
end

Figaro.require_keys("OLLAMA_URL")
Figaro.require_keys("OLLAMA_PASSWORD")
Figaro.require_keys("FACTCHECK_TOOLS_API_KEY")

Figaro.require_keys("VIPS_WARNING") # This should always be set to "0" so that the logs are not spammed with ICPT warnings

Figaro.require_keys("CHROME_EXTENSION_ID")
