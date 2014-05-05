class RuleTrigger < ActiveRecord::Base

  attr_accessible :rule_id

	belongs_to :rule

	TRIGGERS = ["Add to Order", "Create PR", "Add to Disbursement", "Send for Date Down", "Send for Funding",
		"On Record", "Policy Out"]

	def self.get_trigger_list
		TRIGGERS
	end
end
