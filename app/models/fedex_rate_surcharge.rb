# Represents a "Surcharge" line item within a FedEx rate calculation. This uses
# all the fields except for the "name", "formula", "value", "percent" and
# "effective_on" fields. See the "Surcharge" entry in the rate_v9.wsdl file for
# more info.
#
class FedexRateSurcharge < FedexRateLineItem

end
