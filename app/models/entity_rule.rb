class EntityRule < ActiveRecord::Base
  self.table_name  = "tblEntityRules"
  self.primary_key = "ID"

  belongs_to :entity,                             foreign_key: "EntityID",   primary_key: "EntityID"
  belongs_to :contact,    class_name: "Entity",   foreign_key: "ContactID",  primary_key: "EntityID"

  # Employee Action-Tracking Relationships
  belongs_to :created_by, class_name: "Employee", foreign_key: "CreatedBy",  primary_key: "ID"

end
