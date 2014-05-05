class Endorsement < ActiveRecord::Base
  self.table_name  = "tblEndorsements"
  self.primary_key = "EndorsementID"

  scope :versioned, lambda { |v| { :conditions => { :version_id => (v.is_a?(CalcVersion) ? v.id : v) } } }

  has_many   :file_endorsements,   foreign_key: "EndorsementID",  primary_key: "EndorsementID", order: "FileID, ID"
  has_many   :policy_endorsements, foreign_key: "endorsement_id", primary_key: "EndorsementID", order: "FileID, ID"
  belongs_to :underwriter,         foreign_key: "Underwriter",    primary_key: "ID"
  belongs_to :calc_version

end