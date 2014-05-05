class Delivery < ActiveRecord::Base
  self.table_name  = "tblDelivery"
  self.primary_key = "DeliveryID"

  # Define supported delivery types (DeliveryType values)
  TYPES = { 3 => :email, 4 => :web }

  # Search for undelivered deliveries that are ready to be delivered
  scope :deliverable, lambda { { :conditions => ["triggerDT < ? AND SentDT IS NULL", Time.now] } }

  belongs_to :file_info,                               foreign_key: "FileID",         primary_key: "FileID"
  belongs_to :entity,                                  foreign_key: "EntityID",       primary_key: "EntityID"
  belongs_to :entered_by,     class_name: "Employee",  foreign_key: "EnteredBy",      primary_key: "ID"
  belongs_to :from_employee,  class_name: "Employee",  foreign_key: "fromEmployeeID", primary_key: "ID"
  has_many   :delivery_items,                          foreign_key: "DeliveryID",     primary_key: "DeliveryID", order: "Priority"
  has_many   :file_images,    through: :delivery_items

  # Get a fully-formatted email address, including the name part, of the person
  # this delivery is destined for. If a name part is included, the name will be
  # quoted to allow it to be included in recipient lists (single string) even
  # if the name has commas.
  #
  def to_email
    result = self.UserEmail
    name   = self.UserName
    name   = $1 while name =~ /^['"](.+)['"]$/
    name.blank? ? result.dup : "\"#{name}\" <#{result}>"
  end

  # Get the mapped, symbolic version of the DeliveryType field; if it isn't one
  # of the supported values (TYPES above) then nil is returned.
  #
  def delivery_type
    TYPES[self.DeliveryType]
  end
end
