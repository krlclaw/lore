require "net/http"
require "json"

module Lore
  class EmbeddingService
    MODEL = "text-embedding-3-small"
    ENDPOINT = URI("https://api.openai.com/v1/embeddings")

    class << self
      def embed(text)
        api_key = ENV["OPENAI_API_KEY"]
        raise "OPENAI_API_KEY not set" if api_key.blank?

        request = Net::HTTP::Post.new(ENDPOINT)
        request["Authorization"] = "Bearer #{api_key}"
        request["Content-Type"] = "application/json"
        request.body = { model: MODEL, input: text }.to_json

        response = Net::HTTP.start(ENDPOINT.host, ENDPOINT.port, use_ssl: true) do |http|
          http.request(request)
        end

        unless response.is_a?(Net::HTTPSuccess)
          raise "OpenAI embedding API error: #{response.code} #{response.body}"
        end

        data = JSON.parse(response.body)
        data["data"][0]["embedding"]
      end

      def cosine_similarity(a, b)
        return 0.0 if a.nil? || b.nil? || a.empty? || b.empty?

        dot = 0.0
        norm_a = 0.0
        norm_b = 0.0
        a.each_with_index do |val, i|
          bval = b[i].to_f
          dot += val * bval
          norm_a += val * val
          norm_b += bval * bval
        end

        denom = Math.sqrt(norm_a) * Math.sqrt(norm_b)
        denom.zero? ? 0.0 : dot / denom
      end
    end
  end
end
