# The host's reveal of a phase (spec 022 FR-7). Every URL carries the phase number, so a repeated or stale request can
# never reveal a different phase than the one the host was looking at (D7).
class RevealsController < ApplicationController
  before_action :require_host
  before_action :find_open_or_redirect

  def show
    @pending = @phase.pending
  end

  def create
    result = @phase.reveal!
    text = if result.status == :revealed
      "#{@phase.title} was revealed. It is now #{@game.current_phase.title}."
    else
      "That phase was already revealed."
    end
    flash[:banner] = { "kind" => "info", "text" => text }
    redirect_to game_host_path(@game.public_id), status: :see_other
  rescue RulesEngine::InvalidInput => error
    # The message can hold an order, so it is neither shown nor logged (spec 022 AC-4.10).
    Rails.logger.warn("reveal failed: #{error.class}")
    render :failed, status: :unprocessable_content
  end

  private

  # A later or unknown number is the stranger response. A revealed phase is not an error for the host (AC-4.11).
  def find_open_or_redirect
    @phase = find_phase(@game)
    return stranger!(@game) unless @phase && @phase.number <= @game.current_phase.number
    return if @phase.open?

    flash[:banner] = { "kind" => "info", "text" => "That phase was already revealed." }
    redirect_to game_host_path(@game.public_id), status: :see_other
  end
end
