class RateAffiliation < ActiveRecord::Base
  self.table_name  = "tblRateAffiliations"
  self.primary_key = "ID"

  scope :versioned, lambda { |v| { :conditions => { :version_id => (v.is_a?(CalcVersion) ? v.id : v) } } }

  belongs_to :policy_type_1, class_name: "PolicyType", foreign_key: "Policy1ID", primary_key: "ID" # This is a glorified HABTM join table...
  belongs_to :policy_type_2, class_name: "PolicyType", foreign_key: "Policy2ID", primary_key: "ID" # ...making it so a PolicyType HABTM PolicyTypes
  belongs_to :calc_version

end
