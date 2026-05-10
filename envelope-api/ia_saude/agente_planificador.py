"""
Agente planificador: sugere jantar com base em saldo de macros + estoque + shelf_life.
Incorpora: Cesta de Foco (V13), coerência gastronômica (V16), refeição familiar (V18),
           micro-inventário preditivo (V28), ROI proteico (V23).
"""
from __future__ import annotations

import json
import os
import asyncio
import httpx
from datetime import datetime, timezone

GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")

# ── Categorias nutricionais ───────────────────────────────────────────────────

_CAT_PROTEINA  = {"Proteínas", "Laticínios"}
_CAT_CARBO_VEG = {"Carboidratos", "Hortifrúti", "Grãos e Cereais", "Padaria"}

_TEMPEROS_ASSUMIDOS = ["sal", "azeite", "alho", "cebola", "pimenta", "limão", "vinagre"]

# Limiar de dias restantes para levantar suspeita de "furo de geladeira" (V28)
_RISCO_FURO_CATEGORIAS = {"Laticínios", "Hortifrúti", "Proteínas", "Padaria"}
_RISCO_FURO_DIAS = 4  # se vence em ≤ 4 dias, confirma com o usuário


# ── Helpers internos ──────────────────────────────────────────────────────────

def _get_gemini_key() -> str:
    key = os.environ.get("GEMINI_API_KEY", "")
    if not key:
        raise RuntimeError("GEMINI_API_KEY não configurada")
    return key


async def _chamar_gemini(parts: list[dict]) -> str:
    api_key = _get_gemini_key()
    url = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
    payload = {
        "contents": [{"parts": parts}],
        "generationConfig": {"temperature": 0.4, "maxOutputTokens": 2048},
    }
    last_err: Exception | None = None
    for tentativa in range(3):
        try:
            async with httpx.AsyncClient(timeout=60.0) as client:
                resp = await client.post(url, params={"key": api_key}, json=payload)
                if resp.status_code in (429, 500, 502, 503, 504):
                    last_err = Exception(f"HTTP {resp.status_code}")
                    await asyncio.sleep(2 ** tentativa)
                    continue
                resp.raise_for_status()
                data = resp.json()
                return data["candidates"][0]["content"]["parts"][0]["text"]
        except (httpx.TimeoutException, httpx.ConnectError) as e:
            last_err = e
            await asyncio.sleep(2 ** tentativa)
    raise RuntimeError(f"Gemini falhou: {last_err}")


def _parse_json(texto: str) -> dict:
    try:
        return json.loads(texto)
    except json.JSONDecodeError:
        inicio = texto.find("{")
        fim = texto.rfind("}") + 1
        if inicio >= 0 and fim > inicio:
            return json.loads(texto[inicio:fim])
        raise ValueError("Não foi possível extrair JSON da resposta")


# ── Cesta de Foco — V13 ───────────────────────────────────────────────────────

def selecionar_cesta_de_foco(estoque: dict) -> dict:
    """
    Pré-filtro determinístico: seleciona ≤10 ingredientes focados para o prompt.
    Prioriza: proteínas + carbos/vegetais mais próximos do vencimento.
    """
    ativos = [
        item for item in estoque.values()
        if not item.get("consumido") and item.get("quantidade", 0) > 0
    ]

    proteinas = sorted(
        [i for i in ativos if i["categoria"] in _CAT_PROTEINA],
        key=lambda x: x["dias_restantes"],
    )[:3]

    carbos_veg = sorted(
        [i for i in ativos
         if i["categoria"] in _CAT_CARBO_VEG and i["dias_restantes"] <= 5],
        key=lambda x: x["dias_restantes"],
    )[:5]

    if not carbos_veg:
        # Se nenhum vence em ≤5 dias, pega os 5 mais urgentes de qualquer prazo
        carbos_veg = sorted(
            [i for i in ativos if i["categoria"] in _CAT_CARBO_VEG],
            key=lambda x: x["dias_restantes"],
        )[:5]

    return {
        "ingredientes_foco":  proteinas + carbos_veg,
        "temperos_assumidos": _TEMPEROS_ASSUMIDOS,
    }


# ── Micro-inventário preditivo — V28 ─────────────────────────────────────────

