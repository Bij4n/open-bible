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
end
