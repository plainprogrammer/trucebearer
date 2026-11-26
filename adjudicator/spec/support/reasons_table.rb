# frozen_string_literal: true

require_relative "board"

# The table of rejection reasons in docs/interface.md, read from the document itself
# so that the specs follow it and can't drift from it (AC-7.1, AC-7.3).
module ReasonsTable
  PATH = File.expand_path("../../docs/interface.md", __dir__)

  # row name => reasons in precedence order, for example "Move" => [:own_province, ...].
  # "Hold" has no reasons of its own and is absent.
  ROWS = File.read(PATH).lines
             .drop_while { |line| !line.start_with?("### Rejection reasons") }
             .take_while { |line| !line.start_with?("What each reason means") }
             .select { |line| line.start_with?("| ") && line.include?("`") }
             .to_h do |line|
               cells = line.split("|").map(&:strip).reject(&:empty?)
               [cells[0], cells[1].scan(/`:(\w+)`/).flatten.map(&:to_sym)]
             end.freeze

  def self.row(name) = ROWS.fetch(name)
  def self.all = ROWS.values.flatten.uniq
end

# Pins one pair of the precedence in a table row. `both` fails the first and the second
# condition and must report the first. `second_only` fails the second alone.
module PrecedenceHelpers
  def expect_precedence(row, first, second, position, both, second_only)
    list = ReasonsTable.row(row)
    expect(list).to include(first, second)
    expect(list.index(first)).to be < list.index(second)
    expect(Board.verdict(position, second_only)).to eq([second])
    expect(Board.verdict(position, both)).to eq([first])
  end
end

RSpec.configure { |config| config.include PrecedenceHelpers }
