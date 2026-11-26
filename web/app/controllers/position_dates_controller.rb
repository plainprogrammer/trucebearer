# Setting the season and year of the open phase (spec 027 D1, D6).
class PositionDatesController < ApplicationController
  include PositionEditing

  def show; end

  def update
    edit!(:show) do
      season = choose!(field(:date, :season), SEASONS, "Choose a season.")
      year = field(:date, :year)
      raise Choose, YEAR_SENTENCE unless year&.match?(/\A\d{4}\z/) && YEARS.cover?(year.to_i)

      { "action" => "date_set", "to_season" => season, "to_year" => year.to_i }
    end
  end
end
