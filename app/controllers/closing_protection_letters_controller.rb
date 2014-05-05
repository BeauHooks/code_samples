class ClosingProtectionLettersController < ApplicationController
  require 'base64'

  def index
    @cpls = ClosingProtectionLetter.all
  end

  def new
    file = Index.find(params[:id])
    @cpl = ClosingProtectionLetter.create(file: file, company_id: file.Company)
    @cpl.cpl_gather_data(file)
  end

  def show
    @cpl = ClosingProtectionLetter.find(params[:id])
  end

  def edit
    @cpl = ClosingProtectionLetter.find(params[:id])
    @cpl.cpl_update_data(@cpl.file)
  end

  def update
    @cpl = ClosingProtectionLetter.find(params[:id])
    @cpl.updated_by = current_user
    @cpl.update_attributes(params[:closing_protection_letter])
  end

  def create
    @cpl = ClosingProtectionLetter.create(params[:closing_protection_letter])
    @cpl.update_attributes(created_by: current_user)
    render nothing: true
  end

  def submit_cpl_order
    @cpl = ClosingProtectionLetter.find(params[:id])
    response = @cpl.submit_cpl_order
    @cpl.parse_order_response(response,current_user)
    @cpl.save_cpl_pdf(response,random_string)
  end

  def fatco_submit_cpl_order
    @cpl = ClosingProtectionLetter.find(params[:id])
    response = @cpl.fatco_submit_cpl_order
    # @cpl.parse_order_response(response,current_user)
    # @cpl.save_cpl_pdf(response,random_string)
  end

  def fatco_rate_request
    @cpl = ClosingProtectionLetter.find(params[:id])
    response = @cpl.fatco_rate_request
  end

  def display_image
    @cpl = ClosingProtectionLetter.find(params[:id])
    @cpl_image = FileImage.find(@cpl.file_image_id)
    path = File.expand_path("#{@cpl_image.tempfile}.pdf", "#{Rails.root}/tmp/cpl/")
    send_file(path, filename: "cpl.pdf", disposition: "inline")
  end

  def get_lookup_data
    @cpl = ClosingProtectionLetter.find(params[:id])
    response = @cpl.get_lookup_data
    @cpl.parse_lookup_response(response,current_user)
  end

  def find_cpl_by_order_number
    @cpl = ClosingProtectionLetter.find(params[:id])
    response = @cpl.find_cpl_by_order_number
    @cpl.parse_find_response(response,current_user)
  end

  def close_cpl
    @cpl = ClosingProtectionLetter.find(params[:id])
    response = @cpl.close_cpl
    @cpl.parse_close_response(response,current_user)
  end

  def cancel_cpl
    @cpl = ClosingProtectionLetter.find(params[:id])
    response = @cpl.cancel_cpl
    @cpl.parse_cancel_response(response,current_user)
  end

  def update_cpl
    @cpl = ClosingProtectionLetter.find(params[:id])
    response = @cpl.update_cpl
    @cpl.parse_update_response(response,current_user)
    @cpl.save_cpl_pdf(response,random_string)
  end

end