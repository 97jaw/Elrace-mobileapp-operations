# Hub QR Login v2

## Mobile contract

The scanner accepts only the server-generated JSON payload below:

```json
{
  "type": "rcc_hub_login",
  "version": 2,
  "challenge": "rcc_<43 base64url characters>",
  "expires_at": "<ISO-8601 UTC>"
}
```

RCC Mobile sends its existing JWT to Odoo and posts only the public challenge:

```http
POST https://erp.elrace.com/api/hub/qr-login
Authorization: Bearer <current RCC Mobile JWT>
Content-Type: application/json

{"code":"<challenge>"}
```

The app never sends `odoo_id`, calls the Hub approval endpoint directly, stores
the Odoo/Hub HMAC secret, or receives a Hub web token. Odoo derives the user
identity from the authenticated JWT and performs the signed server-to-server
approval.

## Compatibility and rollout

- Minimum QR v2 client: `1.0.26+91` (Android 7.0+/API 24 and iOS 16+).
- Release `1.0.26` to the trusted Android/iOS test channel before enabling QR
  on Hub staging.
- After test-channel approval, set the existing Odoo mobile-version policy to
  require at least `1.0.26` before enabling QR in production. The app's update
  service already supports `minVersion`/`min_version` enforcement.
- Until the supported-client population is confirmed, keep
  `HUB_SIGNIN_CODE_LOGIN_ENABLED=false`. Microsoft SSO remains the fallback and
  is not affected by the mobile release.

## Expected outcomes

- A JSON-RPC response is successful only when `result.status == "success"` or
  `result.success == true`; HTTP 200 alone is not success.
- Missing/expired JWT asks the user to sign in again.
- Expired and already-used QR challenges show distinct retry guidance.
- One transient connection/timeout failure is retried once. Normal responses
  are never submitted twice, repeated scan callbacks are locked by the scanner,
  and closing the scanner cancels an in-flight request.
- Legacy plain-text, URL, and v1 payloads are rejected locally.
