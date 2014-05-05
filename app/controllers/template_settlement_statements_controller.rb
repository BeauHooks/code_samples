class TemplateSettlementStatementsController < ApplicationController

  def show
    @ss = TemplateSettlementStatement.all
  end
end