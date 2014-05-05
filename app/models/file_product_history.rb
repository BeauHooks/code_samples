class FileProductHistory < ActiveRecord::Base

  default_scope {order("updated_at DESC")}

  belongs_to :file_product
  belongs_to :update_employee, class_name: :Employee, foreign_key: "updated_by", primary_key: "ID"

  def self.create_history(object, field)
    file_product = object.file_product
    time = Time.now.to_s(:db)

    history = FileProductHistory.new
    history.file_product_id = file_product.id
    history.record_id = object.id
    history.table_name = object.class.table_name
    history.field_name = field
    history.old_value = object.send(field + "_was")
    history.new_value = object.send(field)
    history.updated_by = object.updated_by
    history.updated_at = time
    history.save

    file_product.updated_by = object.updated_by
    file_product.updated_at = time
    file_product.save
  end
end