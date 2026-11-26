class CreatePositionEdits < ActiveRecord::Migration[8.1]
  def change
    create_table :position_edits do |t|
      t.references :phase, null: false, foreign_key: true
      t.json :detail, null: false
      t.datetime :created_at, null: false
    end
  end
end
