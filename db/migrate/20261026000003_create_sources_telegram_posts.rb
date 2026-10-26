class CreateSourcesTelegramPosts < ActiveRecord::Migration[7.2]
  def change
    create_table :telegram_posts, id: :uuid do |t|
      t.text "text", null: false
      t.string "telegram_id", null: false
      t.datetime "posted_at", precision: nil, null: false
      t.string "language"
      t.text "url"
      t.uuid "author_id", null: false
      t.index ["author_id"], name: "index_telegram_posts_on_author_id"

      t.timestamps
    end
  end
end
