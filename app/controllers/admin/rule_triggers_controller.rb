class Admin::RuleTriggersController < AdminController
  def create
  	trigger = RuleTrigger.where("rule_id = #{params[:rule_id]} AND trigger_text = '#{params[:trigger]}'").first

  	# Create only if it doesn't exist. Otherwise, destroy.
  	if trigger == nil
  		trigger = RuleTrigger.new
  		trigger.rule_id = params[:rule_id]
  		trigger.created_at = Time.now.to_s
  		trigger.created_by = current_user.employee_id
  		trigger.updated_at = Time.now.to_s(:db)
	  	trigger.updated_by = current_user.employee_id
	  	trigger.trigger_text = params[:trigger]
	  	trigger.save
	  else
	  	trigger.destroy
  	end

  	render nothing: true
  end
end