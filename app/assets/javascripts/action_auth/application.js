import { Application, Controller } from "https://unpkg.com/@hotwired/stimulus@3.2.2/dist/stimulus.js";
import * as WebAuthnJSON from "https://unpkg.com/@github/webauthn-json@2.1.1/dist/esm/webauthn-json.js";

const application = Application.start();

const GENERIC_ERROR = "Something went wrong. Please try again.";

const Credential = {
  csrfToken: function () {
    const selector = document.querySelector('meta[name="csrf-token"]');
    return selector ? selector.getAttribute("content") : null;
  },

  showError: function (message) {
    const element = document.getElementById("webauthn_error");
    if (element) {
      element.textContent = message;
      element.hidden = false;
    }
    console.error("[ActionAuth]", message);
  },

  callback: function (url, body, redirectUrl) {
    const self = this;
    return fetch(url, {
      method: "POST",
      body: JSON.stringify(body),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": self.csrfToken()
      },
      credentials: "same-origin"
    }).then(async function (response) {
      if (response.ok) {
        const data = await response.json().catch(() => ({}));
        window.location.replace(data.redirect_url || redirectUrl);
      } else if (response.status < 500) {
        self.showError((await response.text()) || GENERIC_ERROR);
      } else {
        self.showError(GENERIC_ERROR);
      }
    });
  },

  create: function (callbackUrl, credentialOptions) {
    const self = this;
    const redirectUrl = document.querySelector('meta[name="webauthn_redirect_url"]').getAttribute("content");
    return WebAuthnJSON.create({ "publicKey": credentialOptions })
      .then((credential) => self.callback(callbackUrl, credential, redirectUrl))
      .catch((error) => self.showError(error.message || GENERIC_ERROR));
  },

  get: function (credentialOptions) {
    const self = this;
    const urlTag = document.querySelector('meta[name="passkey_auth_url"]') ||
      document.querySelector('meta[name="webauthn_auth_url"]');
    return WebAuthnJSON.get({ "publicKey": credentialOptions })
      .then((credential) => self.callback(urlTag.getAttribute("content"), credential, "/"))
      .catch((error) => self.showError(error.message || GENERIC_ERROR));
  }
};

application.register(
  "add-credential",
  class extends Controller {
    // Attached here rather than on page load so it also works when Turbo brings
    // the form in, and so it wins over Turbo's own form handling.
    connect() {
      this.submit = this.submit.bind(this);
      this.element.addEventListener("submit", this.submit);
    }

    disconnect() {
      this.element.removeEventListener("submit", this.submit);
    }

    submit(event) {
      event.preventDefault();
      const form = this.element;

      fetch(form.action, {
        method: "POST",
        body: new FormData(form),
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": Credential.csrfToken()
        },
        credentials: "same-origin"
      }).then((response) => {
        if (!response.ok) { throw new Error(GENERIC_ERROR); }
        return response.json();
      }).then((data) => {
        form.dispatchEvent(new CustomEvent("ajax:success", { detail: data }));
      }).catch((error) => Credential.showError(error.message || GENERIC_ERROR));
    }

    create(event) {
      const webauthnUrl = document.querySelector('meta[name="webauthn_cred_url"]').getAttribute("content");
      const nickname = event.target.querySelector("input[name='webauthn_credential[nickname]']").value;
      const callbackUrl = `${webauthnUrl}?credential_nickname=${encodeURIComponent(nickname)}`;
      Credential.create(callbackUrl, event.detail);
    }
  }
);

application.register(
  "credential-authenticator",
  class extends Controller {
    static values = { options: Object }

    connect() {
      if (this.hasOptionsValue) {
        Credential.get(this.optionsValue);
      }
    }
  }
);
