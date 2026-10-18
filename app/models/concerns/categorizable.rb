module Categorizable
  extend ActiveSupport::Concern
  extend T::Sig

  @@archive_categories = YAML.load_file(Rails.root.join("lib", "assets", "categories.yml"))["categories"]

  # Name of the prompt managed in Langfuse. The prompt should accept
  # `categories` (comma-separated allowlist) and `content` (text to classify).
  # A text prompt compiles to a single user message; a chat prompt compiles
  # directly to a messages array for the Chat Completions API.
  # Each classification is also recorded as a Langfuse trace so the
  # observations stay linked to this prompt.
  CATEGORIZE_PROMPT_NAME = "categorize-archive-item"

  FALLBACK_CATEGORIZE_PROMPT = "Using this list of categories: #{@@archive_categories.join(",")}\ categorize the\
  following statment into the\
  categories, ordering them by most relevant. If there are no matches respond with no text at all. Return only the category names separated by commas and nothing else: "

  class_methods do
    def property_to_categorize(property = nil, &block)
      # A nifty trick to auto add acts_as_taggable_on(:categories) to the model
      instance_eval(&Proc.new { acts_as_taggable_on(:categories) })
      @@property = property # This is the property that will be used to categorize the model instance
      @@property_block = block # This is the block that the return will be used to categorize the model instance
    end
  end

  included do
    # Categorize the ArchiveItem based on the content of the ArchiveItem
    # This uses LLM_CLIENT (OpenAI-compatible) with the prompt fetched from
    # Langfuse, falling back to FALLBACK_CATEGORIZE_PROMPT when Langfuse is
    # unavailable. The call is recorded as a Langfuse trace with a generation
    # linked to the prompt version. Failures are logged and swallowed so record
    # creation is never blocked by the classifier.
    def categorize
      content = content_to_categorize
      return if content.nil? || content.empty?

      prompt = fetch_categorize_prompt_object
      messages = categorize_messages(content, prompt)
      return if messages.empty?

      trace = Langfuse.trace(CATEGORIZE_PROMPT_NAME, input: { content: content })
      generation = start_categorize_generation(trace, messages, prompt)

      response = LLM_CLIENT.chat.completions.create(
        model: Figaro.env.LLM_MODEL,
        messages: messages
      )

      response_text = extract_chat_content(response)
      finish_categorize_generation(trace, generation, response, response_text)
      return if response_text.nil? || response_text.strip.empty?

      new_categories = response_text.strip.split(",").map(&:strip)
      new_categories = new_categories[0..3] if new_categories.length > 4

      new_categories.each do |category|
        self.category_list.add(category) if @@archive_categories.include?(category)
      end
    rescue StandardError => e
      logger.warn "Categorization skipped: #{e.class}: #{e.message}"
      nil
    end

    def categorize!
      # First we remove all the categories on the ArchiveItem
      clear_categories!

      self.categorize
      self.save!
      self.reload
    end

    def clear_categories!
      self.categories.each { |category| self.category_list.remove(category.name) }
      self.save!
      self.reload
    end
  end

private

  def content_to_categorize
    return instance_eval(&@@property_block) if @@property.nil?
    self.send(@@property)
  end

  def fetch_categorize_prompt_object
    prompt = Langfuse.get_prompt(CATEGORIZE_PROMPT_NAME)
    logger.info "Langfuse prompt #{CATEGORIZE_PROMPT_NAME} unavailable, using fallback" if prompt.nil?
    prompt
  rescue StandardError => e
    logger.info "Langfuse prompt #{CATEGORIZE_PROMPT_NAME} unavailable, using fallback: #{e.class}: #{e.message}"
    nil
  end

  def categorize_messages(content, prompt)
    unless prompt.nil?
      compiled = compile_categorize_prompt(prompt, content)
      normalized = normalize_compiled_messages(compiled)
      return normalized unless normalized.empty?
    end

    fallback_categorize_messages(content)
  end

  def compile_categorize_prompt(prompt, content)
    prompt.compile(
      categories: @@archive_categories.join(", "),
      content: content,
      text: content
    )
  rescue StandardError => e
    logger.info "Langfuse prompt #{CATEGORIZE_PROMPT_NAME} compilation failed, using fallback: #{e.class}: #{e.message}"
    nil
  end

  def normalize_compiled_messages(compiled)
    case compiled
    when String
      return [] if compiled.strip.empty?
      [{ role: "user", content: compiled }]
    when Array
      compiled.filter_map do |message|
        role = message[:role] || message["role"]
        message_content = message[:content] || message["content"]
        next if role.nil? || message_content.nil?
        { role: role, content: message_content }
      end
    else
      []
    end
  end

  def fallback_categorize_messages(content)
    [
      { role: "system", content: FALLBACK_CATEGORIZE_PROMPT },
      { role: "user", content: content }
    ]
  end

  def start_categorize_generation(trace, messages, prompt)
    params = { name: CATEGORIZE_PROMPT_NAME, model: Figaro.env.LLM_MODEL, input: messages }
    params[:prompt] = prompt unless prompt.nil?
    trace.generation(**params)
  rescue StandardError
    nil
  end

  def finish_categorize_generation(trace, generation, response, output)
    return if generation.nil?
    params = { output: output }
    usage = extract_usage_details(response)
    params[:usage_details] = usage unless usage.nil? || usage.empty?
    generation.end(**params)
    trace.update(output: output)
  rescue StandardError
    nil
  end

  def extract_usage_details(response)
    usage = response.usage if response.respond_to?(:usage)
    usage = response["usage"] if usage.nil? && response.respond_to?(:[])

    if usage.respond_to?(:prompt_tokens)
      { input: usage.prompt_tokens, output: usage.completion_tokens, total: usage.total_tokens }.compact
    elsif usage.respond_to?(:[])
      {
        input: usage["prompt_tokens"] || usage[:prompt_tokens],
        output: usage["completion_tokens"] || usage[:completion_tokens],
        total: usage["total_tokens"] || usage[:total_tokens]
      }.compact
    end
  rescue StandardError
    nil
  end

  def extract_chat_content(response)
    choice = response.choices&.first
    message_content = choice&.message&.content
    return message_content if message_content.is_a?(String)

    # Hash-shaped responses (or test doubles exposing hashes)
    hash_choices = response["choices"] if response.respond_to?(:[])
    hash_message = hash_choices&.first&.dig("message", "content")
    return hash_message if hash_message.is_a?(String)

    nil
  rescue StandardError
    nil
  end
end
