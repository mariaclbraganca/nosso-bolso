"""
Teste E2E — Nosso Bolso API
Testa todos os endpoints com dados reais do banco.
familia_id: a1b2c3d4-0000-4000-a000-000000000001
usuario_id: 8ef33e82-1c59-42f5-9ab6-dcadf0cd66dd
"""
import requests
import sys

BASE = "http://127.0.0.1:8002"
FAM = "a1b2c3d4-0000-4000-a000-000000000001"
USR = "8ef33e82-1c59-42f5-9ab6-dcadf0cd66dd"
ENV_ALIM = "e0000001-0000-4000-a000-000000000001"
ENV_LAZER = "e0000004-0000-4000-a000-000000000004"

passed = 0
failed = 0
errors = []

def test(name, method, url, expected_status, body=None, params=None):
    global passed, failed
    try:
        if method == "GET":
            r = requests.get(f"{BASE}{url}", params=params, timeout=10)
        elif method == "POST":
            r = requests.post(f"{BASE}{url}", json=body, timeout=10)
        elif method == "PUT":
            r = requests.put(f"{BASE}{url}", json=body, timeout=10)
        elif method == "PATCH":
            r = requests.patch(f"{BASE}{url}", json=body, timeout=10)
        elif method == "DELETE":
            r = requests.delete(f"{BASE}{url}", params=params, timeout=10)

        if r.status_code == expected_status:
            passed += 1
            print(f"  PASS  {name} [{r.status_code}]")
            return r
        else:
            failed += 1
            detail = ""
            try:
                detail = r.json().get("detail", "")[:100]
            except:
                detail = r.text[:100]
            errors.append(f"{name}: esperado {expected_status}, recebeu {r.status_code} — {detail}")
            print(f"  FAIL  {name} [{r.status_code}] {detail}")
            return r
    except Exception as e:
        failed += 1
        errors.append(f"{name}: EXCEPTION {e}")
        print(f"  FAIL  {name} EXCEPTION: {e}")
        return None

print("=" * 60)
print("TESTE E2E — NOSSO BOLSO API")
print("=" * 60)

# ============================================================
# 1. HEALTH CHECK
# ============================================================
print("\n--- 1. HEALTH CHECK ---")
test("Health check", "GET", "/", 200)

# ============================================================
# 2. DASHBOARD
# ============================================================
print("\n--- 2. DASHBOARD ---")
test("Dashboard stats (abril)", "GET", "/dashboard/stats", 200,
     params={"familia_id": FAM, "mes": "2026-04"})
test("Dashboard stats (sem mes)", "GET", "/dashboard/stats", 200,
     params={"familia_id": FAM})
test("Dashboard stats (sem familia)", "GET", "/dashboard/stats", 422)

# ============================================================
# 3. ENVELOPES
# ============================================================
print("\n--- 3. ENVELOPES ---")
r = test("Listar envelopes", "GET", "/envelopes/", 200,
         params={"familia_id": FAM})
if r and r.status_code == 200:
    envs = r.json()
    print(f"         -> {len(envs)} envelopes encontrados")

# Criar envelope de teste
r = test("Criar envelope teste", "POST", "/envelopes/", 200,
         body={"nome_envelope": "TESTE_E2E", "valor_planejado": 100.0,
               "emoji": "🧪", "cor": "#FF0000", "familia_id": FAM})
test_env_id = None
if r and r.status_code == 200:
    test_env_id = r.json().get("id")
    print(f"         -> criado: {test_env_id}")

# Editar envelope
if test_env_id:
    test("Editar envelope", "PUT", f"/envelopes/{test_env_id}", 200,
         body={"nome_envelope": "TESTE_EDITADO", "valor_planejado": 200.0})

# Deletar envelope teste
if test_env_id:
    test("Deletar envelope teste", "DELETE", f"/envelopes/{test_env_id}", 200,
         params={"familia_id": FAM})

# ============================================================
# 4. TRANSACOES
# ============================================================
print("\n--- 4. TRANSACOES ---")

# Listar
r = test("Listar transacoes (abril)", "GET", "/transacoes/extrato", 200,
         params={"familia_id": FAM, "mes": "2026-04"})
if r and r.status_code == 200:
    txs = r.json()
    print(f"         -> {len(txs)} transacoes")

# Criar receita
r = test("Criar receita", "POST", "/transacoes/receita", 200,
         body={"valor": 50.0, "descricao": "Teste E2E receita",
               "usuario_id": USR, "familia_id": FAM})
receita_id = None
if r and r.status_code == 200:
    receita_id = r.json().get("id")
    print(f"         -> receita criada: {receita_id}")

# Criar despesa (no envelope alimentacao que tem saldo)
r = test("Criar despesa", "POST", "/transacoes/", 200,
         body={"valor": 10.0, "tipo": "despesa", "descricao": "Teste E2E despesa",
               "usuario_id": USR, "envelope_id": ENV_ALIM, "familia_id": FAM})
