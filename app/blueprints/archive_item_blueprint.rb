class ArchiveItemBlueprint < Blueprinter::Base
  identifier :id

  field :public_link
  field :created_at, name: :archived_at

  # `normalized_attrs_for_views` also carries route paths and the record itself,
  # so only the fields that make sense outside the views are exposed
  field :platform do |archive_item|
    archive_item.archivable_item.normalized_attrs_for_views[:publishing_platform_shortname]
  end

  field :author do |archive_item|
    attributes = archive_item.archivable_item.normalized_attrs_for_views
    {
      display_name: attributes[:author_display_name],
      username: attributes[:author_username],
      profile_image_url: attributes[:author_profile_image_url],
    }
  end

  field :text do |archive_item|
    archive_item.archivable_item.normalized_attrs_for_views[:archive_item_caption]
  end

  field :published_at do |archive_item|
    archive_item.archivable_item.normalized_attrs_for_views[:published_at]
  end

  field :media do |archive_item|
    archive_item.archivable_item.combined_media.filter_map do |media|
      if media.try(:image_url)
        { type: "image", url: media.image_url }
      elsif media.try(:video_url)
        { type: "video", url: media.video_url }
      end
    end
  end
end
