require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "create_with_pat generates a user with valid PAT" do
    user = User.create_with_pat(username: "alice")
    assert user.persisted?
    assert user.plaintext_pat.start_with?("lore_pat_")
    assert user.authenticate_pat(user.plaintext_pat)
    refute user.authenticate_pat("wrong_token")
  end

  test "username must be lowercase with hyphens" do
    assert_raises(ActiveRecord::RecordInvalid) { User.create_with_pat(username: "UPPER") }
    assert_raises(ActiveRecord::RecordInvalid) { User.create_with_pat(username: "has spaces") }
    user = User.create_with_pat(username: "valid-name")
    assert user.persisted?
  end

  test "username must be unique" do
    User.create_with_pat(username: "unique")
    assert_raises(ActiveRecord::RecordInvalid) { User.create_with_pat(username: "unique") }
  end
end
