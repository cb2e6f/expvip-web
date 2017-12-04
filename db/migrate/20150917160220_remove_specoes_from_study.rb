class RemoveSpecoesFromStudy < ActiveRecord::Migration[4.2]
  def change
    remove_reference :studies, :species, index: true, foreign_key: true
  end
end
