require "net/http"
require "json"
require "uri"

# Thin client for the Python embedding service. Two endpoints:
#
#   embed_texts(["text", ...])  -> { "embeddings" => [[...], ...], "model_version" => "..." }
#   healthy?                     -> Boolean
#
# Any network / parse failure bubbles up as EmbeddingError so callers
# (SemanticSearchService, the batch rake task) can fall through
# cleanly.
class EmbeddingService
  BASE_URL     = ENV.fetch("EMBEDDING_SERVICE_URL", "http://127.0.0.1:8000")
  HEALTH_TIMEOUT = 5
  EMBED_TIMEOUT  = 30

  class EmbeddingError < StandardError; end

  def self.embed_texts(texts)
    uri = URI("#{BASE_URL}/embed")
    request = Net::HTTP::Post.new(uri)
    request["Content-Type"] = "application/json"
    request.body = { texts: Array(texts) }.to_json

    response = http(uri, timeout: EMBED_TIMEOUT).request(request)
    unless response.is_a?(Net::HTTPSuccess)
      raise EmbeddingError, "HTTP #{response.code}: #{response.body}"
    end

    JSON.parse(response.body)
  rescue JSON::ParserError, SocketError, Errno::ECONNREFUSED, Net::OpenTimeout, Net::ReadTimeout => e
    raise EmbeddingError, "Failed to reach embedding service: #{e.message}"
  end

  def self.healthy?
    uri = URI("#{BASE_URL}/health")
    response = http(uri, timeout: HEALTH_TIMEOUT).get(uri.request_uri)
    return false unless response.is_a?(Net::HTTPSuccess)
    JSON.parse(response.body)["status"] == "healthy"
  rescue StandardError
    false
  end

  def self.http(uri, timeout:)
    Net::HTTP.new(uri.host, uri.port).tap do |http|
      http.open_timeout = timeout
      http.read_timeout = timeout
      http.use_ssl = (uri.scheme == "https")
    end
  end
  private_class_method :http
end
