class NewOrders::FilePropertiesController < NewOrdersController
  before_filter :set_default_county, :get_counties

  def create
    @file = Index.find(params[:new_order_id])
    @file_property = @file.file_properties.create
  end

  def destroy
    file_property = FileProperty.find(params[:id])
    file_property.destroy
    render nothing: true
  end

  def lookup_property
    @list = []
    county_condition = params.has_key?(:county_id) ? "AND CountyID = #{params[:county_id]}" : ""
    results = Taxroll1.where("#{params[:field]} LIKE '#{params[:term].to_s.gsub("'", "\\\\'")}%' #{county_condition}").order("#{params[:field]} ASC").limit(10)
    results.each do |r|
      @list << r.try(params[:field])
    end

    render text: @list
  end

  def fill_property_row
    property = Taxroll1.select("`taxroll1`.*, `taxroll2`.FullLegal").where("#{params[:field]}" => params[:value].to_s.gsub("'", "\\\\'").upcase, :CountyID => params[:county_id]).joins(:taxroll2).last
    render json: property
  end

  private

  def set_default_county
    @default_county = Company.find(session[:company]).DefaultCounty
  end

  def get_counties
    @counties = County.all
  end
end