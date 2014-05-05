class RuleName < ActiveRecord::Base

  before_save :generate_name

  attr_accessible :rule_id

  belongs_to :rule

  def generate_name
  	if self.name_type == "Individual"
  		match = ""
  		full = ""

  		match = self.last_name if !self.last_name.blank?
  		full = self.last_name if !self.last_name.blank?

  		match = "#{self.middle_name} #{match}" if !self.middle_name.blank?
  		full = "#{full}, #{self.first_name}" if !self.first_name.blank?

  		match = "#{self.first_name} #{match}" if !self.first_name.blank?
  		full = !self.first_name.blank? ? "#{full} #{self.middle_name}" : "#{full}, #{self.middle_name}" if !self.middle_name.blank?

			self.match_name = match
			self.full_name = full
		else
			self.match_name = self.full_name
			self.first_name = self.full_name
		end
  end
end
