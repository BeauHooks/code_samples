class NewStatsBase < ActiveRecord::Base
  self.abstract_class = true

  # Configure the connection to be shared by all subclasses
  #
  #establish_connection "disburse_#{RAILS_ENV}"
  establish_connection :new_stats
  # establish_connection(
  #   :adapter  => "mysql2",
  #   :host     => "192.168.100.10",
  #   :database => "NewStats",
  #   :username => "filetrakg",
  #   :password => "yellow"
  # )
end
