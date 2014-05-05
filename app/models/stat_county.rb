class StatCounty < ActiveRecord::Base
  self.table_name   = "tblCounty"
  self.primary_key  = "CountyID"

  establish_connection(
    :adapter  		=> "mysql2",
    :host     		=> "localhost",
    :database 		=> "NewStats",
    :username 	  => "root"
  )

  belongs_to :taxroll1

end
