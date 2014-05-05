class PolicyEndorsementsController < ApplicationController
	def new
		@policy = Policy.find params[:policy_id]
		@schedule_a = @policy.schedule_a

		if @schedule_a.endorsement_options.size == 0
			render js: "addToQueue('endorsement_error', 'application/flash_notice?title=Error&notice=No endorsement options found. Please ensure that you have chosen an underwriter and version on Schedule A.');"
		else
			@endorsement = PolicyEndorsement.new
			respond_to do |format|
				format.js {render "show"}
			end
		end
	end

	def edit
		@policy = Policy.find params[:policy_id]
		@endorsement = PolicyEndorsement.find params[:id]
		respond_to do |format|
			format.js {render "show"}
		end
	end

	def create
		@policy = Policy.find params[:policy_id]
		@schedule_a = @policy.schedule_a
		@file_product = @schedule_a.file_product
		@rate_calculation = RateCalculation.initialize_from_file(@file_product.file_id, current_user.employee_id, @file_product.product_type.name, "pr", underwriter_id: @schedule_a.underwriter_id) if @rate_calculation.nil?
		@rate_calculation.import!
    @rate_calculation.save!
    @rate_calculation.calculate!

    if !params[:endorsement].empty?
      @rate_calculation.add_endorsement!(@policy.sort_order, params[:endorsement])
    end

    if !params[:endorsement_group].empty?
    	@rate_calculation.add_endorsement_group!(@policy.sort_order, params[:endorsement_group])
    end

		# endorsement = PolicyEndorsement.new
		# params[:policy_endorsement].each do |key, value|
		# 	unless !endorsement.attributes.include?(key)
		# 		endorsement.send(key + "=", (value || nil) )
		# 	end
		# end
		# endorsement.updated_by = current_user.employee_id
		# endorsement.created_by = current_user.employee_id
		# endorsement.updated_by = Time.now.to_s(:db)
		# endorsement.created_at = Time.now.to_s(:db)
		# endorsement.save

		respond_to do |format|
			format.js {render "update_policy_endorsements"}
		end
	end

	def update
		endorsement = PolicyEndorsement.find params[:id]
		params[:policy_endorsement].each do |key, value|
			unless !endorsement.attributes.include?(key)
				endorsement.send(key + "=", (value || nil) )
			end
		end
		endorsement.updated_by = current_user.employee_id
		endorsement.updated_by = Time.now.to_s(:db)
		endorsement.save
		render nothing: true
	end

	def destroy
		endorsement = PolicyEndorsement.find params[:id]
		endorsement.removed_by = current_user.employee_id
		endorsement.removed_at = Time.now.to_s(:db)
		endorsement.save
		render nothing: true
	end
end
