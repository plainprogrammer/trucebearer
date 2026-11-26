require "rails_helper"
require_relative "../support/rules_helpers"

# Positions, orders, check results and adjudication results stored as JSON and loaded back (spec 019,
# Story 4). The table and its model exist only while these examples run: nothing is added to db/.
RSpec.describe "Stored gem objects" do
  include RulesHelpers

  before(:all) do
    ApplicationRecord.connection.create_table(:rules_storage_rows, force: true) do |t|
      t.string :label
      t.json :board
      t.json :move
      t.json :verdict
      t.json :result
    end
    @model = Class.new(ApplicationRecord) do
      self.table_name = "rules_storage_rows"
      def self.name = "RulesStorageRow"
      attribute :board, RulesObjectType.position
      attribute :move, RulesObjectType.order
      attribute :verdict, RulesObjectType.check_result
      attribute :result, RulesObjectType.adjudication
    end
  end

  # Fails the run if the table survives, which is what AC-4.10 asks for.
  after(:all) do
    ApplicationRecord.connection.drop_table(:rules_storage_rows, if_exists: true)
    raise "rules_storage_rows was not dropped" if ApplicationRecord.connection.table_exists?(:rules_storage_rows)
  end

  let(:model) { @model }
  let(:start) { RulesEngine.starting_position }
  let(:order_hashes) do
    [ { "type" => "hold", "power" => "england", "at" => "lon" },
      { "type" => "move", "power" => "france", "at" => "mao", "destination" => { "province" => "spa", "coast" => "nc" } },
      { "type" => "move_via_convoy", "power" => "england", "at" => "lon", "to" => "wal" },
      { "type" => "support_hold", "power" => "germany", "at" => "mun", "target" => "ber" },
      { "type" => "support_move", "power" => "france", "at" => "por", "from" => "mao", "to" => "spa" },
      { "type" => "convoy", "power" => "england", "at" => "nth", "from" => "lon", "to" => "nwy" } ]
      .map { |h| { "format" => 1 }.merge(h) }
  end

  def raw(record, column) = model.connection.select_value("SELECT #{column} FROM rules_storage_rows WHERE id = #{record.id}")

  def insert_raw(column, text)
    model.connection.execute("INSERT INTO rules_storage_rows (#{column}) VALUES (#{model.connection.quote(text)})")
    model.order(:id).last
  end

  it "has the spec-only table during its examples (AC-4.10)" do
    expect(ApplicationRecord.connection.table_exists?(:rules_storage_rows)).to be(true)
  end

  it "stores and reloads a position, including a split-coast fleet (AC-4.1)" do
    split = rules_position(units: [ [ :france, :fleet, :spa, :nc ], [ :russia, :fleet, :stp, :sc ] ], ownership: { spa: :france })
    [ start, split ].each do |position|
      record = model.create!(board: position)
      expect(model.find(record.id).board).to eq(position)
    end
  end

  it "stores and reloads each of the six order types with its class (AC-4.2)" do
    order_hashes.each do |hash|
      order = RulesEngine.load_order(hash)
      loaded = model.find(model.create!(move: order).id).move
      expect(loaded).to eq(order)
      expect(loaded.class).to eq(order.class)
    end
  end

  it "stores and reloads a check result, legal and not (AC-4.3)" do
    [ rules_order(:hold, :england, :lon), rules_order(:hold, :france, :lon) ].each do |order|
      verdict = RulesEngine.check(start, order)
      expect(model.find(model.create!(verdict: verdict).id).verdict).to eq(verdict)
    end
  end

  it "stores and reloads an adjudication result (AC-4.4)" do
    adj = RulesEngine.adjudicate(start, [ move(:england, :lon, :nth), move(:russia, :war, :gal), move(:austria, :vie, :gal) ])
    expect(model.find(model.create!(result: adj).id).result).to eq(adj)
  end

  it "stores the JSON text of the hash form, with its format (AC-4.5)" do
    record = model.create!(board: start)
    text = raw(record, "board")
    expect(JSON.parse(text)).to eq(start.to_h)
    expect(text).to include('"format":1')
  end

  it "stores nil as SQL NULL and loads it as nil (AC-4.6)" do
    record = model.create!(board: nil)
    expect(raw(record, "board")).to be_nil
    expect(model.find(record.id).board).to be_nil
  end

  it "accepts a string-keyed hash in place of an object (AC-4.7)" do
    record = model.create!(board: start.to_h)
    expect(model.find(record.id).board).to eq(start)
  end

  it "raises InvalidInput at assignment for anything else (AC-4.7a)" do
    record = model.new
    [ 5, "board", [], start.to_h.transform_keys(&:to_sym), rules_order(:hold, :england, :lon) ].each do |bad|
      expect { record.board = bad }.to raise_error(RulesEngine::InvalidInput)
      expect { model.new(board: bad) }.to raise_error(RulesEngine::InvalidInput)
    end
  end

  it "raises InvalidInput, naming the value, when a stored row has an unknown format (AC-4.8, AC-4.9)" do
    record = insert_raw("board", JSON.generate(start.to_h.merge("format" => 2)))
    expect { model.find(record.id).board }.to raise_error(RulesEngine::InvalidInput, /format 2/)
  end

  it "does not hide or repair a stored row that is not JSON, not an object, or JSON null (AC-4.9a)" do
    expect { model.find(insert_raw("board", "not json").id).board }.to raise_error(JSON::ParserError)
    expect { model.find(insert_raw("board", "[]").id).board }.to raise_error(RulesEngine::InvalidInput)
    expect(model.find(insert_raw("board", "null").id).board).to be_nil
  end

  it "leaves an untouched bad column alone when the record is saved (AC-4.9b)" do
    bad = JSON.generate(start.to_h.merge("format" => 2))
    record = model.find(insert_raw("board", bad).id)
    expect { record.update!(label: "kept") }.not_to raise_error
    expect(raw(record, "board")).to eq(bad)
    expect(raw(record, "label")).to eq("kept")
  end
end
