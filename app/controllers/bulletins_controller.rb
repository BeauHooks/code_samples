class BulletinsController < ApplicationController
  def index
  	@bulletins = []
  end

  def new
  	@bulletin = Bulletin.new
  end

  def edit
  	@bulletin = Bulletin.find params[:id]
  	respond_to do |format|
  		format.js {render "new"}
  	end
  end

  def create
  	bulletin = Bulletin.new

  	params.each do |key, value|
			unless !bulletin.attributes.include?(key)
				bulletin.send(key + "=", (value || nil) )
			end
		end

		bulletin.created_by = current_user.employee_id
		bulletin.updated_by = current_user.employee_id
		bulletin.created_at = Time.now.to_s(:db)
		bulletin.updated_at = Time.now.to_s(:db)

		bulletin.save

    @bulletins = Bulletin.all
  end

  def update
  	bulletin = Bulletin.find params[:id]

  	params.each do |key, value|
			unless !bulletin.attributes.include?(key)
				bulletin.send(key + "=", (value || nil) )
			end
		end

		bulletin.updated_by = current_user.employee_id
		bulletin.updated_at = Time.now.to_s(:db)

		bulletin.save
    @bulletins = Bulletin.all
		respond_to do |format|
  		format.js {render "create"}
  	end
  end

  def show
  	@bulletin = Bulletin.find params[:id]
  end

  def search 
  	if !params[:category].blank?
  		@bulletins = Bulletin.where("category = '#{params[:category]}'")
  	else
  		@bulletins = Bulletin.all
  	end
  end
end