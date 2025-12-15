class AddCreatorToSavedProposals < ActiveRecord::Migration[7.1]
  def change
    add_column :saved_proposals, :creator, :string
  end
end
