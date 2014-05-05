class BaseScheduleA < ActiveRecord::Base

	belongs_to :base_product
	has_many   :base_policies
	has_many   :base_policy_endorsements, through: :base_policies

end
