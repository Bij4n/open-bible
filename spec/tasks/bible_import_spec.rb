require "rails_helper"
require "rake"
require "fileutils"

RSpec.describe "bible:import rake task" do
  let(:fixture_path) { Rails.root.join("spec/fixtures/osis/kjv_mini.xml") }
  let(:target_path)  { Rails.root.join("tmp/bible_sources/kjv_mini.xml") }

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("bible:import")
  end

  before do
    Rake::Task["bible:import"].reenable
    FileUtils.mkdir_p(target_path.dirname)
    FileUtils.cp(fixture_path, target_path)
    Bible::CanonicalBooks.reset!
  end

  after do
    FileUtils.rm_f(target_path)
  end

  it "creates the translation, books, chapters, and verses" do
    Rake::Task["bible:import"].invoke("kjv_mini")

    translation = Translation.find_by!(code: "KJV_MINI")
    expect(translation.name).to eq("KJV Mini (test fixture)")
    expect(translation.books.count).to eq(2)
    expect(Verse.where("osis_ref LIKE 'Bible.KJV_MINI.%'").count).to eq(14)
  end

  it "is idempotent on re-run" do
    Rake::Task["bible:import"].invoke("kjv_mini")
    Rake::Task["bible:import"].reenable
    Rake::Task["bible:import"].invoke("kjv_mini")

    expect(Translation.where(code: "KJV_MINI").count).to eq(1)
    expect(Book.where(translation: Translation.find_by!(code: "KJV_MINI")).count).to eq(2)
    expect(Verse.where("osis_ref LIKE 'Bible.KJV_MINI.%'").count).to eq(14)
  end

  it "aborts loudly on SHA256 mismatch" do
    File.write(target_path, "tampered content that won't match the sha")
    expect {
      Rake::Task["bible:import"].invoke("kjv_mini")
    }.to raise_error(SystemExit, /SHA256 mismatch/)
  end
end
