class CreateSourcesBlueskyPosts < ActiveRecord::Migration[7.2]
  def change
    create_table :bluesky_posts, id: :uuid do |t|
      t.text "text", null: false
      t.string "bluesky_id", null: false
      t.datetime "posted_at", precision: nil, null: false
      t.string "language"
      t.integer "number_of_likes", null: false, default: 0
      t.integer "number_of_reposts", null: false, default: 0
      t.integer "number_of_replies", null: false, default: 0
      t.integer "number_of_quotes", null: false, default: 0
      t.text "url"
      t.uuid "author_id", null: false
      t.index ["author_id"], name: "index_bluesky_posts_on_author_id"

      t.timestamps
    end
  end
end
