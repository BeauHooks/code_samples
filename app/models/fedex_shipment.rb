class FedexShipment < ActiveRecord::Base

  belongs_to :shipment
  has_many   :fedex_rates

end
