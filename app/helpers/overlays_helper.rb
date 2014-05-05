module OverlaysHelper
  def add_employee_to_new_file(name, f)
    new_object = f.object.send(:file_employees).klass.new
    id = new_object.object_id
    fields = f.fields_for(:file_employees, new_object, child_index: id) do |builder|
      render("index/partials/employee_row", f: builder)
    end
    link_to(name, "#", data: {id: id, fields: fields.gsub("\n", "")}, class: "add_employee")
  end

  def add_property_to_new_file(name, f)
    new_object = f.object.send(:file_properties).klass.new
    id = new_object.object_id
    fields = f.fields_for(:file_properties, new_object, child_index: id) do |builder|
      render("index/partials/property_row", f: builder)
    end
    link_to(name, "#", data: {id: id, fields: fields.gsub("\n", "")}, class: "add_property")
  end

  def add_entity_to_new_file(name, f)
    new_object = f.object.send(:file_entities).klass.new
    id = new_object.object_id
    fields = f.fields_for(:file_entities, new_object, child_index: id) do |builder|
      render("index/partials/contact_row", f: builder)
    end
    button_to(name, "#", data: {id: id, fields: fields.gsub("\n", "")}, class: "add_entity")
  end
end