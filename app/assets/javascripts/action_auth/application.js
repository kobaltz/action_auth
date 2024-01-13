import { Application, Controller } from "https://unpkg.com/@hotwired/stimulus/dist/stimulus.js";
window.Stimulus = Application.start();

import * as WebAuthnJSON from 'https://unpkg.com/@github/webauthn-json@2.1.1/dist/esm/webauthn-json.js';
const Credential = {
  getCRFSToken: function () {
    const CSRFSelector = document.querySelector('meta[name="csrf-token"]');
    if (CSRFSelector) {
      return CSRFSelector.getAttribute("content");
    } else {
      return null;
    }
  },

  callback: function (url, body, redirectUrl) {
    const token = this.getCRFSToken();
    fetch(url, {
      method: "POST",
      body: JSON.stringify(body),
      headers: {
        "Content-Type": "application/json",
        "Accept": "application/json",
        "X-CSRF-Token": token
      },
      credentials: 'same-origin'
    }).then(function (response) {
      if (response.ok) {
        console.log("Credential created", response);
        window.location.replace(redirectUrl);
      } else if (response.status < 500) {
        response.text();
      }
    });
  },

  create: function (callbackUrl, credentialOptions) {
    const self = this;
    const webauthnRedirectUrl = document.querySelector('meta[name="webauthn_redirect_url"]').getAttribute("content");
    WebAuthnJSON.create({ "publicKey": credentialOptions }).then(function (credential) {
      self.callback(callbackUrl, credential, webauthnRedirectUrl);
    });
  },

  get: function (credentialOptions) {
    const self = this;
    const webauthnUrl = document.querySelector('meta[name="webauthn_auth_url"]').getAttribute("content");
    WebAuthnJSON.get({ "publicKey": credentialOptions }).then(function (credential) {
      self.callback(webauthnUrl, credential, "/");
    });
  }
};


Stimulus.register(
  "add-credential",
  class extends Controller {
    create(event) {
      const webauthnUrl = document.querySelector('meta[name="webauthn_cred_url"]').getAttribute("content");
      const credentialOptions = event.detail;
      const credential_nickname = event.target.querySelector("input[name='webauthn_credential[nickname]']").value;
      const callback_url = `${webauthnUrl}/?credential_nickname=${credential_nickname}`
      Credential.create(encodeURI(callback_url), credentialOptions);
    }
  }
);

Stimulus.register(
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

document.addEventListener('DOMContentLoaded', function () {
  const form = document.getElementById('webauthn_credential_form');
  if (form) {
    form.addEventListener('submit', function (event) {
      event.preventDefault();
      const formData = new FormData(form);
      fetch(form.action, {
        method: 'POST',
        body: formData,
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        credentials: 'same-origin'
      }).then(response => {
        return response.json();
      }).then(data => {
        form.dispatchEvent(new CustomEvent('ajax:success', { detail: data }));
      });
    });
  }
});
