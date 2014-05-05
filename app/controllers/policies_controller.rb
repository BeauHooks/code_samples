class PoliciesController < ApplicationController

	def index

	end

	def new # also create
		schedule_a = ScheduleA.find params[:schedule_a_id]
		policy = Policy.new
		policy.schedule_a_id = params[:schedule_a_id]
		policy.sort_order = schedule_a.policies.size + 1
		policy.created_by = current_user.employee_id
		policy.created_by = current_user.employee_id
		policy.created_at = Time.now.to_s(:db)
		policy.updated_at = Time.now.to_s(:db)
		policy.save

		@schedule_a = ScheduleA.find params[:schedule_a_id]
		@file_product = @schedule_a.file_product
		@policies = @file_product.policies

		# Setup Rate Calculator
		@rate_calculation = RateCalculation.find(session[:rate_calculation_id]) rescue nil
		@rate_calculation = RateCalculation.initialize_from_file(@file_product.file_id, current_user.employee_id, @file_product.product_type.name, "pr") if @rate_calculation.nil?
		@rate_calculation.import!
    @rate_calculation.cleanup_endorsements!(1)
    @rate_calculation.cleanup_endorsements!(2)
    @rate_calculation.save!
    @rate_calculation.calculate!
	end

	def update
		@policy = Policy.find params[:id]

		params.each do |key, value|
			unless !@policy.attributes.include?(key)
				if value.include?("@")
		      vars = value.scan(/@[0-9A-Za-z]+/)
		      vars.each do |var|
		        alt = Alth.where("Shortcut = '#{var[1..-1].upcase}'").first
		        value = value.gsub("#{var}", alt.Response) unless alt.nil?
		      end
		      @value = value
		    end

		    if Policy.checkboxes.include?(key)
					value = @policy.send(key) != -1 ? -1 : 0
				end

				@policy.send(key + "=", (value || nil) )
			end
		end

		if params.has_key?(:sort_order)
			schedule_a = @policy.schedule_a
			policies = schedule_a.policies.where("id != #{@policy.id}")
			current = 1

			@policy.sort_order = current if @policy.sort_order < current

			policies.each do |p|
				p.sort_order = current

				if p.sort_order == @policy.sort_order
					p.sort_order = current += 1
				end
				p.save
				current += 1
			end

			@policy.sort_order = current if @policy.sort_order > current
			@policy.save
		end

		@policy.save
		@schedule_a = @policy.schedule_a
		@file_product = @schedule_a.file_product
		@stop_refresh = true if !params.has_key?(:sort_order)
		@container = params[:container]

		# Calculate rates
		@rate_calculation = RateCalculation.initialize_from_file(@file_product.file_id, current_user.employee_id, @file_product.product_type.name, "pr", underwriter_id: @schedule_a.underwriter_id) if @rate_calculation.nil?
		@rate_calculation.import!
    @rate_calculation.cleanup_endorsements!(1)
    @rate_calculation.cleanup_endorsements!(2)
    @rate_calculation.save!
    @rate_calculation.calculate!

		if @policy.sort_order == 1
			case params[:container]
			when "amount"
		    @policy.amount = params[:amount]
		  when "use_developer_rate"
		  	@is_developer = params[:use_developer_rate] == "true" ? true : false
		  	@policy.use_developer_rate = @is_developer
		  when "policy_policy_type_id"
		  	@policy_type = PolicyType.find params[:policy_type_id]
		  	@rate_calculation.policy_1_type = @policy_type.PolicyDescription
		  end
		  @rate_calculation.policy_1_amount       = params[:amount] || @policy.amount
		  @rate_calculation.policy_1_is_developer = @is_developer || @policy.use_developer_rate?
		  @rate_calculation.policy_1_type         = @policy_type.nil? ? @policy.policy_type.PolicyDescription : @policy_type.PolicyDescription
		else
			case params[:container]
			when "amount"
		    @policy.amount = params[:amount]
		  when "use_developer_rate"
		  	@is_developer = params[:use_developer_rate] == "true" ? true : false
		  	@policy.use_developer_rate = @is_developer
		  when "is_refinance"
		  	@is_refinance = params[:is_refinance] == "true" ? true : false
		  	@policy.is_refinance = @is_refinance
		  when "policy_policy_type_id"
		  	@policy_type = PolicyType.find params[:policy_type_id]
		  	@policy.policy_type_id = @policy_type.ID
		  end
		  @rate_calculation.policy_2_amount       = params[:amount] || @policy.amount
		  @rate_calculation.policy_2_is_developer = @is_developer || @policy.use_developer_rate?
		  @rate_calculation.policy_2_is_refinance = @is_refinance || @policy.is_refinance?
		  @rate_calculation.policy_2_type         = @policy_type.nil? ? @policy.policy_type.PolicyDescription : @policy_type.PolicyDescription
		end

    @rate_calculation.save!
    @rate_calculation.calculate!
	  logger.info @rate_calculation.table
	  @rate_calculation.table.each do |t|
	  	if t[:underwriter_id] == @schedule_a.underwriter_id
	  		case @policy.sort_order
	  		when 1
	  		  @policy.premium = t[:amount_1]
	  		when 2
	  			@policy.premium = t[:amount_2]
	  		end
	  		@policy.save!
	  		@stop_refresh = false
	  	end
	  end
	  @rate_calculation.destroy
	end

	def destroy
		policy = Policy.find params[:id]
		@schedule_a = policy.schedule_a
		@file_product = @schedule_a.file_product
		policy.destroy
		respond_to do |format|
      format.js {render "update"}
    end
	end
end