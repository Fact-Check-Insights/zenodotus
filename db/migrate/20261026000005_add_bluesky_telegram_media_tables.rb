class AddBlueskyTelegramMediaTables < ActiveRecord::Migration[7.2]
  def change
    create_table :bluesky_images, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid "bluesky_post_id"
      t.jsonb "image_data"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["bluesky_post_id"], name: "index_bluesky_images_on_bluesky_post_id"
    end

    create_table :bluesky_videos, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid "bluesky_post_id"
      t.jsonb "video_data"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["bluesky_post_id"], name: "index_bluesky_videos_on_bluesky_post_id"
    end

    create_table :telegram_images, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid "telegram_post_id"
      t.jsonb "image_data"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["telegram_post_id"], name: "index_telegram_images_on_telegram_post_id"
    end

    create_table :telegram_videos, id: :uuid, default: -> { "gen_random_uuid()" }, force: :cascade do |t|
      t.uuid "telegram_post_id"
      t.jsonb "video_data"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.index ["telegram_post_id"], name: "index_telegram_videos_on_telegram_post_id"
    end
  end
end
