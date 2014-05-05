class RemitBatch < ActiveRecord::Base
  self.table_name  = "tblRemitBatches"
  self.primary_key = "ID"

  has_many   :file_endorsements,                   foreign_key: "RemitBatchID",   primary_key: "ID", order: "RemitDT, FileID, ID"
  has_many   :file_products,                       foreign_key: "RemitBatchID",   primary_key: "ID", order: "FileID, ProductName, IsActive, DummyTime DESC"
  belongs_to :created_by,  class_name: "Employee", foreign_key: "BatchCreatedBy", primary_key: "ID"
  belongs_to :reviewed_by, class_name: "Employee", foreign_key: "ReviewedBy",     primary_key: "ID"
  belongs_to :approved_by, class_name: "Employee", foreign_key: "ApprovedBy",     primary_key: "ID"
  belongs_to :sent_by,     class_name: "Employee", foreign_key: "BatchSentBy",    primary_key: "ID"

end
