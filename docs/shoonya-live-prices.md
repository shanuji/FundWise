# Shoonya live-price integration (personal EquityBasket)

## Scope

Shoonya is a read-only quote provider for EquityBasket. Buy/sell transactions and holdings remain in EquityBasket; all orders continue to be placed manually in Zerodha. Do not call Shoonya order endpoints or read Shoonya positions/trades.

## Authentication prerequisite — do this before wiring the UI

Shoonya's current published documentation describes OAuth login, not a supported TOTP auto-login API. The user signs in on Shoonya's hosted page with User ID, password and TOTP; Shoonya redirects with a short-lived authorization code; the code is exchanged for a session token. Session tokens expire at the daily server reset. Tradetron's integrated vendor flow is not a credential or token API that a separate app can automatically reuse.

Before implementing the production login UI, obtain/confirm:
- Shoonya API client ID / app key and secret code for a personal OAuth client.
- The redirect URI registered for that client.
- Shoonya's current IP-whitelisting requirement for the client.
- A secure place to exchange the auth code for a token. Do not ship the secret code in an APK or commit it to GitHub. If exchange must originate from a whitelisted static IP, use a private backend on that IP; do not put credentials in GitHub Actions or a public endpoint.
- Confirm whether Shoonya permits this personal app's intended market-data usage under the account/API terms.

Do not ask the user to paste passwords, TOTP seed, secret code or session tokens into chat.

## Market-data protocol

- Connect to `wss://api.shoonya.com/NorenWSAPI/`.
- Authenticate the WebSocket with `uid`, `actid`, `source: API` and the current access token.
- Wait for successful connect acknowledgement before subscribing.
- Subscribe to the relevant `EXCHANGE|TOKEN` instrument keys (e.g. `NSE|token`), not just stock display symbols. Maintain an explicit symbol-to-token map; use Shoonya's instrument master/search to resolve symbols.
- First quote message (`tk`) is a snapshot; following `tf` messages are diffs and MUST be merged into the cached quote for that instrument.
- Reconnect with backoff and re-subscribe after every reconnect. Show quote timestamps and stale/disconnected status; keep manual prices as fallback.
- Use one WebSocket and batch subscriptions. Current documentation states up to 500 instrument tokens per connection.

## Implementation stages

1. Resolve account/app prerequisites and the approved OAuth redirect/token exchange.
2. Add secure local session storage and an explicit Connect/Disconnect control. Never log tokens.
3. Add this read-only streaming service and map each holding's exchange/token to a quote.
4. Recalculate portfolio metrics on ticks, persist last-good prices, and visibly mark stale prices.
5. Test market-open, session expiry, phone network changes, app background/resume, and failed token exchange.
6. Build and test the APK before publishing a release.

## Official docs

- https://www.shoonya.com/api-documentation/auth-overview
- https://www.shoonya.com/api-documentation/manual-authentication-oauth
- https://www.shoonya.com/api-documentation/websocket-overview
- https://www.shoonya.com/api-documentation/subscribe-market-feed
- https://www.shoonya.com/api-documentation/vendors-partners
