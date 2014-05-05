class BaseProduct < ActiveRecord::Base

  has_one  :base_schedule_a
	has_many :base_product_exceptions
	has_many :base_product_requirements
	has_many :base_policies,            through: :base_schedule_a
	has_many :base_policy_endorsements, through: :base_policies

end
