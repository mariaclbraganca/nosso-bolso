import sys, requests
sys.stdout.reconfigure(encoding='utf-8')

BASE = 'http://localhost:8001'
USR_A = 'c8648c09-53d3-46cb-94d9-c8a4c819b827'
USR_B = '238f37f6-747e-472e-a518-ac59eb63607d'
FAMILIA = '798bfc69-a6e9-4173-a156-cffa8fcb76c3'
ENV_LAZER = '22a27aa1-d868-40cd-b041-ebd59ec4fd54'

from dotenv import load_dotenv; load_dotenv()
from database import get_supabase
db = get_supabase()

results = []
created = []

def ok(label, passed, extra=''):
    results.append((label, passed))
    sym = 'PASS' if passed else 'FAIL'
    print(f'  [{sym}] {label}' + (f'  ({extra})' if extra else ''))

def sg():
    return db.table('saldo_geral').select('valor_total_disponivel').eq('familia_id', FAMILIA).execute().data[0]['valor_total_disponivel']

def env(eid):
    return db.table('envelopes').select('saldo_atual').eq('id', eid).execute().data[0]['saldo_atual']

# --- 3. RECEITA ---
print('=== 3. RECEITA ===')
sg0 = sg()
r = requests.post(f'{BASE}/transacoes/receita', json={'valor': 1000, 'usuario_id': USR_A, 'descricao': 'Salario Retest'})
ok('POST /receita HTTP 200', r.status_code == 200, f'HTTP {r.status_code}')
if r.status_code == 200:
    created.append(r.json()['id'])
    sg1 = sg()
    ok('tipo=receita', r.json()['tipo'] == 'receita')
    ok('envelope_id=None', r.json()['envelope_id'] is None)
    ok('Trigger saldo_geral +1000', abs(sg1 - sg0 - 1000) < 0.01, f'R${sg0} -> R${sg1}')
else:
    print(f'    erro: {r.text[:100]}')

r2 = requests.post(f'{BASE}/transacoes/', json={'tipo': 'receita', 'valor': 500, 'usuario_id': USR_B, 'descricao': 'Freelance'})
ok('POST /transacoes/ receita', r2.status_code == 200, f'HTTP {r2.status_code}')
if r2.status_code == 200:
    created.append(r2.json()['id'])

# --- 4. ABASTECIMENTO ---
print()
print('=== 4. ABASTECIMENTO ===')
sg_pre = sg()
env_pre = env(ENV_LAZER)
r = requests.post(f'{BASE}/abastecer/', json={'envelope_id': ENV_LAZER, 'valor': 300, 'usuario_id': USR_A})
ok('POST /abastecer/ HTTP 200', r.status_code == 200, f'HTTP {r.status_code}')
if r.status_code == 200:
    created.append(r.json()['id'])
    sg_pos = sg()
    env_pos = env(ENV_LAZER)
    ok('Trigger saldo_geral -300', abs(sg_pre - sg_pos - 300) < 0.01, f'R${sg_pre} -> R${sg_pos}')
    ok('Trigger lazer +300', abs(env_pos - env_pre - 300) < 0.01, f'R${env_pre} -> R${env_pos}')
else:
    print(f'    erro: {r.text[:100]}')

# --- 7. UNDO DELETE ---
print()
print('=== 7. UNDO / DELETE ===')
env_antes = env(ENV_LAZER)
tx = db.table('transacoes').insert({'valor': 50, 'tipo': 'despesa', 'usuario_id': USR_A, 'envelope_id': ENV_LAZER, 'data': '2026-04-04'}).execute().data[0]
env_apos_despesa = env(ENV_LAZER)
ok('Trigger despesa -50', abs(env_antes - env_apos_despesa - 50) < 0.01, f'R${env_antes} -> R${env_apos_despesa}')
r = requests.delete(f'{BASE}/transacoes/{tx["id"]}')
env_apos_del = env(ENV_LAZER)
ok('DELETE HTTP 200', r.status_code == 200)
ok('Trigger reversal +50', abs(env_apos_del - env_antes) < 0.01, f'R${env_apos_despesa} -> R${env_apos_del}')

