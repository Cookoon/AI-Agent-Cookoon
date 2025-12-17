class CreateAdditionalPrompts < ActiveRecord::Migration[7.1]
  def change
    create_table :additional_prompts do |t|
      t.text :content, null: false, default: ""
      t.references :updated_by, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
