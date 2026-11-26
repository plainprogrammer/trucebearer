require "rails_helper"
require_relative "../support/rules_helpers"

# Spec 027 D7, AC-7.12: two edits at once, on two real database connections. The second is built from the first's stored position.
RSpec.describe Game, "#edit_position! under concurrent requests" do
  include RulesHelpers

  self.use_transactional_tests = false

  after { [ PositionEdit, Submission, SavedOrder, Phase, Seat, Game ].each(&:delete_all) }

  let(:game) { Game.start!(power: "england").game }

  def in_thread
    Thread.new do
      ActiveRecord::Base.connection_pool.with_connection { yield }
    rescue StandardError => error
      error
    end
  end

  it "builds the second edit from the position the first stored, and refuses a move of a unit the first removed" do
    entered = Queue.new
    release = Queue.new
    waited = Queue.new
    game
    allow(RulesEngine).to receive(:remove_unit).and_wrap_original do |original, *args, **kwargs|
      entered << true
      release.pop(timeout: 10)
      original.call(*args, **kwargs)
    end

    first = in_thread { Game.find(game.id).edit_position!(1, { "action" => "unit_removed", "province" => "par" }) }
    entered.pop(timeout: 10)
    second = in_thread do
      Game.connection.raw_connection.busy_handler do |count|
        waited << true if count.zero?
        sleep 0.001
        true
      end
      begin
        Game.find(game.id).edit_position!(1, { "action" => "unit_moved", "from" => "par", "to" => "bur", "to_coast" => nil })
      ensure
        current = Game.connection.raw_connection
        current.busy_handler_timeout = 5000 unless current.closed?
      end
    end
    waited.pop(timeout: 10) # the second request is blocked by the first's lock
    release << true

    expect(first.value).to be_a(PositionEdit)
    expect(second.value).to be_a(RulesEngine::EditRefused).and have_attributes(reason: :no_unit)
    expect(PositionEdit.count).to eq(1)
    expect(game.current_phase.reload.position.units.map { |u| u.location.province.to_s }).not_to include("par", "bur")
  end

  it "builds two edits one after the other, the second on the first's position" do
    a = in_thread { Game.find(game.id).edit_position!(1, { "action" => "unit_added", "power" => "france", "type" => "army", "province" => "bur", "coast" => nil }) }
    b = in_thread { Game.find(game.id).edit_position!(1, { "action" => "unit_added", "power" => "france", "type" => "army", "province" => "tyr", "coast" => nil }) }
    [ a.value, b.value ].each { |value| expect(value).to be_a(PositionEdit) }

    provinces = game.current_phase.reload.position.units.map { |u| u.location.province.to_s }
    expect(provinces).to include("bur", "tyr")
  end
end
