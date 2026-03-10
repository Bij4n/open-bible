require "rails_helper"

RSpec.describe ApplicationCable::Connection, type: :channel do
  it "identifies the signed-in user from the Warden env" do
    user = create(:user)
    connect "/cable", env: { "warden" => double(user: user) }
    expect(connection.current_user).to eq(user)
  end

  it "rejects anonymous connections" do
    expect {
      connect "/cable", env: { "warden" => double(user: nil) }
    }.to have_rejected_connection
  end

  it "rejects connections with no warden in env" do
    expect {
      connect "/cable"
    }.to have_rejected_connection
  end
end
