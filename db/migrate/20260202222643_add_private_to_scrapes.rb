class AddPrivateToScrapes < ActiveRecord::Migration[7.2]
  def change
    add_column :scrapes, :private, :boolean
  end
end
