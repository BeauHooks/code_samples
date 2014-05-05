class RateVersion < ActiveRecord::Base
  self.table_name = "versions"

  default_scope { where("is_active != 0") }

end
