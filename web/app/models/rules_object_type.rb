# An ActiveRecord attribute type that stores one kind of rules object (a position, an order, a check
# result or an adjudication) as the JSON text of its hash form, and loads it back through RulesEngine
# (spec 019, FR-4). It names no gem class. An unknown format is not rescued or repaired: the
# InvalidInput from the loader reaches the caller (FR-5).
#
#   attribute :board, RulesObjectType.position
class RulesObjectType < ActiveRecord::Type::Value
  KINDS = %i[position order check_result adjudication].freeze
  KINDS.each { |kind| define_singleton_method(kind) { new(kind) } }

  attr_reader :kind

  def initialize(kind)
    raise ArgumentError, "kind must be one of #{KINDS.inspect}, got #{kind.inspect}" unless KINDS.include?(kind)

    super()
    @kind = kind
  end

  def type = :"rules_#{kind}"

  # A bad value fails at assignment, not on a later read (ActiveModel otherwise casts lazily).
  def assert_valid_value(value) = load_value(value)

  def cast(value) = load_value(value)

  def serialize(value)
    object = load_value(value)
    object && JSON.generate(object.to_h)
  end

  def deserialize(raw)
    return nil if raw.nil?

    load_value(JSON.parse(raw))
  end

  # The objects are immutable, so a save never re-reads an untouched column.
  def changed_in_place?(_raw_old_value, _new_value) = false

  def ==(other) = other.is_a?(RulesObjectType) && other.kind == kind
  alias_method :eql?, :==

  def hash = [ self.class, kind ].hash

  private

  def load_value(value) = RulesEngine.public_send(:"load_#{kind}", value)
end
