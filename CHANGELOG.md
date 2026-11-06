# Changelog

## Unreleased

This release fixes serious security problems. **Everyone should upgrade**, especially if the `webauthn` gem is installed or SMS authentication is turned on. Please read [Upgrading](#upgrading) first, because a few changes can affect your app or its tests.

### Security

- **Passkey sign in didn't verify anything.** `Sessions::PasskeysController#create` looked up the credential ID and signed in as its owner without checking the signature or the challenge. Anyone who had a credential ID could sign in as that user. It's on by default when the `webauthn` gem is installed. It now verifies the signature, the challenge, the sign count and that the user was verified on the device.
- **SMS sign in could be used to take over other accounts.** A request with no phone number matched the first account without one, which set a code on that account and let the code be used to sign in to it. A request could also send `sms_code[]=` with a list of codes to try them all at once. Both are fixed. SMS authentication is off by default.
- **Magic links and SMS codes skipped the security key.** Accounts with a security key now have to use it after either one, as they do after a password.
- **Magic links could be used more than once.** A link worked as many times as anyone liked for 20 minutes, so one found in a mailbox, a forwarded email or a log could still sign in. A link now works once, even if it's clicked twice at the same moment, and using one uses up any others sent to that account. Opening a link now shows a page with a "Sign in" button, so mail scanners that open links don't use them up. Links also stop working when the account's email changes. Before, a link sent to the old address could still sign in and mark the new address as verified.
- **Someone could keep access to an account set up with another person's email address.** Anyone could sign up with an address they didn't own, or change their own account to it. When the address's real owner first signed in with a magic link, the account was marked as verified, but the password and any open sessions still worked for whoever set it up. That first magic link now replaces the password, ends every session and removes connected OAuth accounts. Security keys stay, and are still asked for.
- **Opening the email verification link was enough to verify an address.** Anyone could sign up with someone else's address and their own password. If the address's owner clicked the link in the email they were sent, or a mail scanner opened it, the account was verified and that password worked. The link now opens a page that asks for the account's password, so verifying takes both the link and the password. Wrong passwords on that page count towards account lockout.
- **Password reset links kept working after an email change.** A link sent to the old address could still be used, including by someone who had moved their account to another person's address. Links are now tied to the address they were sent to.
- **Deleting an account didn't ask for the password.** Anyone with access to a signed in browser could delete the account. It now requires the current password, with guesses limited per session. An account created through SMS has no password it could know, so it has to have signed in with a new code in the last 10 minutes instead.
- **WebAuthn challenges could be reused.** They're now used up on the first attempt, which matters most for synced passkeys, since they always report a sign count of 0 and that check can't catch a replay.
- **Session cookies were inconsistent.** Magic link, SMS and passkey sign ins left out the `secure` flag and ignored `insert_cookie_domain`, and most other paths ignored `insert_cookie_domain` too. Every path now sets the cookie in the same way. It's also `secure` on any HTTPS request, not only in production.
- **The password reset form revealed who has an account.** It now gives the same answer for every address.
- **Rate limits added** to magic link requests, SMS requests and code guesses (per client and per phone number), passkey sign in, password reset and verification requests, and changing your email. Before this, a six digit SMS code could be guessed as fast as requests could be sent.
- **WebAuthn scripts no longer load on pages with password fields.** They come from a third-party CDN, so they now load only on the three screens that use them. Stimulus was also pinned to an exact version. It previously loaded whatever version was newest.
- SMS codes come from `SecureRandom`, and CSRF protection is now on whether or not the app's defaults turn it on.

### Fixed

- A passkey registered through the normal flow often couldn't be used for passkey sign in, because registration didn't ask for a discoverable credential. Passkeys registered before this release may need to be registered again to be used without a password.
- Two step sign in couldn't work in an app whose `ApplicationController` requires sign in, because the WebAuthn controllers inherited from it by accident.
- Changing your email was impossible from the default form, which had no current password field. An unverified user can now also correct a mistyped address.
- Logging out another device also logged out the current one.
- Visiting the password screens, or submitting the email change form, while signed out raised an error instead of redirecting to sign in.
- Sign up, password change and password reset raised an error when the password was missing or Have I Been Pwned was unreachable. An outage now counts as "not pwned" and is logged.
- A blank new password could report success without changing anything when pwned checks were off.
- Invalid input on the magic link and SMS forms showed a generic error page. They now show the form with the problem.
- WebAuthn requests with a malformed body raised an error. They now get a 422.
- `edit_user_password_path` was declared as a view helper but didn't exist, and the `edit_password_path` documented in the README wasn't available in views. `edit_user_password_path` and `user_password_path` now work.
- `password_complexity_check = false` was ignored during sign up when pwned checks were on.
- The "Verify Email" link always showed "That email verification link is invalid".
- The magic link email had no plain text version, and the password reset one had HTML tags in its plain text version.
- WebAuthn failures now show a message on the page instead of doing nothing, and a security key nickname containing `&` or `#` is no longer cut off.
- WebAuthn works when the app's initializer never calls `ActionAuth.configure`.
- `pwned_enabled` and `webauthn_enabled` being set without the gem installed no longer raises an error.
- User agents over 255 characters no longer fail sign in on MySQL.
- `session_timeout = nil` turns off session expiry instead of raising an error.
- `bin/rails action_auth:install` added a second `mount` to an app whose existing one was written differently, such as at another path, which stopped the app from booting. It now leaves any existing mount alone.
- The gemspec said Rails 7.1 was supported, but `rate_limit` needs 7.2. It now says `>= 7.2`, and CI tests 7.2, 8.0 and 8.1.

### Added

- **OAuth.** Sign in with Google, GitHub, Facebook, X or any other [OmniAuth](https://github.com/omniauth/omniauth) strategy. It's opt in, like WebAuthn: add the gems and at least one `config.oauth_provider`. People can connect and disconnect providers from the management screen. A matching email address never signs anyone in to an existing account. See [OAuth](README.md#oauth).
- **Account lockout, on by default.** 10 failed passwords or SMS codes in a row lock an account for 30 minutes, and its owner is sent an email. Magic links, passkeys, OAuth and existing sessions keep working. See [Account Lockout](README.md#account-lockout).
- **Account suspension, on by default, but only your app can suspend anyone.** `user.suspend_account!` blocks every way of signing in and signs them out everywhere. See [Account Suspension](README.md#account-suspension).
- `bin/rails generate action_auth:views` copies the views into your app, either all of them or just the groups you name, with `--layout` to include the layout.
- `config.layout` renders the screens in your app's layout. Your route helpers work there without a `main_app.` prefix.
- `config.parent_controller` makes ActionAuth's controllers inherit from your `ApplicationController`, so your helpers work. Its `authenticate_user!` filter is skipped where it has to be.
- `config.after_sign_in_path` and `config.after_sign_out_path`.
- Partials to override one piece at a time: `shared/_flash`, `shared/_errors`, `shared/_links`, `sessions/_sessions`, `sessions/_security_keys` and `sessions/_account`.
- The `action_auth_links` and `action_auth_webauthn_tags` helpers, and the `action_auth_controller?` predicate.
- Links to change email, change password and delete the account on the management screen, which also marks the current device.
- Sprockets apps no longer need to add ActionAuth's assets to `manifest.js`.

### Changed

- Password resets now work on unverified accounts, so an address's owner can always take over an account set up with it. Finishing one also verifies the address, ends every session and removes connected OAuth accounts. Security keys stay.
- After changing a password or an email you're sent to the management screen, since you're still signed in. With `verify_email_on_sign_in` off, signing up goes to `after_sign_in_path`.
- A session is only written to once a minute at most, not on every request.
- The redirects after `PATCH` and `DELETE` requests use `303 See Other`, which Turbo needs.

### Upgrading

See [Upgrading](README.md#upgrading) in the README for the commands to run and the settings you can add.

- **There are new migrations.** Run this, or magic link requests will raise an error telling you to:

  ```bash
  bin/rails action_auth:install:migrations
  bin/rails db:migrate
  ```

  Nothing else breaks while they're waiting to run, such as during a deploy. Lockout and suspension just do nothing until then, and `suspend_account!` raises an error instead of appearing to work.
- **Accounts now lock after too many failed sign ins.** Set `config.account_lockout_enabled = false` to turn this off, including if your tests fail a sign in 10 times for one user. The email it sends uses the same mail setup as your other ActionAuth emails. If it can't be sent, the problem is logged and sign in carries on.

- **Your delete account button needs a password field.** If you used the `button_to` from the README, it will now send people to the management screen with a message instead of deleting the account. That screen has a working form, so you can link to it instead, or see [Account Deletion](README.md#account-deletion) for a form to use.
- **Magic links now take a second click**, on the "Sign in" button. Links in emails sent before you upgrade stop working, so those people will need to request a new one. If you test the flow, `POST` the token to `magics_sign_ins_path` instead of opening the link. To restyle the new page, override `magics/sign_ins/show`.
- **Verifying an email now asks for the password.** The link opens a page with a password field, and submitting it verifies the address. Links already sent keep working, and go to the new page. If your tests open the link and expect the address to be verified, `PATCH` the token and password instead: `patch identity_email_verification_path, params: { sid: token, password: password }`. To restyle the new page, override `identity/email_verifications/show`.
- **Password reset links sent before you upgrade stop working**, because they're now tied to the address. They only last 20 minutes, so people can simply request another.
- **The first magic link on an unverified account replaces its password**, signs it out everywhere else and removes its connected OAuth accounts. The page with the "Sign in" button warns them first, and they can use Reset Password afterwards to choose a new password. There's no way to tell a stranger's password from the owner's at that point, so this applies to everyone. If you run with `verify_email_on_sign_in = false`, expect it to reach most of your password users, because nothing else verifies them. If your tests sign in with a magic link and then use the password, or count sessions, verify the user first.
- **Your test suite may need a change.** Password complexity, session timeouts and `same_site` used to be skipped when `Rails.env.test?`. If your tests create users with simple passwords, turn the check off in your test environment, or use stronger passwords:

  ```ruby
  config.password_complexity_check = !Rails.env.test?
  ```

- **If you copied views into your app**, compare them with the new ones (`bin/rails generate action_auth:views` shows the differences):
  - A copied `identity/emails/edit` needs a `password_challenge` field, or changing an email will keep failing.
  - A copied `sessions/index` keeps working but won't get the new links.
  - If you turn on OAuth, copied `sessions/new`, `registrations/new` and `sessions/index` views need the partials for it. See [Your own views](README.md#your-own-views).
- **If you copied the layout**, it keeps working. You can remove the WebAuthn tags and script from it, and add `<%= action_auth_webauthn_tags %>` to any custom WebAuthn view instead.
- **If you have your own WebAuthn JavaScript**, passkey sign in now answers with `{ "status": "ok", "redirect_url": "..." }` or a 422, rather than a redirect. Error bodies are now fixed messages rather than including the library's error.
- **Flash messages** are now displayed by the views. If your layout also displays them it won't show them twice, but the view's version is the one shown. To use your layout's styling, make `app/views/action_auth/shared/_flash.html.erb` an empty file.
- **Rate limits need a working cache.** They use `config.cache_store`, and `:null_store` turns them off. With several server processes, use a shared store such as Solid Cache or Redis.
- `GET /sessions/:id` was routed but had no action, and has been removed.
- CI no longer runs on Ruby 3.2, which has reached end of life.
