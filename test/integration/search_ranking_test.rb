require "test_helper"

class SearchRankingTest < ActionDispatch::IntegrationTest
  # These tests require OPENAI_API_KEY. They validate the core demo promise.

  setup do
    skip "OPENAI_API_KEY not set" unless ENV["OPENAI_API_KEY"].present?

    # Create test repos with embeddings
    @owner = User.create_with_pat(username: "ranker-#{SecureRandom.hex(4)}")
    @slack = create_repo_with_embedding("slack-notify",
      "Send Slack notifications via incoming webhooks. Simple, reliable, agent-friendly.",
      %w[slack notification webhook messaging])
    @email = create_repo_with_embedding("send-email",
      "Send emails via SMTP with subject, body, and attachments.",
      %w[email smtp notification])
    @csv = create_repo_with_embedding("csv-parser",
      "Parse CSV files and output as JSON, TSV, or filtered rows.",
      %w[csv parsing data cli])
  end

  test "search for 'send slack notification' returns slack-notify first" do
    get "/api/repos/search", params: { q: "send slack notification" }, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    results = body["repos"]
    assert results.any?, "Should return results"
    assert_equal "slack-notify", results.first["name"],
      "slack-notify should be the top result, got: #{results.map { |r| r['name'] }.inspect}"
  end

  test "search for 'send email' returns send-email first" do
    get "/api/repos/search", params: { q: "send email" }, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    results = body["repos"]
    assert_equal "send-email", results.first["name"],
      "send-email should rank first for 'send email', got: #{results.map { |r| r['name'] }.inspect}"
  end

  test "search results are sorted by descending similarity" do
    get "/api/repos/search", params: { q: "send slack notification" }, as: :json
    assert_response :success

    body = JSON.parse(response.body)
    scores = body["repos"].map { |r| r["similarity_score"] }
    assert_equal scores, scores.sort.reverse, "Results should be sorted by descending similarity"
  end

  private

  def create_repo_with_embedding(name, description, tags)
    repo = Repo.create_with_bare_repo!(
      owner: @owner, name: name, description: description, tags: tags
    )
    # generate_embedding! is called in create_with_bare_repo! but may fail silently
    repo.reload
    unless repo.embedding.present?
      repo.generate_embedding!
      repo.reload
    end
    repo
  end
end
