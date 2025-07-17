require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'uri'
require 'json'
require 'openai'

namespace :support_scrapper do
  task start: :environment do
    base_url = "https://support.referralhero.com"

		puts "Embedding prompt constants..."
		begin
			# store_prompt_constant("organic_flow", PromptChunk::ORGANIC_FLOW_PROMPT)
			# store_prompt_constant("referral_flow", PromptChunk::REFERRAL_FLOW_PROMPT)
			# store_prompt_constant("new_sub_flow", PromptChunk::NEW_SUB_FLOW_PROMPT)
		rescue => e
			puts "Failed to store prompt constants: #{e.message}"
		end

    puts "Fetching sidebar..."
    doc = Nokogiri::HTML(URI.open(base_url))
    sidebar = doc.at_css("aside#table-of-contents ul")

    def collect_links_from_sidebar(ul)
      links = []
      ul.css("> li").each do |li|
        a = li.at("a")
        links << a['href'] if a
        nested = li.at("ul")
        links += collect_links_from_sidebar(nested) if nested
      end
      links
    end

    all_links = collect_links_from_sidebar(sidebar)
    puts "Found #{all_links.size} links"

    all_links.each_with_index do |path, i|
      full_url = URI.join(base_url, path).to_s
      puts "[#{i + 1}/#{all_links.size}] Scraping #{full_url}"

      begin
        html = URI.open(full_url).read
        page = Nokogiri::HTML(html)
        main_body = page.at('main')
				
				# Convert image tags to markdown
				main_body.css('img').each do |img|
					src = img['src']
					next unless src
					full_src = URI.join(full_url, src).to_s
				 	img.replace("[Image: #{full_src}]")
				end
				content = main_body.text.strip.gsub(/\s+/, ' ')

        next unless content.present?
				# Remove old chunks for this URL
        PromptChunk.where(link: full_url).delete_all

        # doc = PromptChunk.find_or_initialize_by(link: full_url)
        # doc.chunk = content
        # vector = generate_embedding(content)
        # doc.embedding = vector if vector
        # doc.save!


				split_into_chunks(content).each_with_index do |chunk, j|
          embedding = generate_embedding(chunk)
          if embedding.nil?
            puts "❌ Skipping chunk #{j + 1} for #{full_url} due to embedding failure."
            next
          end

          PromptChunk.create!(
            link: full_url,
            chunk: chunk,
            embedding: embedding
          )
          puts "✅ Saved chunk #{j + 1}"
        end
      rescue => e
        puts "Failed to fetch #{full_url}: #{e.message}"
      end
    end

    puts "✅ Scraping completed."
  end
end

def generate_embedding(text)
  client = OpenAI::Client.new(access_token: ENV['OPENAI_API_KEY'])

  response = client.embeddings(
    parameters: {
      model: "text-embedding-ada-002",
      input: text
    }
  )

  if response.dig("data", 0, "embedding")
		response["data"][0]["embedding"]
  else
    puts "Embedding API failed: #{response}"
    nil
  end
end

def split_into_chunks(text, max_chars = 4000, overlap = 200)
  chunks = []
  start = 0

  while start < text.length
    finish = [start + max_chars, text.length].min
    chunk = text[start...finish]
    chunks << chunk.strip
    start += max_chars - overlap
  end

  chunks
end

def store_prompt_constant(name, content)
	PromptChunk.where(link: "internal://#{name}").destroy_all
	embedding = generate_embedding(content)
	PromptChunk.create!(
		link: "internal://#{name}",
		chunk: content,
		embedding: embedding
	)
	puts "✅ Embedded internal prompt: #{name}"
end
