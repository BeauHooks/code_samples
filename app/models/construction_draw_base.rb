class ConstructionDrawBase < ActiveRecord::Base
  self.abstract_class = true

  # Configure the connection to be shared by all subclasses
  #
  #establish_connection "construction_draw_#{RAILS_ENV}"
  establish_connection(
    :adapter  => "mysql2",
    :host     => "192.168.100.10",
    :database => "ConstructionDraw",
    :username => "filetrakg",
    :password => "yellow"
  )

end