def identificar_itens_suspeitos(estoque: dict) -> list[dict]:
    """
    Retorna itens de categorias frigo que vencem em ≤ N dias.
    Frontend deve perguntar 'ainda tem esse ingrediente?' antes de montar receita.
    """
    return [
        {
            "nome":               item["nome"],
            "quantidade_esperada": item["quantidade"],
            "dias_restantes":     item["dias_restantes"],
        }
        for item in estoque.values()
        if (
            not item.get("consumido")
            and item.get("quantidade", 0) > 0
            and item["categoria"] in _RISCO_FURO_CATEGORIAS
            and 0 < item["dias_restantes"] <= _RISCO_FURO_DIAS
        )
    ]


# ── Cálculo de saldo do dia ───────────────────────────────────────────────────

def _calcular_saldo_membro(perfil: dict, refeicoes_dia: list) -> dict:
    metabolico = perfil.get("metabolico", {})
    metas = metabolico.get("metas_macros", {})
    meta_kcal = metabolico.get("meta_calorica_kcal", 2000)

    consumido = {"calorias_kcal": 0.0, "proteina_g": 0.0, "carboidrato_g": 0.0, "gordura_g": 0.0}
    for ref in refeicoes_dia:
        if ref.get("is_jejum") or ref.get("deleted_at"):
            continue
        m = ref.get("macros_totais", {})
        consumido["calorias_kcal"]  += m.get("calorias_kcal", 0)
        consumido["proteina_g"]     += m.get("proteina_g", 0)
        consumido["carboidrato_g"]  += m.get("carboidrato_g", 0)
        consumido["gordura_g"]      += m.get("gordura_g", 0)

    return {
        "calorias_kcal":  max(0, meta_kcal - consumido["calorias_kcal"]),
        "proteina_g":     max(0, metas.get("proteina_via_comida_g", 0) - consumido["proteina_g"]),
        "carboidrato_g":  max(0, metas.get("carboidrato_g", 0) - consumido["carboidrato_g"]),
        "gordura_g":      max(0, metas.get("gordura_g", 0) - consumido["gordura_g"]),
        "objetivo":       metabolico.get("objetivo", "manutencao"),
        "nome_membro":    perfil.get("anamnese", {}).get("nome_curto", perfil.get("membro_id", "")),
    }


# ── Prompt do Gemini ──────────────────────────────────────────────────────────

def _montar_prompt(membros_saldo: list[dict], cesta: dict, aversoes: list[str]) -> str:
    membros_txt = "\n".join(
        f"- {m['nome_membro']} (Objetivo: {m['objetivo']}): "
        f"{m['calorias_kcal']:.0f} kcal restantes | "
        f"Proteína: {m['proteina_g']:.0f}g | Carbo: {m['carboidrato_g']:.0f}g | "
        f"Gordura: {m['gordura_g']:.0f}g"
        for m in membros_saldo
    )

    ingredientes_txt = "\n".join(
        f"- {i['nome']} ({i['quantidade']:.0f}g disponíveis, vence em {i['dias_restantes']}d)"
        for i in cesta["ingredientes_foco"]
    ) or "Nenhum ingrediente crítico identificado — use o que julgar adequado."

    restricoes_txt = ", ".join(aversoes) if aversoes else "Nenhuma"

    multi_membro = len(membros_saldo) > 1
    regra_porcao = (
        "REGRA OBRIGATÓRIA: Sugira UMA única receita (mesma panela) com porções DIFERENTES "
        "para cada pessoa listada. Não sugira receitas separadas, salvo impossibilidade."
        if multi_membro else ""
    )

    return f"""Você é um nutricionista e chef especialista em refeições práticas e saudáveis.

CONTEXTO DA(S) PESSOA(S) — saldo de macros restante no dia:
{membros_txt}

INGREDIENTES EM FOCO (priorizados por vencimento próximo):
{ingredientes_txt}

TEMPEROS BÁSICOS SEMPRE DISPONÍVEIS (não liste como ingrediente):
{', '.join(cesta['temperos_assumidos'])}

RESTRIÇÕES ALIMENTARES: {restricoes_txt}

{regra_porcao}

REGRAS DE COERÊNCIA GASTRONÔMICA:
- NUNCA misture frutas doces + carnes salgadas na mesma receita
- NUNCA misture iogurte + feijão + peixe na mesma receita
- Cada prato: no máximo 2 ingredientes principais além dos temperos
- Se ingredientes disponíveis não formam prato coerente, prefira:
  a) Duas refeições separadas (prato + sobremesa)
  b) Alertar sobre o que está por vencer e ignorar o incompatível

Sugira 3 opções de jantar usando APENAS ingredientes disponíveis.
Para cada opção, inclua uma substituição caso falte o ingrediente principal.

Retorne APENAS JSON com esta estrutura:
{{
  "sugestoes": [
    {{
      "nome": "Peito de Frango Grelhado com Batata-Doce",
      "ingredientes_usados": [{{"nome": "frango", "quantidade_g": 150}}],
      "preparo_minutos": 20,
      "modo_preparo_resumido": "Tempere o frango e grelhe em fogo médio por 8 min cada lado.",
      "substituicoes": ["sem frango -> 3 ovos inteiros"],
      "porcoes_por_membro": [
        {{
          "nome_membro": "Nome",
          "quantidade_g": 350,
          "calorias_kcal": 380,
          "proteina_g": 42,
          "carboidrato_g": 35,
          "gordura_g": 8
        }}
      ],
      "macros_totais": {{
        "calorias_kcal": 380,
        "proteina_g": 42,
        "carboidrato_g": 35,
        "gordura_g": 8
      }}
    }}
  ]
}}"""


