import os
import json
import logging
from datetime import datetime
import httpx
from ia_compras.models_compras import ListaComprasGerada, ItemLista, CategoriaItem

logger = logging.getLogger(__name__)


def _chamar_gemini(prompt: str) -> str:
    """Chamada síncrona ao Gemini via REST (sem o SDK google-genai, que não é
    dependência obrigatória)."""
    # Lê em runtime para pegar o valor carregado pelo carregar_config_do_supabase()
    api_key = os.environ.get("GEMINI_API_KEY", "")
    model = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
    if not api_key:
        raise RuntimeError("GEMINI_API_KEY não configurada")
    url = f"https://generativelanguage.googleapis.com/v1/models/{model}:generateContent"
    with httpx.Client(timeout=45.0) as client:
        resp = client.post(
            url,
            params={"key": api_key},
            json={"contents": [{"parts": [{"text": prompt}]}]},
        )
        resp.raise_for_status()
        data = resp.json()
        return data["candidates"][0]["content"]["parts"][0]["text"]


def gerar_lista_inteligente(
    familia_id: str, dias: int, saldo: float, estoque: dict, perfil: dict
) -> ListaComprasGerada:
    prompt = _montar_prompt(dias, saldo, estoque, perfil)
    try:
        text = _chamar_gemini(prompt)
        raw = _extrair_json(text)
        return _parse_lista(familia_id, dias, saldo, raw)
    except Exception as e:
        logger.error(f"Gemini orquestrador falhou: {e}", exc_info=True)
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


def _buscar_preco_e_categoria(nome: str, familia_id: str) -> tuple[float, str, str]:
    """Devolve (preco_medio, categoria, unidade) para um item da cesta básica.

    Estratégia em ordem (do mais confiável pro menos):
    1) Dicionário da própria família (já viu o item antes)
    2) Dicionário de qualquer família (média global do produto)
    3) None — não chutamos preço; o caller decide o que fazer
    """
    from ia_compras.mongo_client import get_dicionario_collection
    dic = get_dicionario_collection()

    # 1) próprio histórico da família
    doc = dic.find_one({"familia_id": familia_id, "nome_canonico": nome})
    if doc and (doc.get("preco_medio") or 0) > 0:
        return (
            float(doc["preco_medio"]),
            doc.get("categoria", CategoriaItem.OUTROS.value),
            doc.get("unidade_padrao", "un"),
        )

    # 2) média global (qualquer família que já tenha esse item)
    cursor = dic.find(
        {"nome_canonico": nome, "preco_medio": {"$gt": 0}},
        {"preco_medio": 1, "categoria": 1, "unidade_padrao": 1},
    )
    precos = []
    cat = CategoriaItem.OUTROS.value
    unidade = "un"
    for d in cursor:
        precos.append(float(d["preco_medio"]))
        cat = d.get("categoria", cat)
        unidade = d.get("unidade_padrao", unidade)
    if precos:
        return (sum(precos) / len(precos), cat, unidade)

    # 3) sem histórico
    return (0.0, CategoriaItem.OUTROS.value, "un")


def _quantidade_por_dias(dias: int) -> float:
    """Heurística simples: 1 unidade base cobre 7 dias.

    Sem ML/shelf_life nesta camada — esse é o fallback. Para 7 dias devolve
    1, para 15 devolve 2, para 30 devolve 4. Garante mínimo 1.
    """
    import math
    return max(1.0, float(math.ceil(dias / 7)))


def _fallback_lista(
    familia_id: str, dias: int, saldo: float, estoque: dict, perfil: dict
) -> ListaComprasGerada:
    """Fallback puro-Python quando o Gemini falha.

    Diferente do scraper antigo (que chutava preço=R$10), este:
    - Usa preco_medio do dicionário (família, depois global) como autoridade.
    - Marca itens sem histórico com preco_estimado=0 e motivo claro
      ('Sem histórico de preço') — não inventa valor.
    - Escala quantidade_sugerida pela duração em dias.
    - Lê categoria/unidade do dicionário em vez de assumir OUTROS/un.
    - Marca corte_sugerido=true acumulando custo (greedy) e
      considera 'dentro_do_orcamento' como falso se houver item sem preço
      (não dá pra afirmar que cabe no orçamento se não conhecemos o custo).
    """
    cesta = perfil.get("cesta_basica_inegociavel", [])
    qtd_base = _quantidade_por_dias(dias)
    itens: list[ItemLista] = []
    custo_conhecido = 0.0
    tem_item_sem_preco = False

    for nome in cesta:
        # pular se já tem em estoque (e não venceu)
        if nome in estoque and not estoque[nome].get("consumido"):
            continue

        preco_medio, cat_str, unidade = _buscar_preco_e_categoria(nome, familia_id)
        try:
            cat = CategoriaItem(cat_str).value
        except ValueError:
            cat = CategoriaItem.OUTROS.value

        custo_item = preco_medio * qtd_base
        if preco_medio == 0:
            tem_item_sem_preco = True
            motivo = "Cesta básica — sem histórico de preço, verifique no mercado"
            corte = False
        else:
            motivo = f"Cesta básica · ~R$ {preco_medio:.2f}/un (média histórica)"
            corte = (custo_conhecido + custo_item) > saldo
            custo_conhecido += custo_item

        itens.append(ItemLista(
            nome=nome,
            categoria=cat,
            quantidade_sugerida=qtd_base,
            unidade=unidade,
            preco_estimado=round(custo_item, 2),
            motivo=motivo,
            corte_sugerido=corte,
        ))

    # Pessimista: se algum item está sem preço, não afirmamos que cabe
    dentro = (custo_conhecido <= saldo) and not tem_item_sem_preco

    return ListaComprasGerada(
        familia_id=familia_id, dias_cobertura=dias, saldo_envelope=saldo,
        custo_estimado_total=round(custo_conhecido, 2),
        dentro_do_orcamento=dentro,
        itens=itens, gerado_em=datetime.now(),
    )
