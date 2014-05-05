# Represents a "Rebate" line item within a FedEx rate calculation. This uses all
# the fields except for the "name", "formula", "value" and "effective_on"
# fields. See the "Rebate" entry in the rate_v9.wsdl file for more info.
#
class FedexRateRebate < FedexRateLineItem

end
