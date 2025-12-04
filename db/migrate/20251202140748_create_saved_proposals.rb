class CreateSavedProposals < ActiveRecord::Migration[7.1]
  def change
    create_table :saved_proposals do |t|
      t.string :last_prompt
      t.text :proposal_text

      t.timestamps
    end
  end
end
