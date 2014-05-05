class BasePolicy < ActiveRecord::Base

  belongs_to :base_schedule_a
	has_many   :base_policy_endorsements

end
