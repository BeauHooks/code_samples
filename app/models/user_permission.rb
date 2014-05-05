class UserPermission < ActiveRecord::Base
  self.table_name = "users_permissions"

  belongs_to :user
  belongs_to :permission

end