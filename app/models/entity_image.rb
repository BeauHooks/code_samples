class EntityImage < ActiveRecord::Base
  self.table_name  = "tblEntityImages"
  self.primary_key = "ID"

  belongs_to :entity,                        foreign_key: "EntityID",  primary_key: "EntityID"
  belongs_to :contact, class_name: "Entity", foreign_key: "ContactID", primary_key: "EntityID"

  def image_type
    self.ImageType.nil? ? "Image" : self.ImageType
  end
end
