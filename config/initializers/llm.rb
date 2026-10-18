# frozen_string_literal: true

require "openai"
require "langfuse"

# OpenAI-compatible LLM client for categorization (works against OpenAI,
# LiteLLM, vLLM, Ollama with an OpenAI-compatible endpoint, etc.).
LLM_CLIENT = OpenAI::Client.new(
  api_key: Figaro.env.LLM_API_KEY,
  base_url: Figaro.env.LLM_ENDPOINT
)

Langfuse.configure do |config|
  config.public_key = Figaro.env.LANGFUSE_PUBLIC_KEY
  config.secret_key = Figaro.env.LANGFUSE_SECRET_KEY
  config.host = Figaro.env.LANGFUSE_HOST
  config.ingestion_mode = :otel # Langfuse v4 — legacy ingestion deja de aceptarse en Cloud
end
