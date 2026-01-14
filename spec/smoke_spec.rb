require "rails_helper"

RSpec.describe "suite smoke" do
  it "runs arithmetic" do
    expect(1 + 1).to eq(2)
  end

  it "loads the Rails environment" do
    expect(Rails.env).to eq("test")
    expect(Rails.application.class.name).to eq("OpenBible::Application")
  end
end
