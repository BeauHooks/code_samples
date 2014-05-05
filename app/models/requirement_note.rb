class RequirementNote < ActiveRecord::Base
  self.table_name  = "tblRequirementNotes"

  belongs_to :index, foreign_key: "FileID", primary_key: "FileID"

end
