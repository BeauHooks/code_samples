class PublicUser < ActiveRecord::Base
  include TokenAuthenticatable
  establish_connection :filetrak_public
  self.table_name = "users"

  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :trackable, :validatable

  has_many :secure_deliveries

end
