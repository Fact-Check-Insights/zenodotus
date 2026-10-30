# typed: ignore

# REST API to request scrapes and fetch their results, authenticated with an API key
# sent as `Authorization: Bearer <key>` (or the `api_key` param).
# Scrapes belong to the user that owns the key.
class MediaVault::Api::V1::ScrapesController < MediaVaultController
  SCRAPES_PER_PAGE = 25

  skip_before_action :authenticate_user_and_setup!, :must_be_media_vault_user
  # The parent class' `must_be_media_vault_user` has to run after authenticating, see `ApiController`
  before_action :authenticate_user_from_api_key!, :must_be_media_vault_user

  def index
    scrapes = Scrape.where(user: current_user).includes(:archive_item).order(created_at: :desc)

    if params[:status].present?
      unless Scrape::STATUSES.include?(params[:status].to_sym)
        render json: { error: "Invalid status, must be one of: #{Scrape::STATUSES.join(", ")}" }, status: :bad_request
        return
      end
      scrapes = scrapes.with_status(params[:status])
    end

    pagy, scrapes = pagy(scrapes, items: SCRAPES_PER_PAGE)

    render json: {
      scrapes: ScrapeBlueprint.render_as_hash(scrapes),
      pagination: { page: pagy.page, pages: pagy.pages, count: pagy.count, per_page: pagy.items },
    }
  end

  def show
    scrape = Scrape.where(user: current_user).find_by(id: params[:id])

    if scrape.nil?
      render json: { error: "Scrape not found" }, status: :not_found
      return
    end

    render json: ScrapeBlueprint.render(scrape)
  end

  def create
    # Note that this mirrors `ApiController#submit` and `ArchiveController#submit_url`
    url = params[:url]
    if url.blank?
      render json: { error: "No URL was provided" }, status: :bad_request
      return
    end

    object_model = ArchiveItem.model_for_url(url)
    if object_model.nil?
      render json: { error: "Unsupported URL" }, status: :unprocessable_entity
      return
    end

    is_private = params.key?(:private) ? ActiveModel::Type::Boolean.new.cast(params[:private]) : nil

    begin
      scrape = object_model.create_from_url(url, current_user, private: is_private, initiated_from: "api")
    rescue StandardError => e
      Honeybadger.notify(e)
      render json: { error: "An unexpected error has been raised submitting your request" }, status: :internal_server_error
      return
    end

    render json: ScrapeBlueprint.render(scrape), status: :accepted
  end
end
