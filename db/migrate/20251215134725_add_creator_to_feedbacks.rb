class AddCreatorToFeedbacks < ActiveRecord::Migration[7.1]
  def change
    add_column :feedbacks, :creator, :string
  end
end
