#
# Represents a "Freight Discount" line item within a FedEx rate calculation.
# This uses all the fields except for the "name", "formula", "value" and
# "effective_on" fields. See the "RateDiscount" entry in the rate_v9.wsdl file
# for more information.
#
class FedexRateDiscount < FedexRateLineItem

end
