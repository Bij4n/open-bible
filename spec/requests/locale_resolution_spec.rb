require "rails_helper"

# Verifies the precedence documented in ApplicationController#resolved_locale:
#   current_user.ui_locale  >  session[:locale]  >  params[:locale]  >  default.
# We use home#show as the probe; the welcome string differs between
# English and Spanish so we can read the locale out of the response body.
RSpec.describe "Locale resolution", type: :request do
  let(:english_greeting) { "Welcome to Open Bible" }
  let(:spanish_greeting) { "Bienvenido a Open Bible" }

  it "defaults to English" do
    get "/"
    expect(response.body).to include(english_greeting)
  end

  it "honours params[:locale] for an anonymous visitor" do
    get "/?locale=es"
    expect(response.body).to include(spanish_greeting)
  end

  it "persists an anonymous visitor's params[:locale] into the session" do
    get "/?locale=es"
    get "/"
    expect(response.body).to include(spanish_greeting)
  end

  it "lets params[:locale] override a stale session" do
    get "/?locale=es"
    get "/?locale=en"
    expect(response.body).to include(english_greeting)
  end

  it "ignores an unknown params[:locale]" do
    get "/?locale=fr"
    expect(response.body).to include(english_greeting)
  end

  # Bug repro attempt: user reports that starting in English, clicking
  # Sign in → Sign up → Sign in flips the UI to Spanish. If the request
  # sequence alone reproduces it, something in the app is writing
  # session[:locale] = "es" where it shouldn't. If the sequence stays
  # English, the bug is triggered by an intermediate click (e.g., an
  # accidental locale-pill tap).
  it "stays English across an unauthenticated sign_in -> sign_up -> sign_in flow" do
    get "/users/sign_in"
    expect(response.body).to include(">Sign in</button>").or include("Sign in<")
    expect(response.body).not_to include("Iniciar sesión")

    get "/users/sign_up"
    expect(response.body).not_to include("Registrarse")
    expect(response.body).not_to match(/lang="es"/)

    get "/users/sign_in"
    expect(response.body).not_to match(/lang="es"/)
  end

  context "when signed in" do
    let(:user) { create(:user, ui_locale: "es") }
    before { sign_in user }

    it "uses the user's ui_locale over the default" do
      get "/"
      expect(response.body).to include(spanish_greeting)
    end

    it "ignores a conflicting params[:locale]" do
      get "/?locale=en"
      expect(response.body).to include(spanish_greeting)
    end

    it "ignores a conflicting session value set before sign-in" do
      sign_out user
      get "/?locale=en"
      sign_in user
      get "/"
      expect(response.body).to include(spanish_greeting)
    end
  end
end
