# What the four position-editor controllers share (spec 027 D1, D6, D8): the host check, the phase check, the headers, the "Choose ..."
# checks that run before any gem call, and the answer to one edit.
module PositionEditing
  extend ActiveSupport::Concern

  SEASONS = %w[spring fall].freeze
  YEARS = (1901..1999)
  YEAR_SENTENCE = "The year must be a whole number from 1901 to 1999.".freeze

  class Choose < StandardError; end # the message is the sentence the host sees

  included do
    before_action :require_host
    before_action :find_open_phase
    before_action :editor_headers
    helper_method :editor_path, :field
  end

  private

  # A revealed phase goes to the host page like the reveal does; a later, unknown or malformed number is the stranger response.
  def find_open_phase
    @phase = find_phase(@game)
    return stranger!(@game) unless @phase && @phase.number <= @game.current_phase.number
    return if @phase.open?

    revealed
  end

  def revealed
    flash[:banner] = { "kind" => "info", "text" => "That phase was already revealed." }
    redirect_to game_host_path(@game.public_id), status: :see_other
  end

  def editor_headers
    no_store
    response.set_header("Referrer-Policy", "no-referrer")
  end

  def editor_path = game_position_path(@game.public_id, @phase.number)

  # A string field of a nested form, or nil when it is missing, not a string, or the form is not a hash.
  def field(group, key)
    fields = params[group]
    value = fields.respond_to?(:key?) ? fields[key] : nil
    value.is_a?(String) ? value : nil
  end

  def choose!(value, allowed, sentence)
    raise Choose, sentence unless allowed.include?(value)

    value
  end

  def power!(value) = choose!(value, RulesEngine.powers.map { |power| power.id.to_s }, "Choose a power.")
  def province!(value) = choose!(value, RulesEngine.provinces.map(&:id), "Choose a province.")
  def coast!(value) = value.blank? ? nil : choose!(value, RulesEngine.coasts, "Choose a coast.")

  # Applies one edit and answers: a redirect with the banner, or the form again with the sentence (422). `form` is the template to
  # draw again. A vanished unit is the stranger response (spec 027 D7).
  def edit!(form)
    row = @game.edit_position!(@phase.number, yield)
    cleared = row.clears_orders? ? "Saved orders for this phase were cleared." : "Orders are kept."
    flash[:banner] = { "kind" => "info", "text" => "Saved. #{helpers.position_edit_text(row.detail)}. #{cleared}" }
    redirect_to editor_path, status: :see_other
  rescue Phase::Revealed
    revealed
  rescue Choose => error
    refuse(form, error.message)
  rescue RulesEngine::EditRefused => error
    return stranger!(@game) if error.reason == :no_unit

    refuse(form, helpers.refusal_text(error.reason, province: @refused_province, coast: @refused_coast))
  end

  def refuse(form, sentence)
    @refusal = sentence
    render form, status: :unprocessable_content
  end
end
