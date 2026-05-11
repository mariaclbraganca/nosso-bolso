"""
Agente nutricional: analisa foto/áudio/texto e retorna macros + itens identificados.
Incorpora: fator de cocção (V1), in natura=1.0 (V7), gordura de preparo (V21),
           etanol (V26), clarificação para entradas vagas (V15), unidade_medida (V8).
"""
from __future__ import annotations

import json

from ia_saude.gemini_client import chamar_gemini

_PROMPT_ANALISE = """Você é um nutricionista especializado em análise visual e textual de alimentos.

FATORES DE COCÇÃO — use para calcular peso_cru_g = peso_prato_g / fator_coccao:
arroz branco/integral: 2.5 | macarrão/massa: 2.3 | feijão/lentilha/grão-de-bico: 2.5
frango/peixe: 0.75 | carne bovina/suína: 0.70 | batata-doce/batata: 0.80 | ovo cozido: 0.88

REGRA DE EXCEÇÃO — fator_coccao DEVE ser EXATAMENTE 1.0 para:
- Frutas cruas (maçã, banana, laranja, melancia, etc.)
- Saladas e vegetais crus
- Pães, biscoitos e produtos de padaria
- Produtos industrializados/embalados
- Iogurtes, queijos e laticínios prontos

UNIDADE DE MEDIDA — use o campo "unidade_medida":
- "g"       → alimentos a granel (carne, arroz, legumes)
- "ml"      → líquidos (leite, suco, água, refrigerante)
- "unidade" → produtos embalados inteiros, ovos, frutas
- "fatia"   → pão de forma, queijo fatiado, pizza

GORDURA DE PREPARO — adicione como item extra se detectar:
- Brilho/oleosidade na superfície ou texto "frito/refogado" → 8-12g de azeite/óleo
- Marcas de grelha → 3-5g de azeite
- "cozido/vapor/airfryer" → 0g
- Por padrão seja PESSIMISTA: inclua gordura se houver dúvida.
- Item deve ter "tipo": "gordura_preparo" e "metodo_inferido": "visual" ou "texto".

CATEGORIA ESPECIAL — ETANOL: se identificar bebida alcoólica, use "tipo": "etanol".
Não classifique álcool como carboidrato. Use 7 kcal/g de álcool puro.
Exemplo: taça de vinho 150ml 12% → alcool_puro_g=14, calorias_kcal=98, "pausa_metabolica": true.

REGRA DE CLARIFICAÇÃO: se a entrada contiver expressões vagas como "comi muito",
"bastante", "pratão", "rodízio", "um monte de" — NÃO estime os macros.
Retorne: {"status": "aguardando_clarificacao", "pergunta_agente": "pergunta específica e quantificável"}

Se a entrada for clara, retorne APENAS este JSON:
{
  "status": "calculado",
  "descricao": "nome do prato",
  "itens_identificados": [
    {
      "nome": "arroz branco",
      "tipo": "alimento",
      "quantidade": 150,
      "unidade_medida": "g",
      "peso_prato_g": 150,
      "fator_coccao": 2.5,
      "peso_cru_g": 60,
      "calorias_kcal": 195,
      "proteina_g": 4,
      "carboidrato_g": 43,
      "gordura_g": 0.5,
      "fibra_g": 1
    }
  ],
  "macros_totais": {
    "calorias_kcal": 380,
    "proteina_g": 42,
    "carboidrato_g": 43,
    "gordura_g": 4.5,
    "fibra_g": 3
  },
  "confianca": 0.85,
  "observacao": "porção estimada — margem de ±15%"
}"""


async def _chamar_gemini(parts: list[dict]) -> str:
    return await chamar_gemini({
        "contents": [{"parts": parts}],
        "generationConfig": {"temperature": 0.1, "maxOutputTokens": 2048},
    })


def _parse_json_resposta(texto: str) -> dict:
    try:
        return json.loads(texto)
    except json.JSONDecodeError:
        inicio = texto.find("{")
        fim = texto.rfind("}") + 1
        if inicio >= 0 and fim > inicio:
            return json.loads(texto[inicio:fim])
        raise ValueError("Não foi possível extrair JSON da resposta")


async def analisar_foto(imagem_base64: str, mime_type: str) -> dict:
    parts = [
        {"inline_data": {"mime_type": mime_type, "data": imagem_base64}},
        {"text": _PROMPT_ANALISE},
    ]
    texto = await _chamar_gemini(parts)
    return _parse_json_resposta(texto)


async def analisar_audio(audio_base64: str, mime_type: str) -> dict:
    """Gemini transcreve o áudio e aplica análise nutricional."""
    prompt_audio = (
        "Transcreva este áudio e analise nutricionalmente o que foi descrito. "
        + _PROMPT_ANALISE
    )
    parts = [
        {"inline_data": {"mime_type": mime_type, "data": audio_base64}},
        {"text": prompt_audio},
    ]
    texto = await _chamar_gemini(parts)
    return _parse_json_resposta(texto)


async def analisar_texto(descricao: str) -> dict:
    prompt = f"O usuário descreveu sua refeição assim: \"{descricao}\"\n\n{_PROMPT_ANALISE}"
    parts = [{"text": prompt}]
    texto = await _chamar_gemini(parts)
    return _parse_json_resposta(texto)


async def analisar_refeicao(modalidade: str, dados_entrada: dict) -> dict:
    """
    Dispatcher principal. modalidade: 'foto' | 'audio' | 'texto'
    Retorna dict com status 'calculado' ou 'aguardando_clarificacao'.
    """
    if modalidade == "foto":
        return await analisar_foto(
            dados_entrada["imagem_base64"],
            dados_entrada.get("mime_type", "image/jpeg"),
        )
    if modalidade == "audio":
        return await analisar_audio(
            dados_entrada["audio_base64"],
            dados_entrada.get("mime_type", "audio/mp4"),
        )
    if modalidade == "texto":
        return await analisar_texto(dados_entrada["descricao"])
    raise ValueError(f"Modalidade desconhecida: {modalidade}")
