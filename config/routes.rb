Rails.application.routes.draw do
  devise_for :users

  get   "/settings", to: "settings#edit",   as: :settings
  patch "/settings", to: "settings#update"

  resources :highlights, only: [ :create, :update, :destroy ]
  resources :notes,      only: [ :new, :create, :update, :destroy, :show, :edit ]

  resources :note_shares, only: [ :create, :destroy ]
  resources :comments,    only: [ :create, :update, :destroy ]
  resources :upvotes,     only: [ :create, :destroy ]
  resources :flags,       only: [ :create ]

  post "/locale_banner/dismiss", to: "locale_banners#dismiss", as: :dismiss_locale_banner

  resources :groups do
    collection do
      post :join
    end
    member do
      delete :leave
    end
    resources :memberships, only: [ :create, :destroy ]
    get "bible/:translation/:book/:chapter",
        to: "groups/bible#show",
        as: :bible_chapter,
        constraints: { chapter: /\d+/ }
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "home#show"

  get "/bible", to: "bible/reader#entry", as: :bible_entry
  get "/bible/:translation/:book/:chapter",
      to: "bible/reader#show",
      as: :bible_chapter,
      constraints: { chapter: /\d+/ }

  get "/public/bible", to: redirect("/public/bible/kjv/gen/1")
  get "/public/bible/:translation/:book/:chapter",
      to: "public/bible#show",
      as: :public_bible_chapter,
      constraints: { chapter: /\d+/ }

  get "/search", to: "search#index", as: :search

  get  "/donate",            to: "donations#show",         as: :donate
  post "/donate/confirm",    to: "donations#create_report", as: :donate_confirm
  get  "/donate/thank_you",  to: "donations#thanks",       as: :donate_thank_you

  namespace :admin do
    resources :notes, only: [ :index, :show ] do
      member do
        patch :feature
        patch :unfeature
        patch :hide
        patch :unhide
      end
    end
    resources :flags, only: [ :index ] do
      member do
        patch :resolve
      end
    end
    resources :bitcoin_addresses, only: [ :index, :new, :create ]
  end

  # Branded error pages — wired up via config.exceptions_app in
  # production.rb. Rails dispatches to these paths when an exception
  # bubbles out of the app; ErrorsController#show renders the Echo-
  # branded view through application.html.erb so the error page gets
  # the full chrome (header + footer). via: :all so non-GET requests
  # that hit a 404 path also surface the branded view, not blank
  # routing-error JSON.
  # Preview/test route for branded error pages — bypasses Rack::Static
  # which serves public/{404,...}.html directly at the canonical paths.
  # Useful for design eyeball verification of the dynamic view.
  get "/__error/:code", to: "errors#show", as: :error_preview, constraints: { code: /\d+/ }

  match "/404", to: "errors#show", via: :all, defaults: { code: 404 }, as: :error_404
  match "/422", to: "errors#show", via: :all, defaults: { code: 422 }, as: :error_422
  match "/500", to: "errors#show", via: :all, defaults: { code: 500 }, as: :error_500
  match "/400", to: "errors#show", via: :all, defaults: { code: 400 }, as: :error_400
  match "/406-unsupported-browser", to: "errors#show", via: :all, defaults: { code: 406 }, as: :error_406
end
