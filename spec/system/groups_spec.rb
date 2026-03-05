require "rails_helper"

RSpec.describe "Groups", type: :system, js: true do
  let(:owner)  { create(:user, email: "owner@open-bible.test") }
  let(:friend) { create(:user, email: "friend@open-bible.test") }

  it "lets an owner create a group, share the code, and a friend join" do
    sign_in owner
    visit "/groups"
    click_on "New group"

    fill_in "Name", with: "Tuesday Study"
    fill_in "Description", with: "Weekly gathering."
    find("input[value='invite_only']").click
    find('input[type="submit"]').click

    expect(page).to have_content(/tuesday study/i)
    code = Group.find_by!(name: "Tuesday Study").invitation_code
    expect(page).to have_content(code)

    sign_out owner
    sign_in friend
    visit "/groups"
    find("input[name='invitation_code']").set(code)
    find('input[type="submit"][value="Join"]').click

    expect(page).to have_content(/tuesday study/i)
    expect(Group.find_by!(name: "Tuesday Study").members).to include(friend)
  end
end
