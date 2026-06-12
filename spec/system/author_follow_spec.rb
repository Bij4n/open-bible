require "rails_helper"

# Author-page follow UI (Sprint R5): follow/unfollow toggle, follower/
# following counts, and a Friends badge on mutual follows.
RSpec.describe "Author follow UI", type: :system do
  let(:user)   { create(:user) }
  let(:author) { create(:user, display_name: "Apollos") }

  it "follows and unfollows from the author page" do
    sign_in user
    visit author_path(author)

    expect(page).to have_text(I18n.t("authors.followers", count: 0))
    click_button I18n.t("authors.follow")

    expect(page).to have_button(I18n.t("authors.unfollow"))
    expect(page).to have_text(I18n.t("authors.followers", count: 1))
    expect(user.reload.following?(author)).to be true

    click_button I18n.t("authors.unfollow")
    expect(page).to have_button(I18n.t("authors.follow"))
    expect(user.reload.following?(author)).to be false
  end

  it "shows a Friends badge when the follow is mutual" do
    author.follow!(user)
    user.follow!(author)
    sign_in user

    visit author_path(author)

    expect(page).to have_text(I18n.t("authors.friends_badge"))
  end

  it "shows no follow button on your own page" do
    sign_in user
    visit author_path(user)

    expect(page).not_to have_button(I18n.t("authors.follow"))
  end

  it "shows no follow button signed out" do
    visit author_path(author)

    expect(page).not_to have_button(I18n.t("authors.follow"))
  end
end
