require "test_helper"
require "open3"

class CoverageGapsTest < ActionDispatch::IntegrationTest
  # ── 18.1 CLI output format ──

  test "lore help displays all commands" do
    out, status = Open3.capture2("bash", "bin/lore", "help")
    assert status.success?, "lore help should succeed"
    %w[register search clone publish push star whoami].each do |cmd|
      assert_includes out, cmd, "help should list '#{cmd}'"
    end
  end

  test "lore search with no args prints usage to stderr" do
    out, err, status = Open3.capture3("bash", "bin/lore", "search")
    assert_not status.success?, "search with no args should fail"
    assert_match(/usage.*search/i, err + out)
  end

  test "lore clone with no args prints usage to stderr" do
    out, err, status = Open3.capture3("bash", "bin/lore", "clone")
    assert_not status.success?, "clone with no args should fail"
    assert_match(/usage.*clone/i, err + out)
  end

  test "lore register --help shows usage and examples" do
    out, status = Open3.capture2("bash", "bin/lore", "register", "--help")
    assert status.success?
    assert_match(/usage.*register/i, out)
    assert_includes out, "Examples"
  end

  test "lore search --help shows usage and examples" do
    out, status = Open3.capture2("bash", "bin/lore", "search", "--help")
    assert status.success?
    assert_match(/usage.*search/i, out)
    assert_includes out, "Examples"
  end

  test "lore unknown command prints error" do
    out, err, status = Open3.capture3("bash", "bin/lore", "boguscmd")
    assert_not status.success?
    assert_match(/unknown command/i, err + out)
  end

  # ── 18.2 Star counter cache consistency ──

  test "star counter cache stays consistent after star and unstar" do
    owner = User.create_with_pat(username: "cc-owner-#{SecureRandom.hex(4)}")
    user1 = User.create_with_pat(username: "cc-u1-#{SecureRandom.hex(4)}")
    user2 = User.create_with_pat(username: "cc-u2-#{SecureRandom.hex(4)}")
    repo = Repo.create_with_bare_repo!(owner: owner, name: "cc-repo", description: "counter cache test")

    assert_equal 0, repo.reload.stars_count

    # Star from user1
    post "/api/repos/#{owner.username}/cc-repo/star",
      headers: { "Authorization" => "Bearer #{user1.plaintext_pat}" }, as: :json
    assert_response :success
    assert_equal 1, repo.reload.stars_count

    # Star from user2
    post "/api/repos/#{owner.username}/cc-repo/star",
      headers: { "Authorization" => "Bearer #{user2.plaintext_pat}" }, as: :json
    assert_response :success
    assert_equal 2, repo.reload.stars_count

    # Duplicate star from user1 — should be idempotent
    post "/api/repos/#{owner.username}/cc-repo/star",
      headers: { "Authorization" => "Bearer #{user1.plaintext_pat}" }, as: :json
    assert_response :success
    assert_equal 2, repo.reload.stars_count, "duplicate star should not increment count"

    # Unstar from user1
    delete "/api/repos/#{owner.username}/cc-repo/star",
      headers: { "Authorization" => "Bearer #{user1.plaintext_pat}" }, as: :json
    assert_response :success
    assert_equal 1, repo.reload.stars_count

    # Unstar from user2
    delete "/api/repos/#{owner.username}/cc-repo/star",
      headers: { "Authorization" => "Bearer #{user2.plaintext_pat}" }, as: :json
    assert_response :success
    assert_equal 0, repo.reload.stars_count

    # Unstar again (already unstarred) — should stay at 0
    delete "/api/repos/#{owner.username}/cc-repo/star",
      headers: { "Authorization" => "Bearer #{user2.plaintext_pat}" }, as: :json
    assert_response :success
    assert_equal 0, repo.reload.stars_count, "re-unstar should not go negative"
  end

  # ── 18.3 Seed data creates expected repos ──

  test "seed data creates exactly the expected repos with correct star counts" do
    # Run seeds in test env
    Rails.application.load_seed

    expected_repos = {
      "lore-agent/slack-notify"        => 34,
      "lore-agent/send-email"          => 22,
      "lore-agent/github-issue-creator" => 14,
      "devtools/json-formatter"         => 11,
      "devtools/env-checker"            => 18,
      "devtools/fetch-url"              => 19,
      "agentkit/web-scraper"            => 15,
      "agentkit/file-search"            => 7,
      "agentkit/markdown-renderer"      => 8,
      "toolsmith/csv-parser"            => 10,
      "toolsmith/screenshot-tool"       => 9,
      "toolsmith/cron-scheduler"        => 6,
    }

    expected_repos.each do |full_name, expected_stars|
      owner_name, repo_name = full_name.split("/")
      owner = User.find_by(username: owner_name)
      assert owner, "User #{owner_name} should exist"

      repo = Repo.find_by(owner: owner, name: repo_name)
      assert repo, "Repo #{full_name} should exist"
      assert_equal expected_stars, repo.stars_count, "#{full_name} should have #{expected_stars} stars"
    end

    # Verify all 4 users exist
    %w[lore-agent devtools agentkit toolsmith].each do |username|
      assert User.find_by(username: username), "User #{username} should exist"
    end

    # Verify total seed repo count is at least 12
    seed_owners = %w[lore-agent devtools agentkit toolsmith].map { |u| User.find_by(username: u) }.compact
    seed_repo_count = Repo.where(owner: seed_owners).count
    assert seed_repo_count >= 12, "Should have at least 12 seed repos, got #{seed_repo_count}"
  end

  # ── 18.4 Rate limiting headers ──

  test "rate limiting headers are present on API responses" do
    get "/api/repos", as: :json
    assert_response :success

    assert response.headers["X-RateLimit-Limit"].present?,
      "X-RateLimit-Limit header should be present"
    assert response.headers["X-RateLimit-Remaining"].present?,
      "X-RateLimit-Remaining header should be present"

    assert_equal "60", response.headers["X-RateLimit-Limit"]
    remaining = response.headers["X-RateLimit-Remaining"].to_i
    assert remaining >= 0 && remaining <= 60, "Remaining should be between 0 and 60"
  end

  test "rate limiting headers present on authenticated requests" do
    user = User.create_with_pat(username: "rl-user-#{SecureRandom.hex(4)}")
    get "/api/repos",
      headers: { "Authorization" => "Bearer #{user.plaintext_pat}" }, as: :json
    assert_response :success

    assert response.headers["X-RateLimit-Limit"].present?
    assert response.headers["X-RateLimit-Remaining"].present?
  end
end
