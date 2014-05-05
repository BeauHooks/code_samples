class EntityPermission < ActiveRecord::Base
  self.table_name  = "tblEntityPermissions"
  self.primary_key = "ID"

  belongs_to :entity,                              foreign_key: "EntityID",   primary_key: "EntityID"

  # Employee Action-Tracking Relationships
  belongs_to :entered_by,  class_name: "Employee", foreign_key: "EnteredBy",  primary_key: "ID"
  belongs_to :inactive_by, class_name: "Employee", foreign_key: "InactiveBy", primary_key: "ID"

end
