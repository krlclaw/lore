require "test_helper"
require "tmpdir"

class DemoFlowTest < ActionDispatch::IntegrationTest
  setup do
    @repo_root = Rails.application.config.lore_repo_root
  end

  # --- Registration ---

  test "register a new user and receive a PAT" do
    post "/api/users", params: { username: "demo-agent" }, as: :json
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "demo-agent", body["user"]["username"]
    assert body["pat"].start_with?("lore_pat_"), "PAT should be returned"
  end

  # --- Repo creation ---

  test "create a repo and get clone_url back" do
    user = User.create_with_pat(username: "creator-#{SecureRandom.hex(4)}")
    post "/api/repos",
      params: { name: "my-tool", description: "A test tool", tags: %w[test cli] },
      headers: { "Authorization" => "Bearer #{user.plaintext_pat}" },
      as: :json
    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "my-tool", body["repo"]["name"]
    assert_includes body["repo"]["clone_url"], "/git/#{user.username}/my-tool.git"
    assert_equal "main", body["repo"]["default_branch"]

    # Bare repo exists on disk
    disk_path = File.join(@repo_root, user.username, "my-tool.git")
    assert File.directory?(disk_path), "Bare repo should exist on disk"
    head = File.read(File.join(disk_path, "HEAD")).strip
    assert_equal "ref: refs/heads/main", head
  end

  # --- Clone and push ---

  test "anonymous clone and authenticated push round-trip" do
    user = User.create_with_pat(username: "pusher-#{SecureRandom.hex(4)}")
    repo = Repo.create_with_bare_repo!(owner: user, name: "pushable", description: "test")

    Dir.mktmpdir("demo-test") do |tmp|
      work = File.join(tmp, "pushable")
      # Clone (anonymous)
      system("git", "clone", repo.path, work, exception: true, out: File::NULL, err: File::NULL)

      # Make a commit
      File.write(File.join(work, "README.md"), "# Pushable\nA test repo.\n")
      system("git", "-C", work, "add", ".", exception: true, out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=Test", "-c", "user.email=test@test.com",
        "commit", "-m", "Initial commit", exception: true, out: File::NULL, err: File::NULL)

      # Push (to bare repo directly for test — simulates authenticated push)
      system("git", "-C", work, "push", "origin", "main", exception: true, out: File::NULL, err: File::NULL)
    end

    # Verify the bare repo now has the commit
    log = `git -C #{repo.path} log --oneline 2>&1`.strip
    assert_includes log, "Initial commit"
  end

  # --- Non-fast-forward rejection ---

  test "non-fast-forward push to main is rejected" do
    user = User.create_with_pat(username: "nff-#{SecureRandom.hex(4)}")
    repo = Repo.create_with_bare_repo!(owner: user, name: "nff-repo", description: "test")

    Dir.mktmpdir("nff-test") do |tmp|
      work = File.join(tmp, "nff-repo")
      system("git", "clone", repo.path, work, exception: true, out: File::NULL, err: File::NULL)

      # First commit
      File.write(File.join(work, "README.md"), "version 1")
      system("git", "-C", work, "add", ".", exception: true, out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=Test", "-c", "user.email=test@test.com",
        "commit", "-m", "v1", exception: true, out: File::NULL, err: File::NULL)
      system("git", "-C", work, "push", "origin", "main", exception: true, out: File::NULL, err: File::NULL)

      # Second commit
      File.write(File.join(work, "README.md"), "version 2")
      system("git", "-C", work, "add", ".", exception: true, out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=Test", "-c", "user.email=test@test.com",
        "commit", "-m", "v2", exception: true, out: File::NULL, err: File::NULL)
      system("git", "-C", work, "push", "origin", "main", exception: true, out: File::NULL, err: File::NULL)

      # Reset to v1 and try force push — should fail
      system("git", "-C", work, "reset", "--hard", "HEAD~1", exception: true, out: File::NULL, err: File::NULL)
      result = system("git", "-C", work, "push", "--force", "origin", "main", out: File::NULL, err: File::NULL)
      assert_not result, "Force push should be rejected"
    end
  end

  # --- Star/unstar ---

  test "star and unstar a repo via API" do
    owner = User.create_with_pat(username: "starowner-#{SecureRandom.hex(4)}")
    starrer = User.create_with_pat(username: "starrer-#{SecureRandom.hex(4)}")
    repo = Repo.create_with_bare_repo!(owner: owner, name: "starrable", description: "test")

    # Star
    post "/api/repos/#{owner.username}/starrable/star",
      headers: { "Authorization" => "Bearer #{starrer.plaintext_pat}" },
      as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert body["starred"]
    assert_equal 1, body["repo"]["stars"]

    # Unstar
    delete "/api/repos/#{owner.username}/starrable/star",
      headers: { "Authorization" => "Bearer #{starrer.plaintext_pat}" },
      as: :json
    assert_response :success
    body = JSON.parse(response.body)
    assert_not body["starred"]
    assert_equal 0, body["repo"]["stars"]
  end

  # --- Repo detail ---

  test "fetch repo detail via API" do
    user = User.create_with_pat(username: "detail-#{SecureRandom.hex(4)}")
    Repo.create_with_bare_repo!(
      owner: user, name: "detail-repo",
      description: "A detailed repo", tags: %w[cli test]
    )

    get "/api/repos/#{user.username}/detail-repo", as: :json
    assert_response :success
    body = JSON.parse(response.body)["repo"]
    assert_equal "detail-repo", body["name"]
    assert_equal "A detailed repo", body["description"]
    assert_equal %w[cli test], body["tags"]
    assert_equal "main", body["default_branch"]
  end

  # --- Search validation ---

  test "search requires query parameter" do
    get "/api/repos/search", as: :json
    assert_response :bad_request
  end

  # --- User repo listing ---

  test "list repos for a user" do
    user = User.create_with_pat(username: "lister-#{SecureRandom.hex(4)}")
    Repo.create_with_bare_repo!(owner: user, name: "repo-one", description: "first")
    Repo.create_with_bare_repo!(owner: user, name: "repo-two", description: "second")

    get "/api/users/#{user.username}/repos", as: :json
    assert_response :success
    body = JSON.parse(response.body)
    names = body["repos"].map { |r| r["name"] }
    assert_includes names, "repo-one"
    assert_includes names, "repo-two"
  end

  # --- Auth enforcement ---

  test "repo creation requires authentication" do
    post "/api/repos", params: { name: "sneaky" }, as: :json
    assert_response :unauthorized
  end

  test "starring requires authentication" do
    owner = User.create_with_pat(username: "authowner-#{SecureRandom.hex(4)}")
    Repo.create_with_bare_repo!(owner: owner, name: "auth-repo", description: "test")
    post "/api/repos/#{owner.username}/auth-repo/star", as: :json
    assert_response :unauthorized
  end
end
