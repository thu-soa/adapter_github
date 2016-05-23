class AddUsers < ActiveRecord::Migration
  def change
    create_table :message_source_token_stubs do |t|
      t.string    :source
      t.timestamps null: false
      t.datetime  :valid_until
      t.integer   :user_id
      t.text      :content
    end
  end
end
