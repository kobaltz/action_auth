module ActionAuth
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true
  end
end
