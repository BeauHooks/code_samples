class FileProductHistoriesController < ApplicationController
	def view
		file_product = FileProduct.find params[:file_product_id]
		@histories = file_product.file_product_histories.where("table_name = '#{params[:table_name]}' AND field_name = '#{params[:field_name]}' AND record_id = '#{params[:record_id]}'")
		@field_name = params[:field_name]
		@container = params[:container]
	end

	def update
		history = FileProductHistory.find params[:id]
		@value = history.nil? ? "" : history.new_value
		@field_name = params[:field_name]
		@container = params[:container]
		respond_to do |format|
			format.js
		end
	end

	def undo
		file_product = FileProduct.find params[:file_product_id]
		history = file_product.file_product_histories.where("table_name = '#{params[:table_name]}' AND field_name = '#{params[:field_name]}' AND record_id = '#{params[:record_id]}'").first
		@value = history.nil? ? "" : history.old_value
		@field_name = params[:field_name]
		@container = params[:container]

		respond_to do |format|
			format.js {render "update"}
		end
	end
end