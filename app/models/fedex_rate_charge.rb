#
# Represents a "Variable Handling Charge" line item withing a FedEx rate
# calculation. As such, the only fields used are:
#
#   amount (holds the "Total Customer Charge")
#   value  (holds the "Variable Handling Charge")
#
# The variable handling charge is the calculated amount based on the provided
# details and is stored as the "value". The "amount" is the "value" plus the
# "net charge" (see FedEx docs).
#
class FedexRateCharge < FedexRateLineItem

end
