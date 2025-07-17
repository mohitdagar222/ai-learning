module BotsHelper

  def symbolized_session
    session[:chat_session] ||= {}.with_indifferent_access
    session[:chat_session].deep_symbolize_keys
  end

  def format_bold_markdown(text)
    # Convert **Key** to <strong>Key</strong>
    text.gsub(/\*\*(.+?)\*\*/) { "<strong>#{$1.strip}</strong>" }.html_safe
  end

  def format_message_body_old(message)
    message = markdown_images_to_html(message)
    lines = message.split("\n").map(&:strip)
    formatted_lines = lines.map do |line|
      if line.start_with?("-")
        # Turn bullet lines into <li> with bold keys
        "<li>#{format_bold_markdown(line[1..-1].strip)}</li>"
      else
        # Fallback: simple paragraph
        "<p>#{format_bold_markdown(line)}</p>"
      end
    end
    if formatted_lines.any? { |line| line.start_with?("<li>") }
      "<ul>#{formatted_lines.join}</ul>".html_safe
    else
      formatted_lines.join.html_safe
    end
  end

  def markdown_images_to_html(text)
    text.gsub(/!\[(.*?)\]\((.*?)\)/i) do
      alt_text = Regexp.last_match(1).strip
      src = Regexp.last_match(2).strip
      %(<img src="#{src}" alt="#{alt_text}" style="max-width:100%; height:auto; margin: 1em 0;" />)
    end.html_safe
  end

  def format_message_body(message)
    message = markdown_images_to_html(message)
    renderer = Redcarpet::Render::HTML.new(filter_html: false, hard_wrap: true)
    markdown = Redcarpet::Markdown.new(renderer, fenced_code_blocks: true, autolink: true, tables: true)

    markdown.render(message).html_safe
  end
end
