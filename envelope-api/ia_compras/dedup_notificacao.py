"""
Identidade da compra capturada por notificação (anti-duplicata).

A mesma compra pode chegar várias vezes: o celular relê a bandeja do Android ao
abrir o app, e o cartão adicional notifica o celular do titular e o do adicional.
Em vez de uma janela de tempo curta sobre a hora em que o servidor recebeu, a
identidade da compra é: família + valor + loja (normalizada) + HORÁRIO DA
NOTIFICAÇÃO. Duas capturas com a mesma loja e o mesmo valor, de notificações com
até JANELA_MIN minutos de diferença, são a mesma compra, em qualquer estado
(pendente, confirmada ou cancelada). Duas compras iguais de verdade (dois
lanches de R$ 4,00 no mesmo dia) têm horários diferentes e ficam separadas.

Apps antigos não mandam o horário da notificação: para eles vale a regra antiga
(criada há até JANELA_LEGADO_MIN minutos). Quando o app novo relê a bandeja pela
primeira vez, as capturas antigas (sem horário) são reconhecidas pela data
próxima e passam a guardar o horário (adotar_horario), sem criar outra.
"""
import re
import unicodedata
from datetime import datetime, timedelta
from typing import Optional
from zoneinfo import ZoneInfo

JANELA_MIN = 3
JANELA_LEGADO_MIN = 10
# Captura antiga guardava a data da LEITURA: fica até alguns dias depois da compra.
LEGADO_DIAS_ANTES = 1
LEGADO_DIAS_DEPOIS = 4
FONTES = ["nubank", "ifood"]
_FUSO = ZoneInfo("America/Sao_Paulo")


def normalizar(nome: Optional[str]) -> str:
    texto = unicodedata.normalize("NFKD", nome or "").encode("ascii", "ignore").decode().lower()
    return re.sub(r"[^a-z0-9]", "", texto)


def mesma_loja(a: Optional[str], b: Optional[str]) -> bool:
    """Mesmo nome, ou um é o outro cortado (o Android trunca: 'Posto Da Mat...')."""
    na, nb = normalizar(a), normalizar(b)
    if not na or not nb:
        return False
    if na == nb:
        return True
    curto, longo = sorted((na, nb), key=len)
    return len(curto) >= 6 and longo.startswith(curto)


def para_iso(texto: Optional[str]) -> Optional[str]:
    """Horário da notificação em ISO sem fuso, no horário de Brasília."""
    if not texto:
        return None
    try:
        t = datetime.fromisoformat(texto.strip().replace("Z", "+00:00"))
    except ValueError:
        return None
    if t.tzinfo is not None:
        t = t.astimezone(_FUSO).replace(tzinfo=None)
    return t.isoformat(timespec="seconds")


def _base(familia_id: str, valor: float) -> dict:
    return {
        "familia_id": familia_id,
        "fonte": {"$in": FONTES},
        "valor_total": {"$gte": round(valor - 0.005, 3), "$lte": round(valor + 0.005, 3)},
    }


def achar_candidatos(col, familia_id: str, estabelecimento: str, valor: float,
                     notificado_em: Optional[str], agora: Optional[datetime] = None) -> list:
    """Capturas já existentes que são a mesma compra (qualquer estado)."""
    agora = agora or datetime.now()
    achados = []
    limite = (agora - timedelta(minutes=JANELA_LEGADO_MIN)).isoformat()
    if notificado_em:
        t = datetime.fromisoformat(notificado_em)
        janela = {
            "$gte": (t - timedelta(minutes=JANELA_MIN)).isoformat(timespec="seconds"),
            "$lte": (t + timedelta(minutes=JANELA_MIN)).isoformat(timespec="seconds"),
        }
        achados += list(col.find({**_base(familia_id, valor), "notificado_em": janela}))
        # capturas feitas por apps antigos (sem horário): pela data próxima
        d0 = (t.date() - timedelta(days=LEGADO_DIAS_ANTES)).isoformat() + "T00:00:00"
        d1 = (t.date() + timedelta(days=LEGADO_DIAS_DEPOIS)).isoformat() + "T23:59:59"
        achados += list(col.find({**_base(familia_id, valor), "notificado_em": {"$exists": False},
                                  "data_compra": {"$gte": d0, "$lte": d1}}))
    else:
        achados += list(col.find({**_base(familia_id, valor), "created_at": {"$gte": limite}}))
    return [c for c in achados if mesma_loja(c.get("supermercado"), estabelecimento)]


def achar_duplicata(col, familia_id: str, estabelecimento: str, valor: float,
                    notificado_em: Optional[str], agora: Optional[datetime] = None) -> Optional[dict]:
    candidatos = achar_candidatos(col, familia_id, estabelecimento, valor, notificado_em, agora)
    return min(candidatos, key=lambda c: (c.get("created_at", ""), c.get("compra_id", "")), default=None)


def registrar_origem(col, existente: dict, usuario_id: Optional[str]) -> None:
    """Guarda quem mais notificou a mesma compra (ex.: titular e cartão adicional)."""
    if usuario_id:
        col.update_one({"compra_id": existente["compra_id"]}, {"$addToSet": {"origens": str(usuario_id)}})


def registrar_repeticao(col, existente: dict, usuario_id: Optional[str],
                        notificado_em: Optional[str], data_compra: Optional[str]) -> None:
    """Uma captura nova caiu numa já existente: soma a origem e, se a antiga não
    tinha o horário da notificação (app antigo), adota o horário e a data reais."""
    registrar_origem(col, existente, usuario_id)
    if notificado_em and not existente.get("notificado_em"):
        campos = {"notificado_em": notificado_em}
        if data_compra:
            campos["data_compra"] = f"{data_compra}T00:00:00"
        col.update_one({"compra_id": existente["compra_id"]}, {"$set": campos})


def ficar_com_a_mais_antiga(col, doc: dict, notificado_em: Optional[str]) -> Optional[dict]:
    """Duas capturas simultâneas podem passar juntas pela checagem. Depois de
    inserir, se houver outra criada antes, a minha é removida: sobra uma só."""
    outras = [c for c in achar_candidatos(col, doc["familia_id"], doc["supermercado"], doc["valor_total"],
                                          notificado_em) if c.get("compra_id") != doc["compra_id"]]
    anterior = min(outras, key=lambda c: (c.get("created_at", ""), c.get("compra_id", "")), default=None)
    if anterior and (anterior.get("created_at", ""), anterior.get("compra_id", "")) < (doc["created_at"], doc["compra_id"]):
        col.delete_one({"compra_id": doc["compra_id"]})
        return anterior
    return None
