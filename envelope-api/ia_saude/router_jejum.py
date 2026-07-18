"""Módulo Jejum Intermitente — endpoints REST + motivação Fast Together.

Dados 100% no Supabase (jejum_config, jejum_registros, jejum_together).
Regras críticas:
- Quebras de jejum (status=interrompido) NUNCA são compartilhadas entre usuários.
- Máximo 2 notificações Together/dia por par.
- Linguagem sempre positiva — nunca punitiva.
- Nenhum dado financeiro neste módulo.
"""
from __future__ import annotations

import json
from datetime import datetime, timezone, date

import os

from fastapi import APIRouter, Header, HTTPException, Query

from database import get_supabase
from ia_saude.gemini_client import chamar_gemini

router = APIRouter(tags=["jejum"])

PROTOCOLOS_HORAS = {"16_8": 16.0, "18_6": 18.0, "20_4": 20.0, "24h": 24.0}


def _now() -> datetime:
    return datetime.now(timezone.utc)


# ── Config ───────────────────────────────────────────────────────────────────

@router.get("/jejum/config/{usuario_id}")
async def get_config(usuario_id: str, familia_id: str = Query(...)):
    """Retorna a config do membro. Cria com defaults (16:8) se não existir.

    Reset lazy de jokers: se o mês virou desde o último reset, zera jokers_usados.
    """
    db = get_supabase()
    res = db.table("jejum_config").select("*").eq("usuario_id", usuario_id).execute()

    if res.data:
        cfg = res.data[0]
    else:
        cfg = db.table("jejum_config").insert({
            "usuario_id": usuario_id,
            "familia_id": familia_id,
        }).execute().data[0]

    mes_atual = date.today().month
    if cfg.get("joker_reset_mes") != mes_atual:
        cfg = db.table("jejum_config").update({
            "jokers_usados": 0,
            "joker_reset_mes": mes_atual,
        }).eq("id", cfg["id"]).execute().data[0]

    return cfg


@router.put("/jejum/config/{usuario_id}")
async def put_config(usuario_id: str, payload: dict):
    """Atualiza protocolo/modalidade/preferências. Upsert."""
    db = get_supabase()
    campos_permitidos = {
        "protocolo", "duracao_horas", "modalidade", "janela_inicio",
        "joker_days_mes", "together_ativo", "notif_hidratacao", "notif_fases",
    }
    updates = {k: v for k, v in payload.items() if k in campos_permitidos}
    if not updates:
        raise HTTPException(status_code=422, detail="Nenhum campo válido no payload")

    # Protocolo padrão define a duração automaticamente
    protocolo = updates.get("protocolo")
    if protocolo in PROTOCOLOS_HORAS:
        updates["duracao_horas"] = PROTOCOLOS_HORAS[protocolo]

    existente = db.table("jejum_config").select("id").eq("usuario_id", usuario_id).execute()
    if existente.data:
        res = db.table("jejum_config").update(updates).eq("usuario_id", usuario_id).execute()
    else:
        familia_id = payload.get("familia_id")
        if not familia_id:
            raise HTTPException(status_code=422, detail="familia_id obrigatório na criação")
        res = db.table("jejum_config").insert({
            "usuario_id": usuario_id, "familia_id": familia_id, **updates,
        }).execute()
    return res.data[0]


# ── Ciclo de vida do jejum ───────────────────────────────────────────────────

@router.post("/jejum/iniciar")
async def iniciar(payload: dict):
    """Inicia um jejum. Bloqueia se já existe registro em andamento."""
    usuario_id = payload.get("usuario_id")
    familia_id = payload.get("familia_id")
    if not usuario_id or not familia_id:
        raise HTTPException(status_code=422, detail="usuario_id e familia_id obrigatórios")

    db = get_supabase()
    ativo = db.table("jejum_registros").select("id") \
        .eq("usuario_id", usuario_id).eq("status", "em_andamento").execute()
    if ativo.data:
        raise HTTPException(status_code=409, detail="Já existe um jejum em andamento")

    # Parceiro Together ativo no momento (para contexto de motivação)
    partner_id = None
    tg = db.table("jejum_together").select("usuario_a, usuario_b") \
        .eq("familia_id", familia_id).eq("status", "ativo").execute()
    for t in tg.data or []:
        if t["usuario_a"] == usuario_id:
            partner_id = t["usuario_b"]
        elif t["usuario_b"] == usuario_id:
            partner_id = t["usuario_a"]

    registro = db.table("jejum_registros").insert({
        "usuario_id": usuario_id,
        "familia_id": familia_id,
        "iniciado_em": payload.get("iniciado_em") or _now().isoformat(),
        "meta_horas": payload.get("meta_horas"),   # None = modalidade livre
        "humor_inicio": payload.get("humor_inicio"),
        "together_partner_id": partner_id,
    }).execute().data[0]
    return registro


