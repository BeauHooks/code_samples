class InternalNetwork < ActiveRecord::Base

  establish_connection(
    :adapter  => "mysql2",
    :host     => "192.168.100.10",
    :database => "rate_calculator_production",
    :username => "filetrakg",
    :password => "yellow"
  )

end
