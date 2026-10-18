module LlmMock
  # Categories returned for every prompt. Both must exist in lib/assets/categories.yml,
  # otherwise `Categorizable#categorize` discards them.
  CATEGORIES = ["Politics", "Health"].freeze

  FakeChatMessage = Struct.new(:content)
  FakeChatChoice = Struct.new(:message)
  FakeChatResponse = Struct.new(:choices)

  # No-op stand-ins so no trace is sent to Langfuse from tests.
  class FakeGeneration
    def end(*_, **_); end
  end

  class FakeTrace
    def generation(*_, **_)
      FakeGeneration.new
    end

    def update(*_, **_); end
  end

  # Stands in for the OpenAI-compatible LLM server so that categorization runs
  # without a model being available. Every archive item is created with the
  # same categories. Langfuse prompts and traces are disabled so the local
  # fallback prompt is used and nothing hits the network.
  def self.install!
    fake_response = FakeChatResponse.new([FakeChatChoice.new(FakeChatMessage.new(CATEGORIES.join(", ")))])

    completions = Object.new
    completions.define_singleton_method(:create) do |*_, **_|
      fake_response
    end

    chat = Object.new
    chat.define_singleton_method(:completions) do
      completions
    end

    LLM_CLIENT.define_singleton_method(:chat) do
      chat
    end

    Langfuse.define_singleton_method(:get_prompt) do |*_, **_|
      raise StandardError, "Langfuse disabled in tests"
    end

    Langfuse.define_singleton_method(:trace) do |*_, **_|
      FakeTrace.new
    end
  end
end
