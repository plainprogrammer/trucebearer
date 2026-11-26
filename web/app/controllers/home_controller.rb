class HomeController < ApplicationController
  include ResumableGames

  def index
    no_store # the page varies with the cookies (spec 028 D7)
    @games = resumable_games
  end
end
