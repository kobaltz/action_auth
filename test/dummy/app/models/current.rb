class Current < ActiveSupport::CurrentAttributes
  def user
    return unless ActionAuth::Current.user
    ActionAuth::Current.user.becomes(User)
  end
end
