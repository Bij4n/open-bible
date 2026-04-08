namespace :embeddings do
  desc "Generate vector embeddings for every KJV verse (resumable)"
  task generate: :environment do
    translation = Translation.find_by(code: "KJV")
    abort "KJV translation not found. Run bible:import first." unless translation

    verses = Verse.joins(chapter: { book: :translation })
                  .where(chapters: { books: { translation_id: translation.id } })

    total     = verses.count
    pending   = verses.left_joins(:verse_embedding)
                      .where(verse_embeddings: { id: nil })
                      .order(:id)
    remaining = pending.count
    embedded  = total - remaining

    puts "KJV verses:       #{total}"
    puts "Already embedded: #{embedded}"
    puts "Pending:          #{remaining}"
    next if remaining.zero?

    unless EmbeddingService.healthy?
      abort "Embedding service is not responding at #{EmbeddingService::BASE_URL}. Start it via bin/embedding or Procfile.dev."
    end

    batch_size = ENV.fetch("EMBEDDING_BATCH_SIZE", 100).to_i

    pending.find_in_batches(batch_size: batch_size) do |batch|
      texts = batch.map(&:body_text)
      begin
        payload = EmbeddingService.embed_texts(texts)
        model_version = payload["model_version"]

        batch.each_with_index do |verse, i|
          VerseEmbedding.create!(
            verse: verse,
            embedding: payload["embeddings"][i],
            model_version: model_version
          )
        end

        embedded += batch.size
        pct = ((embedded.to_f / total) * 100).round(1)
        puts "Embedded #{embedded}/#{total} (#{pct}%)"
      rescue EmbeddingService::EmbeddingError => e
        warn "Batch failed: #{e.message}. Continuing with next batch."
      end
    end

    puts "Done."
  end

  desc "Ping the embedding service"
  task health: :environment do
    if EmbeddingService.healthy?
      puts "Embedding service at #{EmbeddingService::BASE_URL} is healthy."
    else
      abort "Embedding service at #{EmbeddingService::BASE_URL} is not responding."
    end
  end
end
