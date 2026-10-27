class CreateSourcesBlueskyUsers < ActiveRecord::Migration[7.2]
  def change
    create_table :bluesky_users, id: :uuid do |t|
      t.string "did", null: false
      t.string "handle", null: false
      t.string "display_name", null: false
      t.integer "number_of_posts", null: false, default: 0
      t.integer "followers_count"
      t.integer "following_count"
      t.boolean "verified", null: false, default: false
      t.text "profile"
      t.string "url"
      t.text "profile_image_url"
      t.jsonb "profile_image_data"
      t.index ["did"], name: "index_bluesky_users_on_did", unique: true
      t.index ["handle"], name: "index_bluesky_users_on_handle"

      t.timestamps
    end
  end
end
