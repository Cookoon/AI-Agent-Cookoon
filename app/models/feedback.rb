# app/models/feedback.rb
class Feedback < ApplicationRecord
  validates :prompt_text, presence: true
  validates :result_text, presence: true
  validates :rating, presence: true, inclusion: { in: 1..5 }
end
