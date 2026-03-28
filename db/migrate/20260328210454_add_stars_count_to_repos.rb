class AddStarsCountToRepos < ActiveRecord::Migration[8.1]
  def change
    add_column :repos, :stars_count, :integer, default: 0, null: false
  end
end
