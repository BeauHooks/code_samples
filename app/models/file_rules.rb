class FileRules < ActiveRecord::Base
  self.table_name  = "tblFileRules"
  self.primary_key = "RuleID"

  belongs_to :index,                                  foreign_key: "FileID",       primary_key: "FileID"
  belongs_to :rule_from_entity, class_name: "Entity", foreign_key: "FromCustomer", primary_key: "EntityID"
end
