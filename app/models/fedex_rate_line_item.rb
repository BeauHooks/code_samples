# Represents a general line item within a FedEx rate calculation. The specific
# types are represented by Single Table Inheritance (STI) subclasses (using the
# "type" field, of course). The types supported are:
#
#   charge    => FedexRateCharge
#   discount  => FedexRateDiscount
#   duty      => FedexRateDuty
#   rebate    => FedexRateRebate
#   surcharge => FedexRateSurcharge
#   tax       => FedexRateTax
#
class FedexRateLineItem < ActiveRecord::Base

  belongs_to :fedex_rate

end
