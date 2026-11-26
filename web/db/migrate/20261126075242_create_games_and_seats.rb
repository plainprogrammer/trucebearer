class CreateGamesAndSeats < ActiveRecord::Migration[8.1]
  def change
    create_table :games do |t|
      t.string :public_id, null: false
      t.string :host_token_digest, null: false
      t.string :join_code, null: false, limit: 6
      t.datetime :joining_closed_at
      t.timestamps
    end
    add_index :games, :public_id, unique: true
    add_index :games, :host_token_digest, unique: true
    # Unique only while joining is open: a closed game frees its code (spec FR-3).
    add_index :games, :join_code, unique: true, where: "joining_closed_at IS NULL", name: "index_games_on_join_code_while_open"

    create_table :seats do |t|
      t.references :game, null: false, foreign_key: true, index: false
      t.string :power, null: false
      t.string :token_digest, null: false
      t.timestamps
    end
    add_index :seats, [ :game_id, :power ], unique: true
    add_index :seats, :token_digest, unique: true
  end
end
