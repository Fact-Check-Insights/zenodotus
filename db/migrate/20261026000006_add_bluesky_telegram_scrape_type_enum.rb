class AddBlueskyTelegramScrapeTypeEnum < ActiveRecord::Migration[7.2]
  def up
    execute <<-SQL
      ALTER TYPE scrape_type ADD VALUE IF NOT EXISTS 'bluesky';
    SQL
    execute <<-SQL
      ALTER TYPE scrape_type ADD VALUE IF NOT EXISTS 'telegram';
    SQL
  end

  def down
    # Postgres enums don't support removing values; no-op like the other
    # scrape_type additions.
  end
end
