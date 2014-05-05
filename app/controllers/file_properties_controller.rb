class FilePropertiesController < ApplicationController
  respond_to :html, :json, :js

  def index
  end

  def show
  end

  def new
  end

  def create
    @file = Index.find params[:index_id]
    @new_order = @file.is_destroyable?

    if params.has_key?(:property_id)
      property                       = Taxroll1.find params[:property_id]
      file_property                  = @file.file_properties.build
      file_property.FileID           = @file.FileID
      file_property.DisplayFileID    = @file.DisplayFileID
      file_property.TaxID            = property.serialnum
      file_property.LegalDescription = property.taxroll2.FullLegal
      file_property.PropertyAddress  = property.Address1
      file_property.City             = property.City
      file_property.State            = property.State
      file_property.Zip              = property.ZipCode
      file_property.CountyID         = property.CountyID
      file_property.AccountID        = property.accountnum
      file_property.DummyTime        = Time.now.to_s(:db)
      file_property.ParcelNum        = @file.file_properties.active.size + 1
      file_property.save!
    else
      @file.file_properties.create
    end
  end

  def edit
  end

  def update
    property = FileProperty.find params[:id]
    file     = property.index

    old_address = property.PropertyAddress
    property.update_attributes(property.dup.attributes.merge params.select { |k| property.dup.attributes.keys.include? k })

    if params.has_key?(:PropertyAddress)
      note               = file.file_notes.new
      note.FileID        = file.FileID
      note.DisplayFileID = file.DisplayFileID
      note.EnteredBy     = current_user.employee_id
      note.NoteDT        = Time.now.to_s(:db)
      note.NoteText      = "PROPERTY ADDRESS: #{old_address} TO: #{params[:PropertyAddress]}"
      note.save
    end
    render nothing: true
  end

  def destroy
    file_property = FileProperty.find params[:id]
    file_property.Inactive = -1
    file_property.save!

    @file = file_property.index
    i = 0
    @file.file_properties.active.order("ParcelNum ASC").each do |property|
      i += 1
      property.ParcelNum = i
      property.save!
    end
    @file_properties = @file.file_properties.includes(:taxroll1).active
  end

  def search
    @file = Index.find params[:index_id]
    @file_properties = []
    @file.file_properties.each {|p| @file_properties << p.TaxID}
    search = params[:search_value].gsub("'", "\\\\'").gsub("%", "").gsub("*", "%")
    if search != ""
      case params[:search_type]
      when "serialnum"
        conditions = "taxroll1.serialnum LIKE '#{search}%'"
      when "accountnum"
        conditions = "taxroll1.accountnum LIKE '#{search}%'"
      when "SitusAddress"
        conditions = "taxroll1.SitusAddress LIKE '#{search}%'"
      when "FullLegal"
        conditions = "taxroll2.FullLegal LIKE '%#{search}%'"
      when "OwnerName"
        conditions = "taxroll1.OwnerName LIKE '#{search}%'"
      when "Address1"
        conditions = "taxroll1.Address1 LIKE '#{search}%'"
      when "SubdivisionDescr"
        conditions = "taxroll3.SubdivisionDescr LIKE '#{search}%'"
      end

      if params[:search_county] != ""
        conditions == "" ? conditions += "taxroll1.CountyID=#{params[:search_county]}" : conditions += " AND taxroll1.CountyID=#{params[:search_county]}"
      end

      @properties = Taxroll1.find(:all, conditions: conditions, order: "taxroll1.serialnum", include: ["taxroll2", "taxroll3"], limit: "100")
    else
      @properties = []
    end
  end
end
