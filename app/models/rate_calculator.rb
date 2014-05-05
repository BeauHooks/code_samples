class RateCalculator < ActiveRecord::Base
  self.table_name  = "tblRateCalculator"
  self.primary_key = "RateID"

  scope :versioned, lambda { |v| { :conditions => { :version_id => (v.is_a?(CalcVersion) ? v.id : v) } } }

  belongs_to :underwriter, :foreign_key => "Underwriter", :primary_key => "ID"
  belongs_to :calc_version

end