@router.post("/jejum/finalizar/{registro_id}")
async def finalizar(registro_id: str, payload: dict):
    """Finaliza um jejum: completo | interrompido | joker.

    O trigger do banco atualiza sequência/recorde/jokers automaticamente.
    """
    status = payload.get("status")
    if status not in ("completo", "interrompido", "joker"):
        raise HTTPException(status_code=422, detail="status deve ser completo, interrompido ou joker")

    db = get_supabase()
    reg = db.table("jejum_registros").select("*").eq("id", registro_id).execute()
    if not reg.data:
        raise HTTPException(status_code=404, detail="Registro não encontrado")
    reg = reg.data[0]
    if reg["status"] != "em_andamento":
        raise HTTPException(status_code=409, detail="Jejum já finalizado")

    # Joker: valida limite mensal
    if status == "joker":
        cfg = db.table("jejum_config").select("jokers_usados, joker_days_mes") \
            .eq("usuario_id", reg["usuario_id"]).execute()
        if cfg.data and cfg.data[0]["jokers_usados"] >= cfg.data[0]["joker_days_mes"]:
            raise HTTPException(status_code=409, detail="Jokers do mês esgotados")

    iniciado = datetime.fromisoformat(reg["iniciado_em"].replace("Z", "+00:00"))
    fim = _now()
    duracao_min = int((fim - iniciado).total_seconds() // 60)

    res = db.table("jejum_registros").update({
        "finalizado_em": fim.isoformat(),
        "duracao_real_min": duracao_min,
        "status": status,
        "is_joker_day": status == "joker",
        "humor_fim": payload.get("humor_fim"),
        "reflexao": payload.get("reflexao"),
    }).eq("id", registro_id).execute()
    return res.data[0]


@router.get("/jejum/ativo/{usuario_id}")
async def get_ativo(usuario_id: str):
    """Registro em andamento ou null — o app checa ao abrir para restaurar o timer."""
    db = get_supabase()
    res = db.table("jejum_registros").select("*") \
        .eq("usuario_id", usuario_id).eq("status", "em_andamento").execute()
    return res.data[0] if res.data else None


@router.get("/jejum/historico/{usuario_id}")
async def get_historico(usuario_id: str, page: int = 1, limit: int = 30):
    """Histórico paginado (mais recentes primeiro) + estatísticas agregadas."""
    db = get_supabase()
    offset = (page - 1) * limit
    res = db.table("jejum_registros").select("*") \
        .eq("usuario_id", usuario_id).neq("status", "em_andamento") \
        .order("iniciado_em", desc=True).range(offset, offset + limit - 1).execute()

    registros = res.data or []

    # Estatísticas sobre todos os registros finalizados (não só a página)
    todos = db.table("jejum_registros").select("status, duracao_real_min") \
        .eq("usuario_id", usuario_id).neq("status", "em_andamento").execute().data or []
    completos = [r for r in todos if r["status"] in ("completo", "joker")]
    duracoes = [r["duracao_real_min"] for r in todos if r.get("duracao_real_min")]

    return {
        "registros": registros,
        "stats": {
            "total": len(todos),
            "completos": len(completos),
            "taxa_sucesso": round(len(completos) / len(todos) * 100) if todos else 0,
            "duracao_media_min": int(sum(duracoes) / len(duracoes)) if duracoes else 0,
        },
    }


# ── Insights IA (semanal) + mensagem do unicórnio ────────────────────────────

@router.get("/jejum/insights/{usuario_id}")
async def get_insights(usuario_id: str):
    """3 observações positivas + 1 sugestão, geradas pelo Gemini a partir dos
    últimos 7 dias. Também retorna a mensagem contextual do card do unicórnio.

    REGRA: nunca mencionar peso, dinheiro ou linguagem punitiva.
    """
    db = get_supabase()
    registros = db.table("jejum_registros").select(
        "iniciado_em, duracao_real_min, meta_horas, status, humor_inicio, humor_fim"
    ).eq("usuario_id", usuario_id).neq("status", "em_andamento") \
        .order("iniciado_em", desc=True).limit(7).execute().data or []

    cfg = db.table("jejum_config").select("protocolo, sequencia_atual, recorde_sequencia") \
        .eq("usuario_id", usuario_id).execute()
    cfg = cfg.data[0] if cfg.data else {}

    if not registros:
        return {
            "insights": [],
            "sugestao": None,
            "mensagem_unicornio": {
                "unicornio": "happy",
                "texto": "Que bom te ver por aqui! Quando quiser, é só tocar em Iniciar — vou estar do seu lado o tempo todo. 🦄",
            },
        }

    prompt = f"""Você é o assistente de bem-estar de um app de jejum intermitente.
Analise o histórico dos últimos jejuns e a configuração do usuário.

Histórico (mais recente primeiro): {json.dumps(registros, default=str, ensure_ascii=False)}
Protocolo atual: {cfg.get('protocolo', '16_8')} | Sequência: {cfg.get('sequencia_atual', 0)} dias | Recorde: {cfg.get('recorde_sequencia', 0)} dias

Responda SOMENTE com JSON, sem markdown:
{{
  "insights": ["frase 1", "frase 2", "frase 3"],
  "sugestao": "uma sugestão gentil de ajuste (ou null se está tudo ótimo)",
  "mensagem_unicornio": {{"unicornio": "sweet ou happy", "texto": "mensagem curta e carinhosa"}}
}}

REGRAS OBRIGATÓRIAS:
- Tom carinhoso, celebra o esforço. NUNCA punitivo.
- NUNCA mencione peso, calorias, dinheiro ou valores financeiros.
- Jejuns interrompidos são "dias de descanso" — jamais "falha" ou "quebra".
- "sweet" para celebrações (metas, recordes), "happy" para motivação do dia a dia.
- Frases curtas, em português brasileiro, com no máximo 1 emoji cada."""

    try:
        texto = await chamar_gemini({
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.7},
        })
        limpo = texto.strip().removeprefix("```json").removeprefix("```").removesuffix("```").strip()
        return json.loads(limpo)
    except Exception as exc:
        # Fallback estático — o módulo nunca pode quebrar por causa da IA
        return {
            "insights": [],
            "sugestao": None,
            "mensagem_unicornio": {
                "unicornio": "happy",
                "texto": f"Você já tem {cfg.get('sequencia_atual', 0)} dias de sequência. Sigo aqui, na torcida! ✨",
            },
            "erro_ia": str(exc),
        }


