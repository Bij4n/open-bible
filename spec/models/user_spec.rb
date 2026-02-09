require "rails_helper"

RSpec.describe User, type: :model do
  describe "Devise modules" do
    it "enables the expected modules" do
      expect(User.devise_modules).to match_array(%i[
        database_authenticatable registerable recoverable rememberable validatable
      ])
    end
  end

  describe "validations" do
    subject { build(:user) }

    it { is_expected.to validate_presence_of(:email) }

    it "requires unique email case-insensitively" do
      create(:user, email: "reader@open-bible.test")
      dup = build(:user, email: "READER@open-bible.test")
      expect(dup).not_to be_valid
      expect(dup.errors[:email]).to be_present
    end

    it "rejects passwords shorter than the Devise minimum" do
      user = build(:user, password: "short", password_confirmation: "short")
      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    describe "ui_locale" do
      it "accepts en and es" do
        expect(build(:user, ui_locale: "en")).to be_valid
        expect(build(:user, ui_locale: "es")).to be_valid
      end

      it "rejects other values" do
        user = build(:user, ui_locale: "fr")
        expect(user).not_to be_valid
        expect(user.errors[:ui_locale]).to be_present
      end
    end

    describe "theme" do
      it "accepts light, dark, and system" do
        %w[light dark system].each do |t|
          expect(build(:user, theme: t)).to be_valid
        end
      end

      it "rejects other values" do
        user = build(:user, theme: "hyperspace")
        expect(user).not_to be_valid
        expect(user.errors[:theme]).to be_present
      end
    end

    describe "display_name" do
      it "is optional" do
        expect(build(:user, display_name: nil)).to be_valid
        expect(build(:user, display_name: "")).to be_valid
      end

      it "rejects names longer than 60 characters" do
        user = build(:user, display_name: "x" * 61)
        expect(user).not_to be_valid
        expect(user.errors[:display_name]).to be_present
      end

      it "enforces case-insensitive uniqueness when set" do
        create(:user, :with_display_name, display_name: "Scribe")
        dup = build(:user, display_name: "scribe")
        expect(dup).not_to be_valid
        expect(dup.errors[:display_name]).to be_present
      end

      it "allows many users with no display_name" do
        create(:user, display_name: nil)
        expect(build(:user, display_name: nil)).to be_valid
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:default_translation).class_name("Translation").optional }
  end

  describe "defaults" do
    it "sets ui_locale and theme when the row is created" do
      user = User.create!(email: "fresh@open-bible.test", password: "correct horse battery staple")
      expect(user.ui_locale).to eq("en")
      expect(user.theme).to eq("system")
    end
  end

  describe "#author_name" do
    it "returns the display_name when set" do
      user = build(:user, display_name: "Scribe", email: "bookish@open-bible.test")
      expect(user.author_name).to eq("Scribe")
    end

    it "falls back to the email local-part when display_name is blank" do
      user = build(:user, display_name: nil, email: "scribe@open-bible.test")
      expect(user.author_name).to eq("scribe")
    end

    it "handles emails without an @ by returning the full string" do
      user = build(:user, display_name: nil, email: "plain")
      expect(user.author_name).to eq("plain")
    end
  end
end
