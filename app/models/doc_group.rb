class DocGroup < ActiveRecord::Base

	has_many :doc_group_templates
	has_one  :update_employee,  class_name: "Employee", foreign_key: "ID", primary_key: "updated_by"

end
