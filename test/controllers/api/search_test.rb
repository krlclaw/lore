require "test_helper"

class Api::SearchTest < ActionDispatch::IntegrationTest
  test "GET /api/repos/search returns 400 without query" do
    get "/api/repos/search", as: :json
    assert_response :bad_request
  end

  test "GET /api/repos/search returns 400 with blank query" do
    get "/api/repos/search", params: { q: "" }, as: :json
    assert_response :bad_request
  end

  test "GET /api/repos/search returns 503 without OPENAI_API_KEY" do
    original = ENV["OPENAI_API_KEY"]
    ENV.delete("OPENAI_API_KEY")
    get "/api/repos/search", params: { q: "slack" }, as: :json
    assert_response :service_unavailable
  ensure
    ENV["OPENAI_API_KEY"] = original if original
  end
end
