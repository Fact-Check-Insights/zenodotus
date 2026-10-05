require "csv"

class Admin::OrganizationsController < AdminController
  before_action :set_organization, only: [:show, :edit, :update, :destroy]

  def index
    @organizations = Organization.left_joins(:users)
                                 .select("organizations.*, COUNT(users.id) AS users_count")
                                 .group("organizations.id")
                                 .order(:name)
  end

  def show
    @report = OrganizationUsageReport.new(@organization, from: date_param(:from, default: 11.months.ago.to_date.beginning_of_month), to: date_param(:to, default: Date.current))

    respond_to do |format|
      format.html
      format.csv do
        send_data usage_csv(@report),
                  filename: "#{@organization.name.parameterize}-usage-#{@report.from}-#{@report.to}.csv",
                  type: "text/csv"
      end
    end
  end

  def new
    @organization = Organization.new
  end

  def create
    @organization = Organization.new(organization_params)

    if @organization.save
      redirect_to admin_organization_path(@organization), notice: "Organization created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @organization.update(organization_params)
      redirect_to admin_organization_path(@organization), notice: "Organization updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @organization.destroy
    redirect_to admin_organizations_path, notice: "Organization deleted. Its users have been kept, without an organization."
  end

private

  def set_organization
    @organization = Organization.find(params[:id])
  end

  def organization_params
    params.require(:organization).permit(:name)
  end

  def date_param(key, default:)
    Date.iso8601(params[key].to_s)
  rescue Date::Error
    default
  end

  # One row per user and month in the range
  def usage_csv(report)
    CSV.generate(encoding: "UTF-8") do |csv|
      csv << ["User", "Email", "Month", *OrganizationUsageReport::METRICS.values]
      report.by_user_and_month.each do |user, months|
        months.each do |month, counts|
          csv << [user.name, user.email, month.strftime("%Y-%m"), *counts.values]
        end
      end
    end
  end
end
