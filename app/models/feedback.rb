class Feedback < ApplicationRecord
  validates :prompt_text, presence: true
  validates :result_text, presence: true
  validates :rating, presence: true, inclusion: { in: 1..5 }
  validates :creator, presence: true
end
