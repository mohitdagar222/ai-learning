# OpenAIClient = OpenAI::Client.new(api_key: ENV["OPENAI_API_KEY"])
OpenAIClient = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])