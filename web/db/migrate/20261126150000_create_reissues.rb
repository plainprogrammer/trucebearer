# One row each time the host reissues a seat (spec 026 D10). Append-only: the model refuses update and destroy.
class CreateReissues < ActiveRecord::Migration[8.1]
  def change
    create_table :reissues do |t|
      t.references :phase, null: false, foreign_key: true
      t.references :seat, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
  end
end
