class UserType < ActiveRecord::Base
  self.table_name 	= "tblUserTypes"
  self.primary_key 	= "ID"

  def self.types
    order(:CustomerType).all.map { |t| t.CustomerType }
  end
end