# ── Função principal ──────────────────────────────────────────────────────────

async def sugerir_jantar(
    membro_ids: list[str],
    familia_id: str,
    itens_confirmados_ausentes: list[str] | None = None,
) -> dict:
    """
    Sugere jantar para um ou mais membros da família.

    Args:
        membro_ids: lista de membro_ids (suporte familiar V18)
        familia_id: ID da família
        itens_confirmados_ausentes: nomes de itens que o usuário confirmou que não estão na geladeira (V28)

    Returns:
        {
          "sugestoes": [...],
          "itens_suspeitos": [...],  # para confirmação de micro-inventário (V28)
          "cesta_usada": [...]
        }
    """
    from ia_compras.agente_estoque import analisar_estoque
    from ia_saude.mongo_client_saude import get_perfil_metabolico_col, get_registro_refeicoes_col

    hoje = datetime.now(timezone.utc).date().isoformat()

    # 1. Carrega perfis e refeições de hoje para cada membro
    perfil_col = get_perfil_metabolico_col()
    ref_col    = get_registro_refeicoes_col()

    membros_saldo: list[dict] = []
    todas_aversoes: set[str]  = set()

    for mid in membro_ids:
        perfil = perfil_col.find_one({"membro_id": mid})
        if not perfil:
            continue
        refeicoes = list(ref_col.find(
            {"membro_id": mid, "data_refeicao": hoje, "deleted_at": None}
        ))
        saldo = _calcular_saldo_membro(perfil, refeicoes)
        membros_saldo.append(saldo)

        anamnese = perfil.get("anamnese", {})
        todas_aversoes.update(anamnese.get("aversoes", []))
        todas_aversoes.update(anamnese.get("alergias", []))

    if not membros_saldo:
        raise ValueError("Nenhum perfil metabólico encontrado para os membros informados")

    # 2. Carrega e filtra estoque
    estoque = analisar_estoque(familia_id)

    # Remove itens que o usuário confirmou ausentes (V28)
    if itens_confirmados_ausentes:
        ausentes_lower = {n.lower() for n in itens_confirmados_ausentes}
        estoque = {
            k: v for k, v in estoque.items()
            if k.lower() not in ausentes_lower
        }

    # 3. Micro-inventário preditivo — itens suspeitos de não estar mais lá (V28)
    itens_suspeitos = identificar_itens_suspeitos(estoque)

    # 4. Cesta de Foco — max 10 itens para o Gemini (V13)
    cesta = selecionar_cesta_de_foco(estoque)

    # 5. Chama Gemini
    prompt = _montar_prompt(membros_saldo, cesta, list(todas_aversoes))
    texto = await _chamar_gemini([{"text": prompt}])
    resultado = _parse_json(texto)

    return {
        "sugestoes":      resultado.get("sugestoes", []),
        "itens_suspeitos": itens_suspeitos,
        "cesta_usada":    [i["nome"] for i in cesta["ingredientes_foco"]],
    }
