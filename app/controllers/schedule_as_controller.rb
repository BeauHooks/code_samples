class ScheduleAsController < ApplicationController
	def create
	end

	def update
		@schedule_a = ScheduleA.find params[:id]
		@updates = Hash.new
		check_boxes = ScheduleA.check_boxes
		time = Time.now.to_s(:db)

		params.each do |key, value|
			unless !@schedule_a.attributes.include?(key)
				if check_boxes.include?(key)
					case key
					when "land_address_verified_by"
						@schedule_a.land_address_verified_by = @schedule_a.send(key).nil? ? value : nil
						@schedule_a.land_address_verified_at = @schedule_a.land_address_verified_by.nil? ? nil : time
					else
						value = @schedule_a.send(key) == -1 ? 0 : -1
						@schedule_a.send(key + "=",  value)
					end
				else
					if value.include?("@")
			      vars = value.scan(/@[0-9A-Za-z]+/)
			      vars.each do |var|
			        alt = Alth.where("Shortcut = '#{var[1..-1].upcase}'").first
			        value = value.gsub("#{var}", alt.Response) unless alt.nil?
			      end
			      @value = value
			    end

			    if key == "effective_at"
			    	value = datetime_parse(value) rescue nil
			    end

					@schedule_a.send(key + "=", (value || nil) )
				end
			end
		end

		@schedule_a.updated_by = current_user.employee_id
		@schedule_a.updated_at = time
		@schedule_a.save
		@file_product = @schedule_a.file_product
		@stop_refresh = true if !(params.has_key?(:version_id) || params.has_key?(:underwriter_id) || params.has_key?(:effective_at))
		@container = params[:container]

		# Initialize Rate Calculator
		@rate_calculation = RateCalculation.initialize_from_file(@file_product.file_id, current_user.employee_id, @file_product.product_type.name, "pr", underwriter_id: @schedule_a.underwriter_id) if @rate_calculation.nil?
		@rate_calculation.import!

		# Fill Rate Calculator with information
		@schedule_a.policies.each do |p|
			if p.sort_order == 1
			  @rate_calculation.policy_1_amount       = p.amount
			  @rate_calculation.policy_1_is_developer = p.use_developer_rate?
			  @rate_calculation.policy_1_type         = p.policy_type.PolicyDescription
			else
			  @rate_calculation.policy_2_amount       = p.amount
			  @rate_calculation.policy_2_is_developer = p.use_developer_rate?
			  @rate_calculation.policy_2_is_refinance = p.is_refinance?
			  @rate_calculation.policy_2_type         = p.policy_type.PolicyDescription
			end
		end

		# Calculate rates
		@rate_calculation.save!
		@rate_calculation.calculate!

    # Update Premium amounts
    @rate_calculation.table.each do |t|
	  	if t[:underwriter_id] == @schedule_a.underwriter_id
	  		@schedule_a.policies.each do |p|
  		    case p.sort_order
		  		when 1
		  		  p.premium = t[:amount_1]
		  		  @rate_calculation.cleanup_endorsements!(1)
		  		when 2
		  			p.premium = t[:amount_2]
		  			@rate_calculation.cleanup_endorsements!(2)
		  		end
		  		p.save!
		  	end
	  		@stop_refresh = false
	  	end
	  end
	  @rate_calculation.destroy
	end
end
