class RateTemplate < ActiveRecord::Base
  self.table_name  = "tblRateTemplate"
  self.primary_key = "TemplateID"

  belongs_to :underwriter, :foreign_key => "Underwriter", :primary_key => "ID"
  belongs_to :policy_type, :foreign_key => "PolicyID",    :primary_key => "ID"
  belongs_to :calc_version

  scope :versioned, lambda { |v| { :conditions => { :version_id => (v.is_a?(CalcVersion) ? v.id : v) } } }

  # Return the "previous" RateTemplate instance. The previous instance is the
  # one, belonging to the same version, who's RateNum is set to exactly one
  # less than the current instance's RateNum value and where at least one of
  # the following two cases is alto true:
  #
  # 1. Both RateTemplate's belong to the same Underwriter, OR
  # 2. Both RateTemplate's belong to the same PolicyType
  #
  # This returns the "previous" RateTemplate instance, if it exists. Otherwise
  # it returnes nil.
  #
  # TODO: this may debatably belong in versioned code library???
  #
  def previous
    return nil if self.underwriter.nil? and self.policy_type.nil?
    return nil if self.RateNum.nil?
    if self.underwriter
      self.underwriter.rate_templates.versioned(version_id).find_by_RateNum(self.RateNum - 1)
    else
      self.policy_type.rate_templates.versioned(version_id).find_by_RateNum(self.RateNum - 1)
    end
  end

end
