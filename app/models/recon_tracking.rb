class ReconTracking < ActiveRecord::Base
  self.table_name  = "tblReconTracking"
  self.primary_key = "id"

  belongs_to :index, 	foreign_key: "FileID", 				        primary_key: "FileID"
  belongs_to :county,	foreign_key: "TrustDeedEntryCounty",  primary_key: "CountyID"

end