# --- 1. DASHBOARD ---
print()
print('=== 1. DASHBOARD STATS ===')
r = requests.get(f'{BASE}/dashboard/stats?familia_id={FAMILIA}&mes=2026-04')
ok('GET /dashboard/stats', r.status_code == 200, f'HTTP {r.status_code}')
if r.status_code == 200:
    d = r.json()
    ok('saldo_disponivel', 'saldo_disponivel' in d, f'R${d.get("saldo_disponivel")}')
    ok('envelopes', len(d.get('envelopes', [])) > 0, f'{len(d.get("envelopes", []))} envs')
    ok('gastos_por_usuario', isinstance(d.get('gastos_por_usuario'), dict))

# --- 2. EXTRATO ---
print()
print('=== 2. EXTRATO COM MES ===')
for mes, nome in [('2026-04', 'abr/30d'), ('2026-02', 'fev/28d'), ('2026-11', 'nov/30d')]:
    r = requests.get(f'{BASE}/transacoes/extrato?mes={mes}&limit=5')
    ok(f'extrato mes={mes} ({nome})', r.status_code == 200, f'HTTP {r.status_code}')

# --- DELETE 404 ---
print()
print('=== DELETE 404 ===')
r = requests.delete(f'{BASE}/transacoes/00000000-0000-0000-0000-000000000000')
ok('DELETE id inexistente = 404', r.status_code == 404, f'HTTP {r.status_code}')

# --- ENVELOPES ---
print()
print('=== ENVELOPES VALIDACAO ===')
ok('sem nome = 422', requests.post(f'{BASE}/envelopes/', json={'valor_planejado': 100}).status_code == 422)
ok('valor negativo = 422', requests.post(f'{BASE}/envelopes/', json={'nome_envelope': 'X', 'valor_planejado': -1}).status_code == 422)
ok('valor zero = 422', requests.post(f'{BASE}/envelopes/', json={'nome_envelope': 'X', 'valor_planejado': 0}).status_code == 422)
r = requests.post(f'{BASE}/envelopes/', json={'nome_envelope': 'Teste Final', 'valor_planejado': 400})
ok('envelope valido + saldo=0', r.status_code == 200 and r.json().get('saldo_atual') == 0.0, f'HTTP {r.status_code}')

# --- PYDANTIC ---
print()
print('=== VALIDACOES PYDANTIC ===')
ok('despesa sem envelope = 422', requests.post(f'{BASE}/transacoes/', json={'tipo': 'despesa', 'valor': 50, 'usuario_id': USR_A}).status_code == 422)
ok('receita com envelope = 422', requests.post(f'{BASE}/transacoes/', json={'tipo': 'receita', 'valor': 100, 'usuario_id': USR_A, 'envelope_id': ENV_LAZER}).status_code == 422)
ok('valor negativo = 422', requests.post(f'{BASE}/transacoes/', json={'tipo': 'despesa', 'valor': -10, 'envelope_id': ENV_LAZER, 'usuario_id': USR_A}).status_code == 422)
ok('tipo invalido = 422', requests.post(f'{BASE}/transacoes/', json={'tipo': 'xxx', 'valor': 10, 'usuario_id': USR_A}).status_code == 422)
ok('sem usuario_id = 422', requests.post(f'{BASE}/transacoes/', json={'tipo': 'despesa', 'valor': 10, 'envelope_id': ENV_LAZER}).status_code == 422)

# --- LIMPEZA ---
print()
for tid in created:
    db.table('transacoes').delete().eq('id', tid).execute()
print(f'  {len(created)} transacoes de teste removidas')

# --- RESULTADO ---
total = len(results)
passed = sum(1 for _, p in results if p)
failed = total - passed
print()
print('=' * 50)
print(f'RESULTADO FINAL: {passed}/{total} PASS  |  {failed} FAIL')
print(f'TAXA: {passed / total * 100:.0f}%')
print('=' * 50)
if failed:
    print('Ainda falhando:')
    for l, p in results:
        if not p:
            print(f'  FAIL: {l}')
else:
    print('TODOS OS TESTES PASSARAM!')
