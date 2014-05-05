class Bulletin < ActiveRecord::Base
  default_scope { order("created_at DESC") }

  has_one :create_employee, class_name: "Employee", foreign_key: "ID", primary_key: "created_by"

  TYPES = ["Tech", "Corporate Memo"]

  def author
    self.create_employee.FullName
  end

  def self.types
    TYPES
  end

  def self.select_options
    options = []
    TYPES.each do |type|
      options << [type, type]
    end
    options
  end
end