# ── Fast Together ────────────────────────────────────────────────────────────

@router.post("/jejum/together/convite")
async def together_convite(payload: dict):
    """Cria/reativa o vínculo Fast Together entre dois membros da mesma família."""
    familia_id = payload.get("familia_id")
    usuario_a = payload.get("usuario_a")
    usuario_b = payload.get("usuario_b")
    if not all([familia_id, usuario_a, usuario_b]):
        raise HTTPException(status_code=422, detail="familia_id, usuario_a e usuario_b obrigatórios")
    if usuario_a == usuario_b:
        raise HTTPException(status_code=422, detail="Não é possível parear consigo mesmo")

    db = get_supabase()
    # Ambos precisam ser da mesma família
    membros = db.table("usuarios").select("id").eq("familia_id", familia_id) \
        .in_("id", [usuario_a, usuario_b]).execute().data or []
    if len(membros) != 2:
        raise HTTPException(status_code=403, detail="Ambos devem pertencer à mesma família")

    # Reativa vínculo existente (em qualquer direção) ou cria novo
    existente = db.table("jejum_together").select("id, status") \
        .eq("familia_id", familia_id) \
        .or_(f"and(usuario_a.eq.{usuario_a},usuario_b.eq.{usuario_b}),"
             f"and(usuario_a.eq.{usuario_b},usuario_b.eq.{usuario_a})").execute()
    if existente.data:
        res = db.table("jejum_together").update({"status": "ativo"}) \
            .eq("id", existente.data[0]["id"]).execute()
    else:
        res = db.table("jejum_together").insert({
            "familia_id": familia_id,
            "usuario_a": usuario_a,
            "usuario_b": usuario_b,
        }).execute()
    return res.data[0]


