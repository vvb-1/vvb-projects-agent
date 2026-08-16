# HANDOVER — `vvb-crab-bot` GitHub App setup

Du är en lokal assistent på **VVB-HP15** (`krily@VVB-HP15`). Du har bash + python3 + git + gh. Du har INGEN direkt access till Crab/Hermes.

## Mål

Sätt upp `vvb-crab-bot` GitHub App för organisationen `vvb-1` via manifest-flödet. Manifestet är redan skapat.

## Förutsättningar

Verifiera innan du kör:

```bash
command -v python3 git gh openssl curl
gh auth status  # måste vara inloggad som vvb-1
```

## Befintliga artefakter (skapade av Crab)

Manifest och nyckel finns redan på denna host:

```bash
cat /tmp/vvb-crab-bot-manifest.json
# Innehåller: name=vvb-crab-bot, permissions (issues+PRs+contents+checks+metadata+members+plans), events (issue_comment, issues, pull_request, pull_request_review)

cat /home/krily/.config/vvb-bot/state.json
# Innehåller: app_name, org, key_path, manifest_path

ls -la /home/krily/.config/vvb-bot/private-key.pem
# RSA-4096 privat nyckel, chmod 600
```

## Arbetsflöde

### Steg 1 — Bestäm hostningsmetod för manifestet

GitHub's manifest-flöde kräver att manifestet är publikt åtkomligt via HTTPS. **Två alternativ:**

**A. Hostat på vivetbil.cc** (rekommenderat av Kristian):

```bash
# Logga in på vivetbil.cc (CF Pages eller annan hosting)
# Ladda upp manifestet:
scp /tmp/vvb-crab-bot-manifest.json user@vivetbil.cc:/path/to/webroot/manifests/vvb-crab-bot.json
# Verifiera att det är åtkomligt:
curl -fsS https://vivetbil.cc/manifests/vvb-crab-bot.json | head -20
```

**B. Inline base64 i URL:en (om A inte är möjligt):**

```bash
# Base64-encode manifestet utan radbrytningar
MANIFEST_B64=$(base64 -w 0 /tmp/vvb-crab-bot-manifest.json)
# GitHub tillåter tyvärr INTE denna approach — verifiera mot docs
# Om inte stödjs, använd A
```

### Steg 2 — Klicka deep-link

Öppna i webbläsaren:

```
https://github.com/settings/apps/new?code=https%3A%2F%2Fvivetbil.cc%2Fmanifests%2Fvvb-crab-bot.json
```

GitHub visar en bekräftelsesida. **Läs permissions noga** innan du klickar "Create". Klicka sedan.

### Steg 3 — Installera App:en på vvb-1

Efter App-skapande omdirigeras GitHub till installationssidan:

- Välj organisationen `vvb-1`
- Välj "All repositories" (eller kurera lista senare)
- Klicka Install

### Steg 4 — Hämta App-ID och Installation-ID

```bash
# Logga in med admin-scope om saknas
gh auth refresh -s admin:org,admin:user

# Hämta App-listan
gh api orgs/vvb-1/apps --jq '.[] | select(.slug=="vvb-crab-bot") | {id, slug, client_id}'

# Hämta installationer
gh api /user/installations --jq '.installations[] | select(.account.login=="vvb-1") | {id, account: .account.login}'
```

### Steg 5 — Generera installations-token

```bash
# Skapa token (10 min TTL, förnyas vid behov)
APP_ID="<från steg 4>"
INSTALLATION_ID="<från steg 4>"
PRIVATE_KEY="/home/....pem"

python3 <<EOF
import jwt, time, requests, json
with open("$PRIVATE_KEY","rb") as f:
    key = f.read()
payload = {"iat": int(time.time())-60, "exp": int(time.time())+600, "iss": "$APP_ID"}
token = jwt.encode(payload, key, algorithm="RS256")
r = requests.post(f"https://api.github.com/app/installations/$INSTALLATION_ID/access_tokens",
                  headers={"Authorization": f"Bearer {token}", "Accept": "application/vnd.github+json"})
print(r.json()["token"])
EOF
```

Kräver `pip install PyJWT requests` (eller använd Python `cryptography` + manuell JWT-skapande).

### Steg 6 — Spara state

```bash
cat > /home/krily/.config/vvb-bot/state.json <<EOF
{
  "app_name": "vvb-crab-bot",
  "app_id": "$APP_ID",
  "installation_id": "$INSTALLATION_ID",
  "private_key": "/home/krily/.config/vvb-bot/private-key.pem",
  "manifest_path": "/tmp/vvb-crab-bot-manifest.json",
  "completed_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
```

### Steg 7 — Verifiera

```bash
TOKEN=*** från steg 5>"
curl -fsS -H "Authorization: Bearer ***" -H "Accept: application/vnd.github+json" \
  https://api.github.com/installation/repositories | jq '.total_count'
# Förväntat: antal repon i vvb-1 som App:en kan se
```

## Säkerhet

- **Privat nyckel** är redan chmod 600, ägs av `krily`. **Aldrig committa, aldrig pusha, aldrig visa i klartext.**
- **Manifestet är publikt** — det innehåller inga hemligheter, endast permissions.
- **App-installations-token är kortlivad** (10 min) — förnya vid varje användning, spara inte permanent.
- **Verifiera permissions i GitHub's bekräftelsesida** innan du klickar Create. Permissions ska vara exakt det som manifestet anger.

## Vid problem

- **404 från vivetbil.cc** → manifestet är inte uppladdat. Verifiera steg 1.
- **"code is invalid" från GitHub** → manifestet innehåller ogiltig JSON. Verifiera att det är valid JSON via `python3 -c "import json; json.load(open('/tmp/vvb-crab-bot-manifest.json'))"`.
- **"already exists" från GitHub** → App:en är redan skapad. Hoppa till steg 4 och installera.

## Nästa steg efter App-skapande

1. Dela App-ID + Installation-ID tillbaka till Kristian
2. Cron-jobbet `vvb-preloop-weekly-watch` är redan aktivt
3. `vvb-projects-agent` är installerat på VVB-OMARCHY
4. NTFY topic: `vvb-projects-9e28ea83` (VVB-OMARCHY)

---

**Klartlämna:** bekräfta att App:en är skapad och installerad, samt App-ID + Installation-ID.