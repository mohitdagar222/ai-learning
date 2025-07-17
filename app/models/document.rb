class Document < ApplicationRecord
  has_embeddings :embedding, dimensions: 1536
end
