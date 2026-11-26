class CreatePhasesSavedOrdersAndSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :phases do |t|
      t.references :game, null: false, foreign_key: true, index: false # the unique indexes below lead with it
      t.integer :number, null: false
      t.text :position, null: false
      t.text :adjudication
      t.datetime :revealed_at
      t.timestamps
      t.index %i[game_id number], unique: true
      t.index :game_id, unique: true, where: "revealed_at IS NULL", name: "index_phases_on_game_id_while_open"
      t.check_constraint "(revealed_at IS NULL) = (adjudication IS NULL)", name: "phases_reveal_is_all_or_nothing"
    end

    create_table :saved_orders do |t|
      t.references :phase, null: false, foreign_key: true, index: false # the unique index below leads with it
      t.references :seat, null: false, foreign_key: true
      t.string :province, null: false
      t.text :content, null: false
      t.timestamps
      t.index %i[phase_id seat_id province], unique: true
    end

    create_table :submissions do |t|
      t.references :phase, null: false, foreign_key: true, index: false # the unique index below leads with it
      t.references :seat, null: false, foreign_key: true
      t.datetime :created_at, null: false
      t.index %i[phase_id seat_id], unique: true
    end
  end
end
