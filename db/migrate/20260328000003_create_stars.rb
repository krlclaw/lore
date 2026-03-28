class CreateStars < ActiveRecord::Migration[8.1]
  def change
    create_table :stars do |t|
      t.references :user, null: false, foreign_key: true
      t.references :repo, null: false, foreign_key: true
      t.timestamps
    end

    add_index :stars, [:user_id, :repo_id], unique: true
  end
end
