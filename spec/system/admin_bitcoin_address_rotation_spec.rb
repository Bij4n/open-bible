require "rails_helper"

# Admin-only flow under ensure_admin. No JS needed — pure Rails forms,
# no Stimulus on the admin pages. rack_test driver suffices and keeps
# the spec fast.
RSpec.describe "Admin bitcoin address rotation", type: :system do
  let(:admin) { create(:user, admin: true) }

  it "lets the admin add a first address and then rotate to a second" do
    sign_in admin
    visit admin_bitcoin_addresses_path

    expect(page).to have_content("No addresses yet")

    click_on "New address"
    fill_in "Bitcoin address", with: "bc1qfirstadminaddedaddressxxxxxxxx"
    fill_in "Notes", with: "ledger / acct 0"
    click_on "Add address"

    expect(page).to have_content("bc1qfirstadminaddedaddressxxxxxxxx")
    expect(page).to have_content("Active")
    expect(page).not_to have_content("No addresses yet")

    click_on "New address"
    fill_in "Bitcoin address", with: "bc1qsecondrotationtargetxxxxxxxxxx"
    fill_in "Notes", with: "trezor / acct 1"
    click_on "Add address"

    # Both addresses listed; only the new one is active.
    expect(page).to have_content("bc1qsecondrotationtargetxxxxxxxxxx")
    expect(page).to have_content("bc1qfirstadminaddedaddressxxxxxxxx")
    expect(page).to have_content("Active").once
    expect(page).to have_content("Archived")
  end

  it "re-renders the form with errors when the address is invalid" do
    sign_in admin
    visit new_admin_bitcoin_address_path

    fill_in "Bitcoin address", with: "tooShort"
    click_on "Add address"

    expect(page).to have_content("is too short")
    expect(BitcoinAddress.count).to eq(0)
  end
end
