class FpRequirementsController < ApplicationController
	def index
		@requirement = FpRequirement.find params[:id]
		@file_product = @requirement.file_product
	end

	def new
		@file_product = FileProduct.find params[:file_product_id]
		@requirement = FpRequirement.new
		@fp_exception_id = params[:fp_exception_id]
		@requirement_template_code = params[:requirement_template_code]
		@entry_number = params[:entry_number]
	end

	def create
		exception = FpException.find(params[:fp_exception_id]) unless params[:fp_exception_id].blank?
		file_product = FileProduct.find params[:file_product_id]

		requirement = FpRequirement.new
		requirement.file_product_id = file_product.id
		requirement.fp_exception_id = params[:fp_exception_id] unless params[:fp_exception_id].blank?
		requirement.sort_order = file_product.all_requirements.size + 1
		requirement.created_by = current_user.employee_id
		requirement.updated_by = current_user.employee_id
		requirement.created_at = Time.now.to_s(:db)
		requirement.updated_at = Time.now.to_s(:db)
		
		if !params[:requirement_template_id].blank?
			template = RequirementTemplate.find(params[:requirement_template_id])
		elsif !params[:template_code].blank?
			template = RequirementTemplate.where("template_code = '#{params[:template_code]}'").first
		end

		unless params[:entry_number].blank? || template.blank?
			entry = RecordingEntry.where("entrynumber = '#{params[:entry_number]}' AND CountyID = #{file_product.index.county_id}").first
			requirement.content = file_product.find_replace(template.template_text, entry)
		else
			requirement.content = file_product.find_replace(template.template_text) unless template.blank?
		end

		requirement.save

		@create = true
		@file_product = FileProduct.find params[:file_product_id]
		respond_to do |format|
			format.js {render "update"}
		end
	end

	def editor
		@requirement = FpRequirement.find params[:id]
		@view = params[:view]
	end

	def update
		@requirement = FpRequirement.find params[:id]
		file_product = @requirement.file_product
		unless params.has_key?(:confirm) && params[:confirm] == "Cancel"
			params.each do |key, value|
				if key == "content" && value.include?("@")
		      vars = value.scan(/@[0-9A-Za-z]+/)
		      vars.each do |var|
		        alt = Alth.where("Shortcut = '#{var[1..-1].upcase}'").first
		        value = value.gsub("#{var}", alt.Response) unless alt.nil?
		      end
		      @value = value
		    end

				unless !@requirement.attributes.include?(key)
					@requirement.send(key + "=", (value || nil) )
				end
			end

			if params.has_key?(:sort_order)
				current = file_product.standard_requirements.size + 1
				requirements = file_product.fp_requirements.where("id != #{@requirement.id}")

				@requirement.sort_order = current if @requirement.sort_order < current

				requirements.each do |r|
					r.sort_order = current
					
					if r.sort_order == @requirement.sort_order
						r.sort_order = current += 1
					end
					
					r.save
					current += 1
				end

				@requirement.sort_order = current if @requirement.sort_order > current
			end

			@requirement.updated_by = current_user.employee_id
			@requirement.updated_at = Time.now.to_s(:db)
			@requirement.save
		end

		@file_product = FileProduct.find file_product.id
		@view = params[:view]
		@stop_refresh = true unless params.has_key?(:confirm) || params.has_key?(:sort_order) || params.has_key?(:removed_by)
		@update_content = true if params.has_key?(:content)
	end
end
