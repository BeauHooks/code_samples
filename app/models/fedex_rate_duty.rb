# Represents a "Duties and Taxes" line item within a FedEx rate calculation.
# This uses the following fields as mapped the specified Fedex "EdtCommodityTax"
# field:
#
#   subtype      => HarmonizedCode + ":" (colon) + EdtTaxDetail.TaxType
#   name         => EdtTaxDetail.Name
#   description  => EdtTaxDetail.Description
#   formula      => EdtTaxDetail.Formula
#   amount       => EdtTaxDetail.Amount
#   value        => EdtTaxDetail.TaxableValue
#   effective_on => EdtTaxDetail.EffectiveDate
#
# The only unused field is the "percent" field. See the "EdtCommodityTax" entry
# int he rate_v9.wsdl file for more info.
#
class FedexRateDuty < FedexRateLineItem

  # For this, the true #subtype should be the EdtTaxDetail.TaxType or everything
  # after the first colon:
  #
  def subtype
    return nil unless self[:subtype] =~ /^[^:]*:(.+)$/
    $1
  end

  def subtype=(val)
    self[:subtype] = "#{harmonized_code}:#{val}"
  end

  #
  # The harmonized code is squished into the "subtype" field, seperated by a
  # colon (I hope FedEx doesn't use colons in harmonized codes...).
  #
  def harmonized_code
    return nil unless self[:subtype] =~ /^([^:]+)/
    $1
  end

  def harmonized_code=(val)
    self[:subtype] = "#{val}:#{subtype}"
  end
end
