class FpExceptionsController < ApplicationController
	include ActionView::Helpers::NumberHelper
	def index
		@exception = FpException.find params[:id]
		@file_product = @exception.file_product
	end

	def new
		@file_product = FileProduct.find params[:file_product_id]
		@exception = FpException.new
	end

	def create
		content = nil
		time = Time.now.to_s(:db)
		file_product = FileProduct.find(params[:file_product_id])
		exception = FpException.new
		exception.file_product_id = params[:file_product_id]
		exception.sort_order = file_product.all_exceptions.size + 1
		exception.created_by = current_user.employee_id
		exception.updated_by = current_user.employee_id
		exception.created_at = time
		exception.updated_at = time

		unless params[:entry_number].blank?
			entry = ExceptionEntry.where("EntryNum = #{params[:entry_number]} AND CountyID = #{file_product.index.county_id}").first

			unless entry.nil?
				case entry.source
				when "import"
					import = ImportScheduleB.where("ID = #{entry.ExceptionID}").first
				when "file"
					import = FileException.where("ID = #{entry.ExceptionID}").first
				when "new"
					import = ScheduleBException.where("ExceptionUniqueID = #{entry.ExceptionID}").first
				end

				exception.content = file_product.find_replace(import.ExceptionText) unless import.nil?
			end
		end

		if exception.content.blank?
			unless params[:exception_template_id].blank?
				template = ExceptionTemplate.find(params[:exception_template_id])
			else
				koi = RecordingKoi.find(:all, joins: [:recording_entries], conditions: ["tblUTEntry.entrynumber = '#{params[:entry_number]}' AND CountyID = #{file_product.index.county_id}"] ).first
				exception_type = koi.nil? ? params[:exception_type] : koi.ExceptionType
				template = ExceptionTemplate.where("ExceptionType = '#{exception_type}'").first
			end

			unless params[:entry_number].blank? || template.blank?
				entry = RecordingEntry.where("entrynumber = '#{params[:entry_number]}' AND CountyID = #{file_product.index.county_id}").first
				exception.content = file_product.find_replace(template.ExceptionText, entry)
			else
				exception.content = file_product.find_replace(template.ExceptionText) unless template.blank?
			end
		end
		
		exception.content = "{{ExceptionText}}" if exception.content.blank?
		exception.save

		unless template.blank? || template.requirement_template.blank?
			@requirement_template_code = template.requirement_template.template_code
			@fp_exception_id = exception.id
			@entry_number = params[:entry_number]
		end

		@create = true
		@file_product = exception.file_product
		respond_to do |format|
			format.js {render "update"}
		end
	end

	def editor
		@exception = FpException.find params[:id]
		@view = params[:view]
	end

	def update
		@exception = FpException.find params[:id]
		file_product = @exception.file_product
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

				unless !@exception.attributes.include?(key)
					@exception.send(key + "=", (value || nil) )
				end
			end

			if params.has_key?(:sort_order)
				current = file_product.standard_exceptions.size + 1
				exceptions = file_product.fp_exceptions.where("id != #{@exception.id}")

				@exception.sort_order = current if @exception.sort_order < current

				exceptions.each do |e|
					e.sort_order = current

					if e.sort_order == @exception.sort_order
						e.sort_order = current += 1
					end
					e.save
					current += 1
				end

				@exception.sort_order = current if @exception.sort_order > current
			end

			@exception.updated_by = current_user.employee_id
			@exception.updated_at = Time.now.to_s(:db)
			@exception.save
		end

		@file_product = FileProduct.find file_product.id
		@view = params[:view]
		@stop_refresh = true unless params.has_key?(:confirm) || params.has_key?(:sort_order) || params.has_key?(:removed_by)
		@update_content = true if params.has_key?(:content)
	end

	def get_exception_number
		file_product = FileProduct.find params[:file_product_id]
		content = ""

		if params[:entry_number] == "" && params[:exception_type] == ""
			render nothing: true
			return
		end

		exception_type = RecordingKoi.find(:all, joins: [:recording_entries], conditions: ["tblUTEntry.entrynumber = '#{params[:entry_number]}' AND CountyID = #{file_product.index.county_id}"] ).first.ExceptionType rescue nil		
		exception_type =  params[:exception_type] if exception_type.blank?
		template = ExceptionTemplate.where("ExceptionType = '#{exception_type}'").first

		if template.nil?
			render js: "
				$('#exception_template_id').val(''); 
				addToQueue('exception_error', 'application/flash_notice?notice=Could not find exception template. If you feel like you received this message in error, please contact tech support.');
			"
		else
			render js: "
				$('#exception_template_id').val('#{template.ID}');
				$('#exception_type').val('#{exception_type}');
				$('#exception_type').focus();
			"
		end
	end
end
