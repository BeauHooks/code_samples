class HudEntitiesController < ApplicationController
  def index
    @hud_entities = HudEntity.find(:all)

    resond_to do |format|
      format.html
    end
  end

  def show
  end

  def edit
  end

  def update
  end

  def new
    @hud_entity = HudEntity.new

    respond_to do |format|
      format.html
    end
  end

  def destroy
  end

end
