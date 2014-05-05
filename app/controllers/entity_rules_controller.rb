class EntityRulesController < ApplicationController

  def new
    @rule   = EntityRule.new
    @entity = Entity.find params[:id]
    respond_to do |format|
      format.html { render layout: "modal_box" }
    end
  end

  def create
    @params         = params[:entity_rule]
    @rule           = EntityRule.new
    @rule.EntityID  = @params[:EntityID]
    @rule.RuleDT    = Time.now.to_s(:db)
    @rule.CreatedBy = current_user.employee_id
    @rule.RuleText  = @params[:RuleText]
    @rule.save
    respond_to do |format|
      format.js { render nothing: true }
    end
  end
end
