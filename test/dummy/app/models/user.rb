class User < ActionAuth::User
  has_many :posts, dependent: :destroy
end
