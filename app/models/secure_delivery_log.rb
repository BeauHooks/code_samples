class SecureDeliveryLog < ActiveRecord::Base
  establish_connection :filetrak_public
  self.pluralize_table_names = false

  belongs_to :public_user, foreign_key: :user_id, primary_key: :id

  def self.viewed_count(user_id, file_image_id)
    SecureDeliveryLog.where("user_id = #{user_id} AND file_image_id = file_image_id AND viewed_at IS NOT NULL").size
  end

  def self.get_history(file_image_id)
    SecureDeliveryLog.where("file_image_id = #{file_image_id}").order("created_at ASC")
  end
end