despesa_id = None
if r and r.status_code == 200:
    despesa_id = r.json().get("id")
    print(f"         -> despesa criada: {despesa_id}")

# Validacoes
test("Receita com envelope (deve falhar)", "POST", "/transacoes/", 422,
     body={"valor": 10.0, "tipo": "receita", "descricao": "invalida",
           "usuario_id": USR, "envelope_id": ENV_ALIM, "familia_id": FAM})

test("Despesa sem envelope (deve falhar)", "POST", "/transacoes/", 422,
     body={"valor": 10.0, "tipo": "despesa", "descricao": "invalida",
           "usuario_id": USR, "familia_id": FAM})

test("Valor negativo (deve falhar)", "POST", "/transacoes/", 422,
     body={"valor": -5.0, "tipo": "receita", "descricao": "invalida",
           "usuario_id": USR, "familia_id": FAM})

# Editar transacao
if despesa_id:
    test("Editar transacao", "PUT", f"/transacoes/{despesa_id}", 200,
         body={"valor": 15.0, "descricao": "Teste E2E editado"})

# Soft delete (lixeira)
if despesa_id:
    test("Soft delete (lixeira)", "DELETE", f"/transacoes/{despesa_id}", 200,
         params={"familia_id": FAM})

# Listar lixeira
test("Listar lixeira", "GET", "/transacoes/lixeira", 200,
     params={"familia_id": FAM})

# Restaurar
if despesa_id:
    test("Restaurar da lixeira", "POST", f"/transacoes/{despesa_id}/restaurar?familia_id={FAM}", 200)

# Deletar transacao de teste (limpar)
if despesa_id:
    test("Deletar despesa teste", "DELETE", f"/transacoes/{despesa_id}", 200,
         params={"familia_id": FAM})
if receita_id:
    test("Deletar receita teste", "DELETE", f"/transacoes/{receita_id}", 200,
         params={"familia_id": FAM})

# ============================================================
# 5. ABASTECER
# ============================================================
print("\n--- 5. ABASTECER ---")
test("Abastecer envelope", "POST", "/abastecer/", 200,
     body={"envelope_id": ENV_LAZER, "valor": 5.0,
           "usuario_id": USR, "familia_id": FAM})

# ============================================================
# 6. REMANEJAR
# ============================================================
print("\n--- 6. REMANEJAR ---")
test("Remanejar entre envelopes", "POST", "/remanejar/", 200,
     body={"origem_id": ENV_ALIM, "destino_id": ENV_LAZER,
           "valor": 5.0, "usuario_id": USR, "familia_id": FAM})

test("Remanejar sem saldo (deve falhar)", "POST", "/remanejar/", 400,
     body={"origem_id": ENV_LAZER, "destino_id": ENV_ALIM,
           "valor": 999999.0, "usuario_id": USR, "familia_id": FAM})

# ============================================================
# 7. GASTOS FIXOS
# ============================================================
print("\n--- 7. GASTOS FIXOS ---")
r = test("Listar fixos (abril)", "GET", "/fixos/", 200,
         params={"familia_id": FAM, "mes": "2026-04"})
if r and r.status_code == 200:
    fixos = r.json()
    print(f"         -> {len(fixos)} fixos")

# Criar fixo
r = test("Criar gasto fixo", "POST", "/fixos/", 200,
         body={"nome": "Teste E2E Fixo", "valor": 99.90,
               "mes": "2026-04", "familia_id": FAM})
fixo_id = None
if r and r.status_code == 200:
    fixo_id = r.json().get("id")

# Marcar como pago
if fixo_id:
    test("Marcar fixo como pago", "PATCH", f"/fixos/{fixo_id}", 200,
         body={"pago": True})

# Deletar fixo
if fixo_id:
    test("Deletar fixo teste", "DELETE", f"/fixos/{fixo_id}", 200,
         params={"familia_id": FAM})

# Recorrencia (maio deve trazer fixos de abril recorrentes)
test("Recorrencia maio", "GET", "/fixos/", 200,
     params={"familia_id": FAM, "mes": "2026-05"})

# ============================================================
# 8. EXPORT
# ============================================================
print("\n--- 8. EXPORT ---")
test("Export CSV", "GET", "/transacoes/export", 200,
     params={"familia_id": FAM, "formato": "csv"})

# ============================================================
# 9. INSIGHTS
# ============================================================
print("\n--- 9. INSIGHTS ---")
test("Insights comparativo", "GET", "/dashboard/insights", 200,
     params={"familia_id": FAM, "mes_atual": "2026-04"})

# ============================================================
# RESULTADO FINAL
# ============================================================
print("\n" + "=" * 60)
print(f"RESULTADO: {passed} PASSED / {failed} FAILED / {passed + failed} TOTAL")
print("=" * 60)

if errors:
    print("\nFALHAS:")
    for e in errors:
        print(f"  {e}")

sys.exit(0 if failed == 0 else 1)
