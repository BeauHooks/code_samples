class BaseProductException < ActiveRecord::Base

	default_scope { where("removed_at IS NULL").order("sort_order ASC") }

  belongs_to :base_product
	has_many   :base_product_requirements

end
