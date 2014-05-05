class Shipment < ActiveRecord::Base
  self.inheritance_column = "disabling_sti"

  belongs_to :employee, primary_key: "ID"
  belongs_to :company,  primary_key: "CompanyID"
  belongs_to :file,     primary_key: "FileID", class_name: "FileInfo"
  belongs_to :entity,   primary_key: "EntityID"

  validates :to, :to_address1, :to_city, :to_state, :to_country, :to_zip, :to_phone, :service, :packaging, :weight, :ship_at, :presence => true

  attr_accessor :type, :sender_email, :ship_notify_sender, :deliver_notify_sender, :recipient1_email,
    :ship_notify_recipient1, :deliver_notify_recipient1, :recipient2_email, :ship_notify_recipient2, :deliver_notify_recipient2,
    :recipient3_email, :ship_notify_recipient3, :deliver_notify_recipient3, :notify_message, :no_signature

  SEARCH_OPTIONS = [
                     ["File Number","file_number"],
                     ["Entity ID","entity_id"],
                     ["To Name","to_name"],
                     ["Date","date"],
                     ["Tracking Number","tracking_number"]
                   ]

  def self.search_options
    SEARCH_OPTIONS
  end

  # If smart search is added to this table, this method must get renamed or removed
  def self.search(option, term)
    order = "created_at DESC"
    case option
    when "file_number"
      where("file_id = ? AND cancel_at IS NULL", term["0"]).order(order)
    when "entity_id"
      where("entity_id = ? AND cancel_at IS NULL", term["0"]).order(order)
    when "to_name"
      where("shipments.to LIKE ? AND cancel_at IS NULL", term["0"].gsub("*","%").gsub("'", "\\\\'")+"%").order(order)
    when "date"
      where("created_at BETWEEN ? AND ? AND cancel_at IS NULL", term["1"]+" 00:00:00", term["2"]+" 23:59:59").order(order)
    when "tracking_number"
      where("tracking = ? AND cancel_at IS NULL", term["0"]).order(order)
    else
      []
    end
  end

  def type
    write_attribute(:type, "FedEx")
  end
end
