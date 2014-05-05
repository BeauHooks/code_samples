class DocTemplateVersion < ActiveRecord::Base

	belongs_to :doc_template
	has_one    :update_employee, class_name: "Employee", foreign_key: "ID", primary_key: "created_by"
	belongs_to :doc_signature_type

end
