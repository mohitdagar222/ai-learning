class CreateDocuments < ActiveRecord::Migration[8.0]
  def change
    enable_extension "vector" unless extension_enabled?("vector")
    
    create_table :documents do |t|
      t.text :content
      t.vector :embedding, limit: 1536

      t.timestamps
    end
  end
end
