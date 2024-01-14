class Current < ActiveSupport::CurrentAttributes
  def user
    User.find_by(id: ActionAuth::Current.user&.id)
  end
end
