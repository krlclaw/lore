class CreateRepos < ActiveRecord::Migration[8.1]
  def change
    create_table :repos do |t|
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.string :name, null: false
      t.string :description, default: ""
      t.text :tags, default: "[]"          # JSON array of strings
      t.string :path, null: false           # absolute filesystem path to bare repo
      t.text :embedding                     # JSON array of floats, nullable
      t.datetime :last_pushed_at
      t.timestamps
    end

    add_index :repos, [:owner_id, :name], unique: true
  end
end
