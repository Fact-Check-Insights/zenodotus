module RemoteUrlMock
  class UrlNotMockedError < StandardError; end

  MOCK_MEDIA_DIRECTORY = File.join(File.dirname(__FILE__), "media")
  MOCK_DATA_DIRECTORY = File.join(File.dirname(__FILE__), "data")

  # The URLs searched by tests, mapped either to a local stand-in file or to the
  # failure Shrine raises when it cannot download one. Add an entry here rather than
  # letting a test reach the real host.
  RESPONSES = {
    "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp4" =>
      File.join(MOCK_MEDIA_DIRECTORY, "3875fecb-bba8-498d-b9c0-f76fc3833a3a.mp4"),
    "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_30mb.mp4" => :too_large,
    "https://sample-videos.com/video321/mp4/720/big_buck_bunny_720p_1mb.mp" => :not_found,
    # Downloads fine, but isn't media, so the app rejects it.
    "https://sample-videos.com/xls/Sample-Spreadsheet-1000-rows.xls" =>
      File.join(MOCK_DATA_DIRECTORY, "instagram_posts.json"),
    "https://sample-videos.com" => File.join(MOCK_DATA_DIRECTORY, "instagram_posts.json")
  }.freeze

  # Replaces Shrine's remote downloader so no test fetches a URL over the network.
  def self.install!
    Shrine.define_singleton_method(:remote_url) do |url, **_options|
      RemoteUrlMock.download(url)
    end
  end

  def self.download(url)
    response = RESPONSES.fetch(url) do
      raise UrlNotMockedError, "#{url} was not caught by the remote URL mock. Please add it to RemoteUrlMock::RESPONSES."
    end

    case response
    when :too_large
      raise Shrine::Plugins::RemoteUrl::DownloadError, "remote file too large"
    when :not_found
      raise Shrine::Plugins::RemoteUrl::DownloadError, "remote file not found"
    else
      File.open(response, binmode: true)
    end
  end
end
