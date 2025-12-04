class RemoveFeedbackTypeFromFeedbacks < ActiveRecord::Migration[7.1]
  def change
    remove_column :feedbacks, :feedback_type, :integer
  end
end
