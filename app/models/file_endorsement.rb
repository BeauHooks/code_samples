class FileEndorsement < ActiveRecord::Base
  self.table_name  = "tblFileEndorsements"
  self.primary_key = "ID"

  belongs_to :file_info,                           foreign_key: "FileID",        primary_key: "FileID"
  belongs_to :endorsement,                         foreign_key: "EndorsementID", primary_key: "EndorsementID"
  belongs_to :remit_batch,                         foreign_key: "RemitBatchID",  primary_key: "ID"

  # Employee Action-Tracking Relationships
  belongs_to :modified_by, class_name: "Employee", foreign_key: "ModifiedBy",    primary_key: "ID"
  belongs_to :approved_by, class_name: "Employee", foreign_key: "ApprovedBy",    primary_key: "ID"
  belongs_to :created_by,  class_name: "Employee", foreign_key: "CreatedBy",     primary_key: "ID"

end
