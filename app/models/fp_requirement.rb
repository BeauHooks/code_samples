class FpRequirement < ActiveRecord::Base

	before_save :update_related
  after_save  :save_history

  default_scope { where("removed_at IS NULL").order("sort_order ASC") }

  belongs_to :fp_exception
  belongs_to :file_product
  has_many   :file_product_histories, primary_key: :id, foreign_key: :record_id

  def update_related
  	if self.removed_by_changed?
  		self.removed_at = Time.now.to_s(:db)

      file_product = self.file_product
  		i = file_product.standard_requirements.size
  		file_product.fp_requirements.where("id != #{self.id}").each do |r|
  			r.sort_order = i += 1
  			r.save
  		end
  	end
  end

  def save_history
    history_fields = ["content", "fp_exception_id", "cleared_by", "sort_order"]
    self.changed.each do |key|
      if history_fields.include?(key) && !self.send(key + "_was").blank?
        FileProductHistory.create_history(self, key)
      end
    end
  end

  def text
    self.content.to_s.gsub(/\n/, "<br />").html_safe
  end

  def print_text
    self.content.to_s.gsub(/\n/, "<br />").gsub(/\^\[(.*?)\]\^/, "").html_safe
  end
 end