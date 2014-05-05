class QuoteEndorsement < ActiveRecord::Base
  establish_connection :rate_calc

  attr_accessible :quote, :quote_id, :endorsement, :endorsement_id, :group_number, :group_name, :quoted_amount

  belongs_to :quote
  belongs_to :endorsement

end
