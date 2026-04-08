require "rails_helper"
require "rake"

RSpec.describe "embeddings:generate rake task" do
  let!(:translation) { create(:translation, :kjv) }
  let!(:book)        { create(:book, :john, translation: translation) }
  let!(:chapter)     { create(:chapter, book: book, number: 3) }
  let!(:verses) do
    (1..3).map do |n|
      create(:verse, chapter: chapter, number: n,
                     body_text: "verse #{n}", body_html: "verse #{n}",
                     osis_ref: "Bible.KJV.John.3.#{n}")
    end
  end

  def stub_payload(texts)
    {
      "embeddings" => texts.map.with_index { |_, i| [ 0.1 * (i + 1) ] + Array.new(383, 0.0) },
      "model_version" => "all-MiniLM-L6-v2"
    }
  end

  before(:all) do
    Rails.application.load_tasks unless Rake::Task.task_defined?("embeddings:generate")
  end

  before do
    Rake::Task["embeddings:generate"].reenable
    Rake::Task["embeddings:health"].reenable
    allow(EmbeddingService).to receive(:healthy?).and_return(true)
  end

  describe "embeddings:generate" do
    it "embeds every pending verse via the service" do
      allow(EmbeddingService).to receive(:embed_texts) { |texts| stub_payload(texts) }

      expect { Rake::Task["embeddings:generate"].invoke }.to output(/Embedded 3\/3/).to_stdout

      expect(VerseEmbedding.count).to eq(3)
      verses.each { |v| expect(v.reload.verse_embedding).to be_present }
    end

    it "is idempotent — only embeds verses without an existing row" do
      create(:verse_embedding, verse: verses.first)

      received_batches = []
      allow(EmbeddingService).to receive(:embed_texts) do |texts|
        received_batches << texts
        stub_payload(texts)
      end

      Rake::Task["embeddings:generate"].invoke

      expect(VerseEmbedding.count).to eq(3)
      # Service only asked to embed the two rows missing one
      expect(received_batches.flatten.size).to eq(2)
    end

    it "aborts when the service is unhealthy" do
      allow(EmbeddingService).to receive(:healthy?).and_return(false)

      expect { Rake::Task["embeddings:generate"].invoke }.to raise_error(SystemExit, /not responding/)
      expect(VerseEmbedding.count).to eq(0)
    end

    it "skips a failed batch and continues with the next" do
      # Batch size of 1 so each verse is its own batch.
      stub_const("ENV", ENV.to_hash.merge("EMBEDDING_BATCH_SIZE" => "1"))

      call_count = 0
      allow(EmbeddingService).to receive(:embed_texts) do |texts|
        call_count += 1
        raise EmbeddingService::EmbeddingError, "transient" if call_count == 2
        stub_payload(texts)
      end

      Rake::Task["embeddings:generate"].invoke

      # 2 of 3 verses embedded; the middle batch failed.
      expect(VerseEmbedding.count).to eq(2)
    end

    it "aborts when no KJV translation exists" do
      Translation.where(code: "KJV").destroy_all

      expect { Rake::Task["embeddings:generate"].invoke }
        .to raise_error(SystemExit, /KJV translation not found/)
    end
  end

  describe "embeddings:health" do
    it "prints a healthy message when the service responds" do
      allow(EmbeddingService).to receive(:healthy?).and_return(true)
      expect { Rake::Task["embeddings:health"].invoke }.to output(/healthy/).to_stdout
    end

    it "aborts when the service is unresponsive" do
      allow(EmbeddingService).to receive(:healthy?).and_return(false)
      expect { Rake::Task["embeddings:health"].invoke }.to raise_error(SystemExit, /not responding/)
    end
  end
end
