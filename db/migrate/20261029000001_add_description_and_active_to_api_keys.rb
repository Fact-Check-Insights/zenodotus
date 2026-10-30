class AddDescriptionAndActiveToApiKeys < ActiveRecord::Migration[7.2]
  def up
    add_column :api_keys, :description, :string
    add_column :api_keys, :active, :boolean, default: true, null: false
    add_column :api_keys, :key_prefix, :string

    # Keys created from the console before this had no description
    execute "UPDATE api_keys SET description = 'Legacy key' WHERE description IS NULL"
    change_column_null :api_keys, :description, false

    remove_index :api_keys, :hashed_api_key
    add_index :api_keys, :hashed_api_key, unique: true
  end

  def down
    remove_index :api_keys, :hashed_api_key
    add_index :api_keys, :hashed_api_key

    remove_column :api_keys, :key_prefix
    remove_column :api_keys, :active
    remove_column :api_keys, :description
  end
end
