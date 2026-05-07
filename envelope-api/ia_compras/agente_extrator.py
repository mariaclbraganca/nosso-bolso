from ia_compras.scraper_sefaz import raspar_nfce, extrair_texto_nota, processar_html_pre_raspado
from ia_compras.circuit_breaker import extrair_com_fallback
from ia_compras.models_compras import CategoriaItem
from ia_compras.shelf_life import calcular_data_feedback
from ia_compras.mongo_client import get_compras_collection, get_dicionario_collection
from datetime import datetime
from uuid import uuid4
from typing import Optional
import logging

logger = logging.getLogger(__name__)

EXTRACTION_SCHEMA = {
    "supermercado": "string",
    "data_compra": "YYYY-MM-DD",
    "valor_total": "float",
    "itens": [{
        "nome_original": "string",
        "nome_padronizado": "string legivel",
        "categoria": "enum: Proteínas, Carboidratos, Hortifrúti, Laticínios, Padaria, Bebidas, Lanches, Temperos e Condimentos, Limpeza, Higiene Pessoal, Congelados, Grãos e Cereais, Outros",
        "quantidade": "float",
        "unidade": "un, kg, l, pct, cx",
        "valor_unitario": "float",
        "valor_total_item": "float"
    }]
}


def _validar_grounding(extraido: dict, texto_fonte: str) -> dict:
    """Source grounding: remove itens cujo nome não aparece na fonte (anti-alucinação)."""
    try:
        import langextract as lx
        return lx.validate_grounding(extraido, texto_fonte)
    except Exception:
        texto_lower = texto_fonte.lower()
        itens_validos = []
        for item in extraido.get("itens", []):
            nome = item.get("nome_original", "").lower()
            palavras = [p for p in nome.split() if len(p) > 3]
            if not palavras or any(p in texto_lower for p in palavras):
                itens_validos.append(item)
            else:
                logger.warning(f"Source grounding falhou: {item.get('nome_original')}")
        extraido["itens"] = itens_validos
        return extraido


def _parse_data(valor) -> Optional[datetime]:
    """Aceita 'YYYY-MM-DD', 'YYYY-MM-DDTHH:MM:SS', 'DD/MM/YYYY', etc."""
    if not valor:
        return None
    if isinstance(valor, datetime):
        return valor
    s = str(valor).strip()
    for fmt in ("%Y-%m-%d", "%Y-%m-%dT%H:%M:%S", "%Y-%m-%d %H:%M:%S",
                "%d/%m/%Y", "%d/%m/%Y %H:%M:%S", "%d/%m/%Y %H:%M"):
        try:
            return datetime.strptime(s, fmt)
        except ValueError:
            continue
    try:
        return datetime.fromisoformat(s.replace("Z", "+00:00"))
    except ValueError:
        return None


async def processar_nota(
    qr_code_url: str, familia_id: str, html_payload: Optional[str] = None
) -> dict:
    """Processa uma NFC-e e grava no Mongo.

    Se `html_payload` vier, usa direto (raspagem feita pelo cliente —
    necessário em produção porque a SEFAZ-GO bloqueia o IP do Render).
    Caso contrário, faz o scrape no servidor (fallback / dev local).
    """
    if html_payload:
        html = processar_html_pre_raspado(html_payload)
    else:
        html = raspar_nfce(qr_code_url)
    texto = extrair_texto_nota(html)
    raw, provider = await extrair_com_fallback(texto, EXTRACTION_SCHEMA)
    raw = _validar_grounding(raw, texto)

    # Guarda anti-alucinação do LLM: se Gemini não extraiu itens nem valor
    # consistente, é sinal forte de que a fonte (HTML) era ruim mesmo assim
    # — não gravar pendente lixo, falhar pra UI ver.
    n_itens = len(raw.get("itens", []) or [])
    valor_total_llm = float(raw.get("valor_total", 0) or 0)
    if n_itens == 0 or valor_total_llm <= 0:
        raise RuntimeError(
            f"Não foi possível extrair os dados da nota "
            f"(LLM devolveu {n_itens} itens, valor total R$ {valor_total_llm}). "
            f"Tente escanear de novo ou verifique se a NFC-e está disponível na SEFAZ."
        )

    itens_validados = []
    data_compra = _parse_data(raw.get("data_compra")) or datetime.now()
    for item_raw in raw.get("itens", []):
        try:
            cat = CategoriaItem(item_raw["categoria"])
        except ValueError:
            # CATEGORIA_ENUM_ONLY: categorias inválidas são rejeitadas, não fazem fallback
            logger.warning(f"Categoria rejeitada (CATEGORIA_ENUM_ONLY): {item_raw['categoria']}")
            continue

        preco_un = float(item_raw.get("valor_unitario", 0))
        produto_ref_id = _resolver_produto(
            item_raw["nome_padronizado"], cat, familia_id, preco_un
        )
        data_fb = calcular_data_feedback(data_compra, cat)

        itens_validados.append({
            "nome_original": item_raw["nome_original"],
            "nome_padronizado": item_raw["nome_padronizado"],
            "produto_ref_id": produto_ref_id,
            "categoria": cat.value,
            "quantidade": float(item_raw.get("quantidade", 1)),
            "unidade": item_raw.get("unidade", "un"),
            "valor_unitario": preco_un,
            "valor_total_item": float(item_raw.get("valor_total_item", 0)),
            "status_consumo": "ativo",
            "data_feedback_estimada": data_fb.isoformat(),
        })

    compra_id = str(uuid4())
    doc = {
        "compra_id": compra_id,
        "familia_id": familia_id,
        "data_compra": data_compra.isoformat(),
        "supermercado": raw.get("supermercado", "Desconhecido"),
        "valor_total": float(raw.get("valor_total", 0)),
        "qr_code_url": qr_code_url,
        "status_integracao": "pendente",
        "transacao_supabase_id": None,
        "itens": itens_validados,
        "created_at": datetime.now().isoformat(),
        "llm_provider": provider.value,
    }
    get_compras_collection().insert_one(doc)
    return {"compra_id": compra_id, "status": "processando"}


def _resolver_produto(
    nome_padronizado: str, categoria: CategoriaItem,
    familia_id: str, preco_unitario: float = 0.0
) -> Optional[str]:
    dic = get_dicionario_collection()
    existente = dic.find_one({"familia_id": familia_id, "nome_canonico": nome_padronizado})
    if existente:
        update: dict = {"$addToSet": {"sinonimos_llm": nome_padronizado}}
        if preco_unitario > 0:
            preco_atual = existente.get("preco_medio", 0.0)
            novo_preco = (preco_atual + preco_unitario) / 2 if preco_atual > 0 else preco_unitario
            update["$set"] = {"preco_medio": round(novo_preco, 2)}
        dic.update_one({"_id": existente["_id"]}, update)
        return str(existente["_id"])
    novo = dic.insert_one({
        "familia_id": familia_id,
        "nome_canonico": nome_padronizado,
        "categoria": categoria.value,
        "sinonimos_llm": [nome_padronizado],
        "preco_medio": preco_unitario,
        "unidade_padrao": "un",
        "created_at": datetime.now().isoformat(),
    })
    return str(novo.inserted_id)
