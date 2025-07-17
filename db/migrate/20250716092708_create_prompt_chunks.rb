class CreatePromptChunks < ActiveRecord::Migration[8.0]
  def change
    create_table :prompt_chunks do |t|
      t.string :link
      t.text :chunk, null: false
      t.vector :embedding, limit: 1536, null: false
      t.float :quality_score, default: 0.0

      t.timestamps
    end
  end
end
