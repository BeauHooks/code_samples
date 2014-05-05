	class ReconTrackingsController < ApplicationController
	def create
		@file               = Index.where("FileID = #{params[:FileID]}").first
		recon               = ReconTracking.new
		recon.employee_id   = current_user.employee_id
		recon.Company       = @file.Company
		recon.DisplayFileID = @file.DisplayFileID

		date_fields = ["PayoffGoodThruDate"]
		params.each do |key, value|
			unless !recon.attributes.include?(key) || date_fields.include?(key)
				recon.send(key + "=", (value || nil) )
			end

			if date_fields.include?(key)
				recon.send(key + "=", (datetime_parse(value) rescue nil) )
			end
		end

		recon.save

		@commit = params[:commit]
		@reconveyance = ReconTracking.new(recon.attributes) if @commit == "Save and Copy"

		respond_to do |format|
	    format.js { render 'recon_trackings/refresh' }
	  end
	end

	def update
		recon = ReconTracking.find params[:id]
		@file = recon.index

		date_fields = ["PayoffGoodThruDate"]
		params.each do |key, value|
			unless !recon.attributes.include?(key) || date_fields.include?(key)
				recon.send(key + "=", (value || nil) )
			end

			if date_fields.include?(key)
				recon.send(key + "=", (datetime_parse(value) rescue nil) )
			end
		end
		recon.save

		@commit = params[:commit]
		@reconveyance = ReconTracking.new(recon.attributes) if @commit == "Save and Copy"

		respond_to do |format|
	    format.js { render 'recon_trackings/refresh' }
	  end
	end

	def new
		@file = Index.where("FileID" => params[:FileID]).first
	end

	def edit
		@reconveyance = ReconTracking.find params[:id]
		@file = @reconveyance.index

		respond_to do |format|
			format.js {render "recon_trackings/new"}
		end
	end

	def destroy
		recon = ReconTracking.find params[:id]
		recon.InActive = -1
		recon.save

		file_id = recon.FileID
		@file = Index.where("FileID = #{file_id}").first
		respond_to do |format|
	    format.js { render 'recon_trackings/refresh' }
	  end
	end

	def copy
		old_recon = ReconTracking.find params[:id]
		@file = Index.where("FileID = #{old_recon.FileID}").first
		@recon = ReconTracking.new
		@recon.employee_id = current_user.employee_id

		no_copy = ["id", "updated_at", "employee_id"]
		old_recon.attributes.each do |key, value|
			unless no_copy.include?(key)
				@recon.send(key + "=", value )
			end
		end

		respond_to do |format|
	    format.js { render 'recon_trackings/refresh' }
	  end
	end

	def refresh
		@file = Index.where("FileID = #{params[:FileID]}").first
		@refresh = 'refresh'
		respond_to do |format|
	    format.js { render 'recon_trackings/refresh' }
	  end
	end

	def get_beneficiary_info
		entity = Entity.find(params[:entity_id])
		address = entity.addresses.first
		if address != nil
			csz = address.City.to_s
			csz += csz != "" ? ", " + address.State.to_s : address.State.to_s
			csz += csz != "" ? " " + address.Zip.to_s : address.Zip.to_s
			render js: "$('#add_recon input[type=text]#BeneAddress').val('#{address.Address}');$('#add_recon input[type=text]#BeneAddress2').val('#{address.Address2}');$('#add_recon input[type=text]#BeneCSZip').val('#{csz}');"
		else
			render js: "addToQueue('', 'application/flash_notice?notice=No address found for this beneficiary. No action will be taken.');"
		end
	end
end
