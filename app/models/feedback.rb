# app/models/feedback.rb
class Feedback < ApplicationRecord
  enum feedback_type: { chefs: 0, lieux: 1 }

  validates :feedback_type, presence: true
  validates :prompt_text, presence: true
  validates :result_text, presence: true
  validates :rating, presence: true, inclusion: { in: 1..5 }
end
