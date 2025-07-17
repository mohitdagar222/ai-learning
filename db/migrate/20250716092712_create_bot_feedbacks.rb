class CreateBotFeedbacks < ActiveRecord::Migration[8.0]
  def change
    create_table :bot_feedbacks do |t|
      t.text :user_query
      t.text :bot_response
      t.boolean :liked
      t.integer :chunk_ids, array: true, default: []
      
      t.timestamps
    end
  end
end
