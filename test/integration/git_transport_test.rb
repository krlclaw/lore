require "test_helper"
require "tmpdir"
require "webrick"
require "rackup"
require "rackup/handler/webrick"

class GitTransportTest < ActionDispatch::IntegrationTest
  # Tests for git transport edge cases via HTTP (through Grack + GitAuthMiddleware)

  setup do
    @repo_root = Rails.application.config.lore_repo_root

    # Start a WEBrick server on a random port with the Rails app
    @port = rand(10_000..60_000)
    @server = WEBrick::HTTPServer.new(
      Port: @port,
      Logger: WEBrick::Log.new("/dev/null"),
      AccessLog: []
    )
    @server.mount("/", Rackup::Handler::WEBrick, Rails.application)
    @server_thread = Thread.new { @server.start }

    # Wait for server to be ready
    10.times do
      break if server_ready?
      sleep 0.1
    end
  end

  teardown do
    @server&.shutdown
    @server_thread&.join(5)
  end

  # --- 17.1: Anonymous clone via HTTP ---

  test "anonymous clone via HTTP works without auth" do
    user = User.create_with_pat(username: "anonclone-#{SecureRandom.hex(4)}")
    repo = Repo.create_with_bare_repo!(owner: user, name: "public-tool", description: "test")

    # Seed the repo with a commit so there's something to clone
    seed_commit(repo, "README.md", "# Public Tool\n", "Initial commit")

    Dir.mktmpdir("anon-clone-test") do |tmp|
      work = File.join(tmp, "public-tool")
      url = "http://localhost:#{@port}/git/#{user.username}/public-tool.git"

      result = system("git", "clone", url, work, out: File::NULL, err: File::NULL)
      assert result, "Anonymous clone via HTTP should succeed"

      # Verify content was cloned
      readme = File.read(File.join(work, "README.md"))
      assert_equal "# Public Tool\n", readme
    end
  end

  # --- 17.2: Authenticated push updates last_pushed_at ---

  test "authenticated push via HTTP updates last_pushed_at" do
    user = User.create_with_pat(username: "pushts-#{SecureRandom.hex(4)}")
    repo = Repo.create_with_bare_repo!(owner: user, name: "ts-repo", description: "test")

    assert_nil repo.last_pushed_at, "last_pushed_at should be nil before any push"

    # Seed a commit so the repo has a main branch
    seed_commit(repo, "README.md", "# TS Repo\n", "init")

    Dir.mktmpdir("push-ts-test") do |tmp|
      work = File.join(tmp, "ts-repo")
      url = "http://#{user.username}:#{user.plaintext_pat}@localhost:#{@port}/git/#{user.username}/ts-repo.git"

      system("git", "clone", url, work, out: File::NULL, err: File::NULL)

      # Make a new commit
      File.write(File.join(work, "CHANGELOG.md"), "## v1.0\n- initial\n")
      system("git", "-C", work, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=Test", "-c", "user.email=test@test.com",
        "commit", "-m", "Add changelog", out: File::NULL, err: File::NULL)

      result = system("git", "-C", work, "push", "origin", "main", out: File::NULL, err: File::NULL)
      assert result, "Authenticated push via HTTP should succeed"
    end

    repo.reload
    assert_not_nil repo.last_pushed_at, "last_pushed_at should be set after push"
    assert_in_delta Time.current, repo.last_pushed_at, 10, "last_pushed_at should be recent"
  end

  # --- 17.3: Clear error when pushing to non-existent repo ---

  test "push to non-existent repo returns error" do
    user = User.create_with_pat(username: "noexist-#{SecureRandom.hex(4)}")

    Dir.mktmpdir("noexist-test") do |tmp|
      work = File.join(tmp, "ghost-repo")
      FileUtils.mkdir_p(work)

      # Init a local repo and try to push to a non-existent remote
      system("git", "-C", work, "init", "-b", "main", out: File::NULL, err: File::NULL)
      File.write(File.join(work, "README.md"), "hello")
      system("git", "-C", work, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=Test", "-c", "user.email=test@test.com",
        "commit", "-m", "init", out: File::NULL, err: File::NULL)

      url = "http://#{user.username}:#{user.plaintext_pat}@localhost:#{@port}/git/#{user.username}/ghost-repo.git"
      system("git", "-C", work, "remote", "add", "origin", url, out: File::NULL, err: File::NULL)

      # Push should fail because the repo doesn't exist on the server
      result = system("git", "-C", work, "push", "origin", "main", out: File::NULL, err: File::NULL)
      assert_not result, "Push to non-existent repo should fail"
    end
  end

  # --- 17.4: Multiple commits show correct HEAD after push ---

  test "repos with multiple commits show correct HEAD after push" do
    user = User.create_with_pat(username: "multicommit-#{SecureRandom.hex(4)}")
    repo = Repo.create_with_bare_repo!(owner: user, name: "multi-repo", description: "test")

    # Seed initial commit
    seed_commit(repo, "README.md", "v1\n", "First commit")

    Dir.mktmpdir("multi-test") do |tmp|
      work = File.join(tmp, "multi-repo")
      url = "http://#{user.username}:#{user.plaintext_pat}@localhost:#{@port}/git/#{user.username}/multi-repo.git"

      system("git", "clone", url, work, out: File::NULL, err: File::NULL)

      # Make multiple commits
      File.write(File.join(work, "README.md"), "v2\n")
      system("git", "-C", work, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=Test", "-c", "user.email=test@test.com",
        "commit", "-m", "Second commit", out: File::NULL, err: File::NULL)

      File.write(File.join(work, "README.md"), "v3\n")
      system("git", "-C", work, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=Test", "-c", "user.email=test@test.com",
        "commit", "-m", "Third commit", out: File::NULL, err: File::NULL)

      result = system("git", "-C", work, "push", "origin", "main", out: File::NULL, err: File::NULL)
      assert result, "Push with multiple commits should succeed"
    end

    # Verify HEAD points to the latest commit
    log = `git -C #{repo.path} log --oneline 2>&1`.strip.lines
    assert_equal 3, log.length, "Should have 3 commits total"
    assert_includes log[0], "Third commit", "HEAD should point to the latest commit"

    # Verify content at HEAD
    content = `git -C #{repo.path} show HEAD:README.md 2>&1`.strip
    assert_equal "v3", content
  end

  private

  def server_ready?
    TCPSocket.new("localhost", @port).close
    true
  rescue Errno::ECONNREFUSED
    false
  end

  def seed_commit(repo, filename, content, message)
    Dir.mktmpdir("seed") do |tmp|
      work = File.join(tmp, "seed-work")
      system("git", "clone", repo.path, work, out: File::NULL, err: File::NULL)
      File.write(File.join(work, filename), content)
      system("git", "-C", work, "add", ".", out: File::NULL, err: File::NULL)
      system("git", "-C", work,
        "-c", "user.name=Seed", "-c", "user.email=seed@lore.sh",
        "commit", "-m", message, out: File::NULL, err: File::NULL)
      system("git", "-C", work, "push", "origin", "main", out: File::NULL, err: File::NULL)
    end
  end
end
