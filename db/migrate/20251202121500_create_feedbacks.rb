# db/migrate/20251202121500_create_feedbacks.rb
class CreateFeedbacks < ActiveRecord::Migration[6.1]
  def change
    create_table :feedbacks do |t|
      t.integer :feedback_type, null: false
      t.text :prompt_text, null: false
      t.text :result_text, null: false
      t.integer :rating, null: false
      t.timestamps
    end
  end
end
