require "test_helper"

class Api::StarsTest < ActionDispatch::IntegrationTest
  setup do
    @user = User.create_with_pat(username: "staruser-#{SecureRandom.hex(4)}")
    @pat = @user.plaintext_pat
    @repo = Repo.create_with_bare_repo!(owner: @user, name: "star-target")
  end

  test "POST star creates a star" do
    post "/api/repos/#{@user.username}/star-target/star",
      headers: { "Authorization" => "Bearer #{@pat}" },
      as: :json
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal true, body["starred"]
    assert_equal 1, body["repo"]["stars"]
  end

  test "POST star is idempotent" do
    2.times do
      post "/api/repos/#{@user.username}/star-target/star",
        headers: { "Authorization" => "Bearer #{@pat}" },
        as: :json
      assert_response :ok
    end
    body = JSON.parse(response.body)
    assert_equal 1, body["repo"]["stars"]
  end

  test "DELETE unstar removes star" do
    Star.create!(user: @user, repo: @repo)

    delete "/api/repos/#{@user.username}/star-target/star",
      headers: { "Authorization" => "Bearer #{@pat}" },
      as: :json
    assert_response :ok
    body = JSON.parse(response.body)
    assert_equal false, body["starred"]
    assert_equal 0, body["repo"]["stars"]
  end

  test "star requires authentication" do
    post "/api/repos/#{@user.username}/star-target/star", as: :json
    assert_response :unauthorized
  end
end
