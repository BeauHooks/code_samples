class FileTrakBase < ActiveRecord::Base
  self.abstract_class = true

  self.establish_connection(
    adapter:  "mysql2",
    host:     "192.168.100.10",
    username: "filetrakg",
    password: "yellow",
    database: "filetrak"
  )

end