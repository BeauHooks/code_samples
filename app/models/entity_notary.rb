class EntityNotary < ActiveRecord::Base
  self.table_name  = "tblEntityNotaries"
  self.primary_key = "NotaryID"

  belongs_to :entity,                                   foreign_key: "EntityID",  primary_key: "EntityID"
  belongs_to :signature, class_name: "EntitySignature", foreign_key: "UserSigID", primary_key: "UserSigID"

end
