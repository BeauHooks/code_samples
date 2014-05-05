class RecordingEntriesController < ApplicationController
  require 'RMagick'
  include Magick
  respond_to :html, :js, :json
  before_filter :set_county, :set_options, :set_field

  def index
    if params[:search]
      @search_results = RecordingEntry.search(params[:search_field],@county_id,params[:search],params[:date_from],params[:date_to])
      if params[:match] || params[:search_field] == "entrynumber"
        @match = set_match
      end
    else
      @search_results = nil
    end
    @detail = set_detail
    respond_with @search_results
  end

  def display_search_results
    @search_results = RecordingEntry.search(params[:search_field],@county_id,params[:search],params[:date_from],params[:date_to])
    if params[:match] || params[:search_field] == "entrynumber"
      @match = set_match
    end
    @detail = set_detail
    respond_with @search_results
  end

  def result_detail
    @detail = set_detail
  end

  def show_file
    recording_entry = RecordingEntry.find(params[:id])
    file = recording_entry.get_file
    if Pathname.new(file).exist?
      unless File.exist?("tmp/recording/#{recording_entry.entrynumber.to_i}.pdf")
        `tiff2pdf -o 'tmp/recording/#{recording_entry.entrynumber.to_i}.pdf' #{file.to_s}`
      end
      send_file "tmp/recording/#{recording_entry.entrynumber.to_i}.pdf"
    else
      send_file PropertyLookupModule::Engine.root.join("app","assets","images","property_lookup_module","no_image_available.jpg"), :disposition => 'inline'
    end
  end

  private

    def set_county
      if params[:county_id]
        @county_id = params[:county_id]
      else
        @county_id = current_user.county ||= 4 # Washington County
      end
    end

    def set_field
      if params[:search_field]
        @search_field = params[:search_field]
      else
        @search_field = 'fromparty-toparty'
      end
    end

    def set_match
      if params[:id]
        RecordingEntry.find(params[:id])
      else
        nil
      end
    end

    def set_detail
      if params[:id]
        RecordingEntry.find(params[:id])
      else
        unless @search_results.blank?
          @search_results.first
        else
          nil
        end
      end
    end

    def set_options
      @select_options = RecordingEntry::SELECT_OPTIONS
      @search_display = RecordingEntry::SEARCH_DISPLAY
    end
end
