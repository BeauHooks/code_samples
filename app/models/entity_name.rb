class EntityName < ActiveRecord::Base
  self.table_name  = "tblEntityNames"
  self.primary_key = "NameID"

  belongs_to :entity, foreign_key: "EntityID", primary_key: "EntityID"

end
