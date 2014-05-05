class Gfe < ActiveRecord::Base
  establish_connection :rate_calc

  belongs_to :hud
  has_one    :quote

end
