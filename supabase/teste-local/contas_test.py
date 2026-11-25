"""Exercita o ambiente hospedado com três contas fictícias descartáveis."""
import json
import secrets
import sys
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlsplit

fixture = json.loads(Path(sys.argv[1]).read_text())
base = fixture["url"]
key = fixture["publishable_key"]
assert urlsplit(base).scheme == "https"
assert urlsplit(base).hostname == fixture["test_project_ref"] + ".supabase.co"
assert key.startswith("sb_publishable_")

by_role = {account["role"]: account for account in fixture["accounts"]}
assert set(by_role) == {"gm", "player", "outside"}
assert len({account["id"] for account in by_role.values()}) == 3
assert all(account["email"].endswith("@example.com") for account in by_role.values())


def request(path, body, token=None, status=200):
    headers = {"apikey": key, "Content-Type": "application/json"}
    if token:
        headers["Authorization"] = "Bearer " + token
    req = urllib.request.Request(
        base + path, headers=headers, data=json.dumps(body).encode()
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as response:
            received = response.status
            data = json.load(response)
    except urllib.error.HTTPError as error:
        received = error.code
        data = json.load(error)
    assert received == status, (path, body.get("action"), received, data.get("error"))
    return data


def action(name, token=None, status=200, **fields):
    return request("/functions/v1/rpg-account", {"action": name, **fields}, token, status)


def legacy_login(account):
    return request("/auth/v1/token?grant_type=password", {
        "email": account["email"], "password": account["password"]
    })


gm, player, outside = (by_role[role] for role in ("gm", "player", "outside"))
sessions = {role: legacy_login(account) for role, account in by_role.items()}
gm_token, player_token, outside_token = (
    sessions[role]["access_token"] for role in ("gm", "player", "outside")
)
suffix = secrets.token_hex(3)
gm_name = "mestre-" + suffix
player_name = "jogador-" + suffix

action("setup", status=401, username=player_name)
assert action("setup", gm_token, username=gm_name)["ok"]
assert action("setup", player_token, username=player_name, campaign_id=fixture["campaign"])["ok"]
action("setup", outside_token, status=409, username=player_name)
action("setup", outside_token, status=403, username="outro-" + suffix,
       campaign_id=fixture["campaign"])
for obj in ("target", "claim"):
    request("/rest/v1/rpc/rpg_account", {
        "p_action": obj, "p_actor": None, "p_data": {"username": player_name}
    }, player_token, 403)

session = action("login", username=player_name.upper(), password=player["password"])
assert set(session) == {"access_token", "refresh_token"}
assert action("settings", session["access_token"])["username"] == player_name
unknown = action("login", status=401, username="inexistente-" + suffix, password=player["password"])
assert unknown == action("login", status=401, username=player_name, password="Senha errada")
print("Login, vinculação de conta e isolamento da função privada passaram.")

unknown_request = action("request", username="inexistente-" + suffix)
assert unknown_request == action("request", username=player_name) == {"ok": True}
assert action("settings", outside_token)["pending"] == []
pending = action("settings", gm_token)["pending"]
request_id = next(item["id"] for item in pending if item["username"] == player_name)
action("approve", outside_token, status=403, request_id=request_id)
code = action("approve", gm_token, request_id=request_id)["code"]
action("approve", gm_token, status=403, request_id=request_id)
assert action("request", username=player_name)["ok"]

new_password = "Rpg!9-" + secrets.token_urlsafe(23)
action("recover", status=400, username=player_name, code="00000-00000-00000-00000",
       password=new_password)
assert action("recover", username=player_name, code=code, password=new_password)["ok"]
action("recover", status=400, username=player_name, code=code, password=new_password)
action("login", status=401, username=player_name, password=player["password"])
new_session = action("login", username=player_name, password=new_password)
user = request("/auth/v1/token?grant_type=refresh_token", {
    "refresh_token": new_session["refresh_token"]
})["user"]
assert user["id"] == player["id"]
request("/auth/v1/token?grant_type=refresh_token", {"refresh_token": sessions["player"]["refresh_token"]}, status=400)
action("settings", player_token, status=401)
print("Código do mestre, uso único, troca da senha e revogação da sessão passaram.")

old_backup = action("backup", gm_token)["code"]
backup = action("backup", gm_token)["code"]
assert backup != old_backup
new_gm_password = "Rpg!9-" + secrets.token_urlsafe(23)
action("recover", status=400, username=gm_name, code=old_backup, password=new_gm_password)
assert action("recover", username=gm_name, code=backup, password=new_gm_password)["ok"]
action("recover", status=400, username=gm_name, code=backup, password=new_gm_password)
taken = action("login", username=gm_name, password=new_gm_password)
user = request("/auth/v1/token?grant_type=refresh_token", {
    "refresh_token": taken["refresh_token"]
})["user"]
assert user["id"] == gm["id"]
print("Código de reserva do mestre, rotação e uso único passaram.")
