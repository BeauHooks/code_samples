class DeliveryItem < ActiveRecord::Base
  self.table_name  = "tblDeliveryItems"
  self.primary_key = "DeliveryItemID"

  belongs_to :delivery,   foreign_key: "DeliveryID", primary_key: "DeliveryID"
  belongs_to :file_image, foreign_key: "ImageID",    primary_key: "ImageID"

end
