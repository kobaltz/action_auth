ActionAuth.configure do |config|
  config.webauthn_enabled = true
  config.webauthn_origin = 'http://localhost:3000'
  config.webauthn_rp_name = "Example Inc."
end