@router.get("/jejum/together/{usuario_id}")
async def together_estado(usuario_id: str, familia_id: str = Query(...)):
    """Estado do vínculo Together do usuário + progresso POSITIVO do parceiro.

    Compartilha apenas: jejum ativo (elapsed), sequência, último completo.
    NUNCA compartilha: interrupções, humor, reflexões.
    """
    db = get_supabase()
    tg = db.table("jejum_together").select("*").eq("familia_id", familia_id) \
        .eq("status", "ativo") \
        .or_(f"usuario_a.eq.{usuario_id},usuario_b.eq.{usuario_id}").execute()
    if not tg.data:
        return None

    vinculo = tg.data[0]
    partner_id = vinculo["usuario_b"] if vinculo["usuario_a"] == usuario_id else vinculo["usuario_a"]

    partner = db.table("usuarios").select("id, nome").eq("id", partner_id).execute()
    partner_nome = partner.data[0]["nome"] if partner.data else ""

    ativo = db.table("jejum_registros").select("iniciado_em, meta_horas") \
        .eq("usuario_id", partner_id).eq("status", "em_andamento").execute()

    cfg = db.table("jejum_config").select("sequencia_atual") \
        .eq("usuario_id", partner_id).execute()

    return {
        "together_id": vinculo["id"],
        "parceiro": {
            "id": partner_id,
            "nome": partner_nome,
            "jejum_ativo": ativo.data[0] if ativo.data else None,
            "sequencia": cfg.data[0]["sequencia_atual"] if cfg.data else 0,
        },
        "mensagem_ia": vinculo.get("mensagem_ia"),
    }


@router.post("/jejum/together/motivar")
async def together_motivar(payload: dict):
    """Envia incentivo manual ao parceiro. Respeita o limite de 2 notifs/dia."""
    together_id = payload.get("together_id")
    remetente_id = payload.get("remetente_id")
    if not together_id or not remetente_id:
        raise HTTPException(status_code=422, detail="together_id e remetente_id obrigatórios")

    db = get_supabase()
    tg = db.table("jejum_together").select("*").eq("id", together_id).execute()
    if not tg.data:
        raise HTTPException(status_code=404, detail="Vínculo não encontrado")
    vinculo = tg.data[0]

    if not _pode_notificar(vinculo):
        raise HTTPException(status_code=429, detail="Limite de 2 incentivos por dia atingido")

    destinatario_id = vinculo["usuario_b"] if vinculo["usuario_a"] == remetente_id else vinculo["usuario_a"]
    remetente = db.table("usuarios").select("nome").eq("id", remetente_id).execute()
    nome = remetente.data[0]["nome"] if remetente.data else "Alguém"

    mensagem = payload.get("mensagem") or f"{nome} está na torcida por você! 🦄"

    _registrar_notificacao(db, vinculo, "incentivo_livre", mensagem)
    _enviar_push(db, destinatario_id, "💜 Incentivo recebido", mensagem)
    return {"status": "enviado", "mensagem": mensagem}


# ── Cron: motivação por contágio (chamar de hora em hora) ────────────────────

@router.post("/jejum/processar-motivacoes")
async def processar_motivacoes(x_cron_secret: str | None = Header(default=None)):
    """Varre vínculos Together ativos e dispara motivações por milestone.

    Chamado por cron externo (Render Cron / GitHub Actions) a cada 1h —
    mesmo padrão do /notificacoes/processar-alertas.
    Só eventos POSITIVOS são propagados. Máx 2 notifs/dia por par.
    """
    _secret = os.getenv("CRON_SECRET", "")
    if _secret and x_cron_secret != _secret:
        raise HTTPException(status_code=401, detail="Unauthorized")

    db = get_supabase()
    vinculos = db.table("jejum_together").select("*").eq("status", "ativo").execute().data or []
    disparadas = 0

    for vinculo in vinculos:
        if not _pode_notificar(vinculo):
            continue

        for autor_id, alvo_id in (
            (vinculo["usuario_a"], vinculo["usuario_b"]),
            (vinculo["usuario_b"], vinculo["usuario_a"]),
        ):
            evento = _detectar_milestone(db, autor_id)
            if not evento:
                continue

            autor = db.table("usuarios").select("nome").eq("id", autor_id).execute()
            nome = autor.data[0]["nome"] if autor.data else "Seu parceiro"

            mensagem = await _gerar_mensagem_motivacao(nome, evento)
            _registrar_notificacao(db, vinculo, evento, mensagem)
            _enviar_push(db, alvo_id, "🦄 Fast Together", mensagem)
            disparadas += 1
            break  # 1 notificação por vínculo por rodada

    return {"status": "ok", "vinculos": len(vinculos), "notificacoes": disparadas}


# ── Helpers ──────────────────────────────────────────────────────────────────

def _pode_notificar(vinculo: dict) -> bool:
    """Limite de 2 notificações/dia por par, com reset diário."""
    hoje = date.today().isoformat()
    if vinculo.get("notifs_reset_dia") != hoje:
        return True
    return (vinculo.get("notifs_hoje") or 0) < 2


