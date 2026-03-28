require "test_helper"
require "tmpdir"

class FullDemoScenarioTest < ActionDispatch::IntegrationTest
  # Full end-to-end demo: register → search → clone → edit → push → verify

  setup do
    skip "OPENAI_API_KEY not set" unless ENV["OPENAI_API_KEY"].present?
  end

  test "complete demo flow: register, create repo, search, clone, edit, push" do
    # Step 1: Register a new user
    post "/api/users", params: { username: "demo-e2e-#{SecureRandom.hex(4)}" }, as: :json
    assert_response :created
    user_body = JSON.parse(response.body)
    pat = user_body["pat"]
    username = user_body["user"]["username"]
    assert pat.present?, "Should receive a PAT"

    # Step 2: Create a repo (publish)
    post "/api/repos",
      params: { name: "my-tool", description: "A demo tool for testing", tags: %w[test demo] },
      headers: { "Authorization" => "Bearer #{pat}" },
      as: :json
    assert_response :created
    repo_body = JSON.parse(response.body)["repo"]
    assert_equal "my-tool", repo_body["name"]

    # Step 3: Push initial content to the repo
    repo = Repo.find_by(name: "my-tool", owner: User.find_by(username: username))
    Dir.mktmpdir("demo-e2e") do |tmp|
      work = File.join(tmp, "my-tool")
      system("git", "clone", repo.path, work, exception: true, out: File::NULL, err: File::NULL)

      File.write(File.join(work, "README.md"), "# my-tool\n\nA demo tool.\n")
      system("git", "-C", work, "add", ".", exception: true, out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=#{username}/lore-agent",
        "-c", "user.email=#{username}@lore.agents",
        "commit", "-m", "Initial commit", exception: true, out: File::NULL, err: File::NULL)
      system("git", "-C", work, "push", "origin", "main", exception: true, out: File::NULL, err: File::NULL)
    end

    # Step 4: Search for the repo
    get "/api/repos/search", params: { q: "demo tool for testing" }, as: :json
    assert_response :success
    search_body = JSON.parse(response.body)
    found = search_body["repos"].any? { |r| r["name"] == "my-tool" }
    assert found, "Created repo should appear in search results"

    # Step 5: Star the repo
    post "/api/repos/#{username}/my-tool/star",
      headers: { "Authorization" => "Bearer #{pat}" },
      as: :json
    assert_response :success
    star_body = JSON.parse(response.body)
    assert star_body["starred"]

    # Step 6: Clone, edit, and push back
    Dir.mktmpdir("demo-e2e-edit") do |tmp|
      work = File.join(tmp, "my-tool")
      system("git", "clone", repo.path, work, exception: true, out: File::NULL, err: File::NULL)

      # Verify initial content
      readme = File.read(File.join(work, "README.md"))
      assert_includes readme, "A demo tool"

      # Make an improvement
      File.write(File.join(work, "README.md"), "# my-tool\n\nA demo tool.\n\n## Usage\n\nRun it.\n")
      system("git", "-C", work, "add", ".", exception: true, out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=#{username}/lore-agent",
        "-c", "user.email=#{username}@lore.agents",
        "commit", "-m", "Add usage section", exception: true, out: File::NULL, err: File::NULL)
      system("git", "-C", work, "push", "origin", "main", exception: true, out: File::NULL, err: File::NULL)
    end

    # Step 7: Verify the push updated the bare repo
    log = `git -C #{repo.path} log --oneline 2>&1`.strip
    assert_includes log, "Add usage section", "Push should have added the new commit"

    # Step 8: Verify repo detail shows correct data
    get "/api/repos/#{username}/my-tool", as: :json
    assert_response :success
    detail = JSON.parse(response.body)["repo"]
    assert_equal "my-tool", detail["name"]
    assert_equal 1, detail["stars"]
  end
end
