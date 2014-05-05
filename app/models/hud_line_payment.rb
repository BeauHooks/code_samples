class HudLinePayment < ActiveRecord::Base

	before_destroy :update_check_working

  belongs_to :hud
  belongs_to :hud_line
  belongs_to :entity
  belongs_to :company
  belongs_to :invoice
  belongs_to :index
  belongs_to :check
  belongs_to :check_working, foreign_key: "check_id", primary_key: "id"

  def update_check_working
  	check = self.check_working
  	return if check == nil
    amount = HudLinePayment.where("check_id = #{check.id} AND id != #{self.id}").sum("amount").to_f
    check.amount = amount
    check.save
  end
end
