# Named to avoid clashing with the 2022 `CreateOrganizations` migration, which was later reverted.
class CreateUserOrganizations < ActiveRecord::Migration[7.2]
  def change
    create_table :organizations, id: :uuid do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_index :organizations, :name, unique: true

    add_reference :users, :organization, type: :uuid, foreign_key: true, null: true
  end
end
