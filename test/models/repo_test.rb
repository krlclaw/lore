require "test_helper"

class RepoTest < ActiveSupport::TestCase
  setup do
    @user = User.create_with_pat(username: "repouser-#{SecureRandom.hex(4)}")
  end

  test "create_with_bare_repo initializes a bare git repo" do
    repo = Repo.create_with_bare_repo!(owner: @user, name: "my-tool", description: "A tool", tags: ["test"])
    assert repo.persisted?
    assert File.directory?(repo.path)
    assert File.exist?(File.join(repo.path, "HEAD"))
    head = File.read(File.join(repo.path, "HEAD")).strip
    assert_equal "ref: refs/heads/main", head
  end

  test "bare repo denies non-fast-forward pushes" do
    repo = Repo.create_with_bare_repo!(owner: @user, name: "nff-test")
    config = `git -C #{repo.path} config receive.denyNonFastForwards`.strip
    assert_equal "true", config
  end

  test "repo name must be unique per owner" do
    Repo.create_with_bare_repo!(owner: @user, name: "dup-test")
    assert_raises(ActiveRecord::RecordInvalid) do
      Repo.create_with_bare_repo!(owner: @user, name: "dup-test")
    end
  end

  test "tags are stored as JSON and parsed back" do
    repo = Repo.create_with_bare_repo!(owner: @user, name: "tag-test", tags: ["slack", "notify"])
    repo.reload
    assert_equal ["slack", "notify"], repo.tags
  end

  test "clone_url and web_url" do
    repo = Repo.create_with_bare_repo!(owner: @user, name: "url-test")
    assert_match %r{/git/#{@user.username}/url-test\.git$}, repo.clone_url
    assert_match %r{/#{@user.username}/url-test$}, repo.web_url
  end
end
