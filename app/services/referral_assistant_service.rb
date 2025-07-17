require 'openai'

class ReferralAssistantService
  attr_reader :messages, :context, :step

  def initialize(user, session_data)
    @user = user
    @messages = session_data[:messages] || []
    @context = session_data[:context] || {}
    @step = session_data[:step] || "start"
    @client = OpenAIClient
  end

  def ask_stream(message, &stream_callback)
    @messages << { role: "user", content: message }
    loop_count = 0
    loop do
      full_response = ""
      streamed_message = {}
      finish_reason = nil
      @client.chat(
        parameters: {
          model: "gpt-4.1-mini",
          messages: full_conversation,
          stream: proc { |chunk|
            delta = chunk.dig("choices", 0, "delta")
            if delta&.key?("content") && delta["content"]
              full_response << delta["content"]
              # Call the streaming callback if provided
              stream_callback.call(chunk, full_response) if stream_callback
            end
            streamed_message.deep_merge!(delta) if delta
            finish_reason = chunk.dig("choices", 0, "finish_reason")
            handle_stream_chunk(chunk)
          }
        }
      )
      if finish_reason == "tool_calls"
        tool_call = streamed_message["tool_calls"][0]
        tool_call_id = tool_call["id"]
        function_name = tool_call.dig("function", "name")
        arguments = JSON.parse(tool_call.dig("function", "arguments"))
        tool_response = call_function(function_name, arguments)
        @messages << { role: "assistant", tool_calls: streamed_message["tool_calls"] }
        @messages << { role: "tool", tool_call_id: tool_call_id, name: function_name, content: tool_response.to_json }
      else
        bot_reply = full_response
        chunk_ids = @similar_chunks.pluck(:id)
        if support_response?(bot_reply, @similar_chunks)
          feedback = BotFeedback.create!(
            user_query: message,
            bot_response: bot_reply,
            chunk_ids: chunk_ids
          )
          @feedback = feedback
        end
        @messages << { role: "assistant", content: bot_reply, feedback_id: feedback&.id }
        return bot_reply
      end
      break if loop_count >= 5
      loop_count += 1
    end
  end

  private

  def full_conversation
    user_last_message = @messages.last[:content]
    @similar_chunks = search_similar_chunks(user_last_message)
    top_chunk_url = @similar_chunks.first.link
    context = @similar_chunks.map do |chunk|
      "- #{chunk.chunk}"
    end.join("\n\n")

    base = [
      {
        role: "system",
        content: "Note: For support-related queries, please use only the support prompt provided below and avoid including subscriber or referral flow data.\\n\\nMake sure the response is clearly formatted and user-friendly.\\n\\n- Also it is *very IMPORTANT to include images in response in the format of HTML tags if available*.\\n- For additional reference, include this link in the response so the user can view more details: #{top_chunk_url}\\n\\nContext for the response:\\n#{context}"
      }
    ]

    base + @messages.map do |msg|
      case msg[:role]
      when "bot"
        { role: "assistant", content: msg[:content] }
      when "user"
        { role: "user", content: msg[:content] }
      else
        msg
      end
    end
  end

  def handle_stream_chunk(chunk)
    delta = chunk.dig("choices", 0, "delta")
    return unless delta["content"]
    puts delta
  end

  def support_response?(response, similar_chunks)
    return false if similar_chunks.blank?
    interactive_patterns = [
      /please (select|choose|confirm|enter|provide|reply)/i,
      /which (option|one)/i,
      /pick a number/i,
      /say yes|type yes/i,
      /enter your/i,
      /choose from/i,
    ]

    return false if interactive_patterns.any? { |pattern| response.match?(pattern) }

    long_enough = response.length > 300
    long_enough
  end

  def embed_query(text)
    client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

    response = client.embeddings(
      parameters: {
        model: "text-embedding-ada-002",
        input: text
      }
    )

    response.dig("data", 0, "embedding")
  end

  def search_similar_chunks(query, limit = 3)
    embedding = embed_query(query)
    return [] unless embedding
    
    sql_expr = ActiveRecord::Base.send(:sanitize_sql_array, ["(embedding <=> ARRAY[?]::vector) + (0.1 * -quality_score) AS combined_score", embedding])
    chunks = PromptChunk.select("prompt_chunks.*, #{sql_expr}").order("combined_score ASC").limit(limit)
    # PromptChunk.nearest_neighbors(:embedding, embedding, distance: "cosine").limit(limit)
  end

  def reset
    @step = "start"
    @context = {}
  end
end
