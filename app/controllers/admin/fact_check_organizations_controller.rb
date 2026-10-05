class Admin::FactCheckOrganizationsController < AdminController
  def index
    @fact_check_organizations = FactCheckOrganization.all.order(:name)
  end
end
