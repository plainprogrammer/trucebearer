Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Development and test only. See config.x.styleguide. Never linked from any page.
  constraints(->(_request) { Rails.configuration.x.styleguide }) do
    get "styleguide" => "styleguide#show"
  end

  # Games and joining (spec 021).
  get "games/new", to: "games#new", as: :new_game
  post "games", to: "games#create"

  scope "games/:public_id", constraints: { public_id: %r{[^/]+} }, format: false do
    get "/", to: "games#show", as: :game
    get "host", to: "hosts#show", as: :game_host
    get "host-link", to: "host_links#show", as: :game_host_link
    get "seat-link", to: "seat_links#show", as: :game_seat_link
    get "host/close", to: "closings#show", as: :game_close
    post "host/close", to: "closings#create"
    get "host/seats/:power/reissue", to: "reissues#show", as: :game_reissue
    post "host/seats/:power/reissue", to: "reissues#create"
    get "host/seats/:power/qr", to: "reissues#qr", as: :game_seat_qr

    # Phases (spec 022). A phase number is matched strictly in the controller, so a dot in it is a stranger, not a 404 page.
    get "phases/:number/orders", to: "seat_orders#show", as: :game_seat_orders, constraints: { number: %r{[^/]+} }
    put "phases/:number/orders", to: "seat_orders#update", constraints: { number: %r{[^/]+} }
    get "host/phases/:number/reveal", to: "reveals#show", as: :game_reveal, constraints: { number: %r{[^/]+} }
  end

  get "join", to: "joins#index", as: :join
  post "join", to: "joins#create"
  get "join/:code", to: "joins#show", as: :join_game, constraints: { code: %r{[^/]+} }, format: false
  post "join/:code/seat", to: "join_seats#create", as: :join_seat, constraints: { code: %r{[^/]+} }, format: false

  root "home#index"

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Defines the root path route ("/")
  # root "posts#index"
end
