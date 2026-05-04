import os
import json
from datetime import datetime
from google import genai
from ia_compras.models_compras import ListaComprasGerada, ItemLista, CategoriaItem
import logging

logger = logging.getLogger(__name__)
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "")
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
_client: genai.Client | None = None


def _get_client() -> genai.Client:
    global _client
    if _client is None:
        _client = genai.Client(api_key=GEMINI_API_KEY)
    return _client


def gerar_lista_inteligente(
    familia_id: str, dias: int, saldo: float, estoque: dict, perfil: dict
) -> ListaComprasGerada:
    prompt = _montar_prompt(dias, saldo, estoque, perfil)
    try:
        resp = _get_client().models.generate_content(model=GEMINI_MODEL, contents=prompt)
        raw = _extrair_json(resp.text)
        return _parse_lista(familia_id, dias, saldo, raw)
    except Exception as e:
        logger.error(f"Gemini orquestrador falhou: {e}")
        return _fallback_lista(familia_id, dias, saldo, estoque, perfil)


def _extrair_json(text: str) -> dict:
    """Tolerante a ```json ... ``` e texto extra."""
    if not text:
        return {}
    s = text.strip()
    if s.startswith("```"):
        # remove cerca markdown
        s = s.split("```", 2)[1] if s.count("```") >= 2 else s
        if s.startswith("json"):
            s = s[4:].lstrip()
        if s.endswith("```"):
            s = s[:-3]
    try:
        return json.loads(s)
    except json.JSONDecodeError:
        start = s.find("{")
        end = s.rfind("}") + 1
        if start >= 0 and end > start:
            return json.loads(s[start:end])
        raise


def _montar_prompt(dias: int, saldo: float, estoque: dict, perfil: dict) -> str:
    schema = {
        "itens": [{"nome": "str", "categoria": "CategoriaItem", "quantidade_sugerida": "float",
                   "unidade": "str", "preco_estimado": "float", "motivo": "str", "corte_sugerido": "bool"}],
        "custo_estimado_total": "float", "dentro_do_orcamento": "bool",
    }
    return (
        f"Assistente de compras para {dias} dias. Saldo disponível: R$ {saldo:.2f}.\n"
        f"Perfil da família: {json.dumps(perfil, ensure_ascii=False, default=str)}\n"
        f"Estoque atual: {json.dumps(estoque, ensure_ascii=False, default=str)}\n"
        f"Retorne APENAS JSON válido seguindo este schema: {json.dumps(schema)}\n"
        f"Considere o saldo e sugira corte_sugerido=true nos itens que estouram o orçamento."
    )


def _parse_lista(familia_id: str, dias: int, saldo: float, raw: dict) -> ListaComprasGerada:
    itens = []
    for i in raw.get("itens", []):
        try:
            cat = CategoriaItem(i["categoria"]).value
        except ValueError:
            cat = CategoriaItem.OUTROS.value
        itens.append(ItemLista(
            nome=i["nome"], categoria=cat,
            quantidade_sugerida=float(i.get("quantidade_sugerida", 1)),
            unidade=i.get("unidade", "un"),
            preco_estimado=float(i.get("preco_estimado", 0)),
            motivo=i.get("motivo", ""),
            corte_sugerido=bool(i.get("corte_sugerido", False)),
        ))
    custo = float(raw.get("custo_estimado_total", sum(i.preco_estimado for i in itens)))
    return ListaComprasGerada(
        familia_id=familia_id, dias_cobertura=dias, saldo_envelope=saldo,
        custo_estimado_total=round(custo, 2),
        dentro_do_orcamento=bool(raw.get("dentro_do_orcamento", custo <= saldo)),
        itens=itens, gerado_em=datetime.now(),
    )


def _fallback_lista(
    familia_id: str, dias: int, saldo: float, estoque: dict, perfil: dict
) -> ListaComprasGerada:
    from ia_compras.mongo_client import get_dicionario_collection
    cesta = perfil.get("cesta_basica_inegociavel", [])
    itens: list[ItemLista] = []
    custo = 0.0
    for nome in cesta:
        if nome not in estoque or estoque[nome].get("consumido"):
            doc = get_dicionario_collection().find_one({"nome_canonico": nome})
            preco = doc["preco_medio"] if doc and doc.get("preco_medio", 0) > 0 else 10.0
            itens.append(ItemLista(
                nome=nome, categoria=CategoriaItem.OUTROS.value,
                quantidade_sugerida=1.0, unidade="un", preco_estimado=preco,
                motivo="Cesta básica - fallback local",
                corte_sugerido=custo + preco > saldo,
            ))
            custo += preco
    return ListaComprasGerada(
        familia_id=familia_id, dias_cobertura=dias, saldo_envelope=saldo,
        custo_estimado_total=round(custo, 2), dentro_do_orcamento=custo <= saldo,
        itens=itens, gerado_em=datetime.now(),
    )
