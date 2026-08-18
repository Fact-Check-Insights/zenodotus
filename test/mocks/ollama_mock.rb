module OllamaMock
  # Categories returned for every prompt. Both must exist in lib/assets/categories.yml,
  # otherwise `Categorizable#categorize` discards them.
  CATEGORIES = ["Politics", "Health"].freeze

  # Stands in for the Ollama server so that categorization runs without a model
  # being available. Every archive item is created with the same categories.
  def self.install!
    OLLAMA_CLIENT.define_singleton_method(:generate) do |_request, _options = {}|
      [{ "response" => CATEGORIES.join(", ") }]
    end
  end
end
