class StandardRequirement < ActiveRecord::Base

  default_scope {where("removed_at IS NULL").order("sort_order ASC")}

  def text
    self.content.to_s.gsub(/\n/, "<br />").html_safe
  end

  def print_text
    self.content.to_s.gsub(/\n/, "<br />").gsub(/\^\[(.*?)\]\^/, "").html_safe
  end
end
