class BotsController < ApplicationController
  include BotsHelper
  include ActionController::Live

  def show
  end

  def update_session
    session[:chat_session] ||= {}
    session[:chat_session][:messages] = params[:messages].map { |msg| msg.to_unsafe_h.deep_symbolize_keys }
    session[:chat_session][:context]  = params[:context]&.to_unsafe_h&.deep_symbolize_keys || {}
    session[:chat_session][:step]     = params[:step]
    head :ok
  end

  def transcribe_with_whisper(file_path)
    response = RestClient.post(
      "https://api.openai.com/v1/audio/transcriptions",
      { file: File.new(file_path), model: "whisper-1" },
      { Authorization: "Bearer #{ENV['OPENAI_API_KEY']}" }
    )
    JSON.parse(response.body)["text"]
  end

  def stream
    response.headers["Content-Type"] = "text/event-stream"
    response.headers["Cache-Control"] = "no-cache"
    response.headers['Last-Modified'] = Time.now.httpdate
    begin
      if params[:audio]
        file = params[:audio]
        temp_path = Rails.root.join("tmp", "audio_#{Time.now.to_i}.webm")
        File.open(temp_path, 'wb') { |f| f.write(file.read) }
        transcription = transcribe_with_whisper(temp_path)
        params[:message] = transcription
      end
      sse = SSE.new(response.stream, retry: 300, event: "chunk")
      service = ReferralAssistantService.new(nil, symbolized_session)
      sse.write({ status: "starting" }, event: "start")
      # Stream the response
      full_chunks = ""
      answer = service.ask_stream(params[:message]) do |chunk_data, full_response|
        content = chunk_data.dig("choices", 0, "delta", "content")
        if content && !content.empty?
          full_chunks += content
          chunk_html = render_to_string(partial: "bots/message", locals: { message: full_chunks, from: :bot})
          puts "Streaming chunk: #{chunk_html}" # Debug log
          sse.write({ content: chunk_html }, event: "chunk")
          # Manually flush the response buffer
          response.stream.write("\n")
        end
      end
      # Update session with final state
      session[:chat_session][:messages] = service.messages
      session[:chat_session][:context] = service.context
      session[:chat_session][:step] = service.step
      # Send completion event
      feedback_id = service.messages.last[:feedback_id]
      bot_html = render_to_string(partial: "bots/message", locals: { message: answer, from: :bot, feedback_id: feedback_id })
      sse.write({
        done: true,
        feedback_id: feedback_id,
        full_response: bot_html,
        session_data: {
          messages: service.messages,
          context: service.context,
          step: service.step
        }
      }, event: "done")
    rescue => e
      logger.error "Streaming error: #{e.message}"
      logger.error e.backtrace.join("\n")
      sse&.write({ error: "An error occurred: #{e.message}" }, event: "error")
    ensure
      sse&.close
    end
  end

  def feedback
    feedback = BotFeedback.find(params[:id])
    feedback.update!(liked: params[:liked]) if feedback 
  end

  def clear_chat
    @step = "start"
    @context = {}
    session[:chat_session] = {}
    redirect_to root_path
  end
end