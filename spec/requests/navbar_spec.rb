require "rails_helper"

# Structural assertions on the navbar dropdown introduced in Sprint 12.
# Request-level coverage rather than a system spec because the
# dropdown's JS behavior (toggle, click-outside, Escape) is a thin
# Stimulus controller the user is verifying locally; what belongs in
# CI is "does the rendered markup contain the right items behind the
# user-menu trigger." Signed-out checks hit the home page (not the
# Devise sign-in view) because Devise's shared _links partial renders
# a "Sign up" link underneath the form, which would make it impossible
# to assert that "Sign up" is absent from the navbar.
RSpec.describe "Navbar", type: :request do
  describe "signed-out visitors" do
    before { get "/" }

    it "wires the user-menu Stimulus controller with a trigger + menu pair" do
      expect(response.body).to include('data-controller="user-menu"')
      expect(response.body).to include('data-user-menu-target="trigger"')
      expect(response.body).to include('data-user-menu-target="menu"')
    end

    it "places sign-in inside the menu and omits sign-up (sign-up is one click away via the Devise form)" do
      expect(response.body).to include("Sign in")
      expect(response.body).not_to include("Sign up")
    end

    it "places the theme toggle and both locale options inside the menu" do
      expect(response.body).to include(%(aria-label="Switch theme"))
      expect(response.body).to include(%(data-label-light="Light"))
      expect(response.body).to include(%(data-label-dark="Dark"))
      expect(response.body).to include("English")
      expect(response.body).to include("Español")
    end

    it "does not render a signed-in-only item" do
      expect(response.body).not_to include(">Sign out<")
      expect(response.body).not_to include(">Admin<")
    end
  end

  describe "signed-in regular users" do
    let(:user) { create(:user) }

    before do
      sign_in user
      get "/"
    end

    it "places settings and sign-out inside the menu" do
      expect(response.body).to include(">Settings<")
      expect(response.body).to include("Sign out")
    end

    it "hides sign-in, sign-up, and admin" do
      expect(response.body).not_to include(">Sign in<")
      expect(response.body).not_to include(">Sign up<")
      expect(response.body).not_to include(">Admin<")
    end
  end

  describe "signed-in admins" do
    let(:admin) { create(:user, admin: true) }

    before do
      sign_in admin
      get "/"
    end

    it "surfaces the admin link inside the menu" do
      expect(response.body).to include(">Admin<")
    end
  end
end
