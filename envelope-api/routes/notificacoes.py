from fastapi import APIRouter, BackgroundTasks
from database import get_supabase
from datetime import date, timedelta
import calendar

router = APIRouter()

@router.post("/processar-alertas")
def processar_alertas(background_tasks: BackgroundTasks):
    """
    Roda em background para verificar quem precisa de notificação (SPEC-06).
    Em produção, isso seria chamado por um CRON job (ex: GitHub Actions ou Render Cron).
    """
    db = get_supabase()
    hoje = date.today()
    amanha = hoje + timedelta(days=1)
    mes_str = hoje.strftime("%Y-%m")

    # 1. Verificar Gastos Fixos vencendo amanhã (24h)
    fixos = db.table("gastos_fixos").select("*, usuarios(fcm_token)") \
        .eq("mes", mes_str).eq("dia_vencimento", amanha.day).eq("pago", False).execute().data
    
    for f in fixos:
        token = f["usuarios"]["fcm_token"] if f["usuarios"] else None
        if token:
            print(f"🔔 NOTIFICANDO: Gasto fixo '{f['nome']}' vence amanhã! (Token: {token[:10]}...)")
            # Aqui entraria: firebase_admin.messaging.send(...)

    # 2. Verificar Envelopes quase vazios (< 20%)
    envelopes = db.table("envelopes").select("*").execute().data
    for e in envelopes:
        plan = float(e["valor_planejado"])
        saldo = float(e["saldo_atual"])
        if plan > 0 and saldo >= 0 and (saldo / plan) <= 0.2:
            # Notificar todos da família ou apenas o admin? (Notificamos o Admin da família)
            admins = db.table("usuarios").select("fcm_token").eq("familia_id", e["familia_id"]).eq("role", "admin").execute().data
            for a in admins:
                if a["fcm_token"]:
                    print(f"⚠️ ALERTA: Envelope '{e['nome_envelope']}' está quase vazio! ({int(saldo/plan*100)}% restantes)")

    return {"status": "Processamento de alertas iniciado em background"}
