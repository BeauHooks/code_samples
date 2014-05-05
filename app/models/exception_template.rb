class ExceptionTemplate < ActiveRecord::Base
  self.table_name  = "tblExceptionTemplates"
  self.primary_key = "ID"

  belongs_to :requirement_template, foreign_key: "RequirementID"

end