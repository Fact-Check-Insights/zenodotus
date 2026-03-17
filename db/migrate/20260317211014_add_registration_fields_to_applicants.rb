class AddRegistrationFieldsToApplicants < ActiveRecord::Migration[7.2]
  def change
    add_column :applicants, :organization_type, :string
    add_column :applicants, :organization_type_other, :string
    add_column :applicants, :primary_role_other, :string
    add_column :applicants, :commercial_use, :boolean
  end
end
