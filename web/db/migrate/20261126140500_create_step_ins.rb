# One row each time the host confirms entering another seat (spec 026 D1). Append-only: the model refuses update and destroy.
class CreateStepIns < ActiveRecord::Migration[8.1]
  def change
    create_table :step_ins do |t|
      t.references :phase, null: false, foreign_key: true
      t.references :seat, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
  end
end
