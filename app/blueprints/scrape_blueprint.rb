class ScrapeBlueprint < Blueprinter::Base
  identifier :id

  fields :url, :private, :created_at, :updated_at
  field :scrape_type, name: :platform
  field :status

  association :archive_item, name: :result, blueprint: ArchiveItemBlueprint
end