def _registrar_notificacao(db, vinculo: dict, evento: str, mensagem: str) -> None:
    hoje = date.today().isoformat()
    notifs = (vinculo.get("notifs_hoje") or 0) + 1 if vinculo.get("notifs_reset_dia") == hoje else 1
    db.table("jejum_together").update({
        "evento": evento,
        "mensagem_ia": mensagem,
        "notif_enviada": True,
        "notifs_hoje": notifs,
        "notifs_reset_dia": hoje,
    }).eq("id", vinculo["id"]).execute()
    # Atualiza o dict local para o loop do cron respeitar o limite na mesma rodada
    vinculo["notifs_hoje"] = notifs
    vinculo["notifs_reset_dia"] = hoje


def _detectar_milestone(db, usuario_id: str) -> str | None:
    """Detecta o milestone POSITIVO mais relevante do usuário agora.

    Ordem de prioridade: completo hoje > streak 7 > streak 3 > 50% da meta.
    Interrupções NUNCA geram evento.
    """
    hoje = date.today().isoformat()

    completo = db.table("jejum_registros").select("id") \
        .eq("usuario_id", usuario_id).eq("status", "completo") \
        .gte("finalizado_em", hoje).execute()
    if completo.data:
        return "milestone_completo"

    cfg = db.table("jejum_config").select("sequencia_atual").eq("usuario_id", usuario_id).execute()
    seq = cfg.data[0]["sequencia_atual"] if cfg.data else 0
    if seq == 7:
        return "streak_7"
    if seq == 3:
        return "streak_3"

    ativo = db.table("jejum_registros").select("iniciado_em, meta_horas") \
        .eq("usuario_id", usuario_id).eq("status", "em_andamento").execute()
    if ativo.data and ativo.data[0].get("meta_horas"):
        iniciado = datetime.fromisoformat(ativo.data[0]["iniciado_em"].replace("Z", "+00:00"))
        elapsed_h = (_now() - iniciado).total_seconds() / 3600
        meta = float(ativo.data[0]["meta_horas"])
        if 0.5 <= elapsed_h / meta < 0.6:  # janela para não repetir toda hora
            return "milestone_50pct"

    return None


async def _gerar_mensagem_motivacao(nome_autor: str, evento: str) -> str:
    """Gemini gera 1 frase carinhosa. Fallback estático se a IA falhar."""
    fallbacks = {
        "milestone_completo": f"{nome_autor} concluiu o jejum de hoje! Você consegue também 💪",
        "streak_7": f"Uma semana completa! {nome_autor} está voando ⏱️",
        "streak_3": f"3 dias seguidos! {nome_autor} não para 🌟",
        "milestone_50pct": f"{nome_autor} já passou da metade do jejum! 🦄",
        "incentivo_livre": f"{nome_autor} está na torcida por você! 💜",
    }
    prompt = f"""Gere UMA frase curta de motivação para um app de jejum intermitente em dupla.
Contexto: {nome_autor} atingiu o marco "{evento}". A frase será enviada ao PARCEIRO de jejum.
Regras: português brasileiro, carinhosa, companheirismo (nunca competição), máximo 1 emoji,
sem mencionar peso/dinheiro/comida. Mencione o unicórnio Sweet ou Happy se ficar natural.
Responda APENAS com a frase, sem aspas."""
    try:
        texto = await chamar_gemini({
            "contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"temperature": 0.8, "maxOutputTokens": 80},
        })
        frase = texto.strip().strip('"')
        return frase if frase else fallbacks.get(evento, fallbacks["incentivo_livre"])
    except Exception:
        return fallbacks.get(evento, fallbacks["incentivo_livre"])


def _enviar_push(db, usuario_id: str, titulo: str, corpo: str) -> None:
    """Dispara FCM para o usuário se houver token cadastrado.

    Usa firebase_admin quando disponível; caso contrário apenas loga —
    a mensagem fica persistida em jejum_together e o app exibe no card
    do unicórnio na próxima abertura.
    """
    user = db.table("usuarios").select("fcm_token").eq("id", usuario_id).execute()
    token = user.data[0].get("fcm_token") if user.data else None
    if not token:
        return
    try:
        from firebase_admin import messaging  # type: ignore
        messaging.send(messaging.Message(
            notification=messaging.Notification(title=titulo, body=corpo),
            token=token,
            android=messaging.AndroidConfig(
                notification=messaging.AndroidNotification(channel_id="jejum_motivacao"),
            ),
        ))
    except Exception as exc:
        print(f"[jejum] FCM indisponível ({exc}) — push não enviado, mensagem fica in-app")
