class Star < ApplicationRecord
  belongs_to :user
  belongs_to :repo, counter_cache: :stars_count

  validates :user_id, uniqueness: { scope: :repo_id }
end
