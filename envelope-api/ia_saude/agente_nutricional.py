"""
Agente nutricional: analisa foto/áudio/texto e retorna macros + itens identificados.
Incorpora: fator de cocção (V1), in natura=1.0 (V7), gordura de preparo (V21),
           etanol (V26), clarificação para entradas vagas (V15), unidade_medida (V8).
"""
from __future__ import annotations

import json

from ia_saude.gemini_client import chamar_gemini

# Prompt comprimido: tabelas em uma linha, schema sem valores de exemplo
_PROMPT_ANALISE = """Nutricionista analisando alimentos. Retorne APENAS JSON.

COCÇÃO (peso_cru_g = peso_prato_g / fator): arroz/feijão/lentilha=2.5 | macarrão=2.3 | frango/peixe=0.75 | carne=0.70 | batata=0.80 | ovo cozido=0.88
FATOR 1.0 (sem conversão): frutas cruas, saladas, pães, industrializados, laticínios prontos

UNIDADE: "g"=granel | "ml"=líquidos | "unidade"=embalados/ovos/frutas | "fatia"=pão/queijo fatiado

GORDURA DE PREPARO: adicione item extra com "tipo":"gordura_preparo" se detectar brilho/oleosidade(8-12g) ou marcas de grelha(3-5g). "cozido/vapor/airfryer"=0g. Seja pessimista.

ETANOL: use "tipo":"etanol", 7kcal/g, "pausa_metabolica":true. Nunca classifique como carbo.

CLARIFICAÇÃO: se entrada vaga ("comi muito","rodízio","pratão") retorne:
{"status":"aguardando_clarificacao","pergunta_agente":"pergunta quantificável"}

Se entrada clara, retorne:
{"status":"calculado","descricao":"...","itens_identificados":[{"nome":"","tipo":"alimento","quantidade":0,"unidade_medida":"g","peso_prato_g":0,"fator_coccao":1.0,"peso_cru_g":0,"calorias_kcal":0,"proteina_g":0,"carboidrato_g":0,"gordura_g":0,"fibra_g":0}],"macros_totais":{"calorias_kcal":0,"proteina_g":0,"carboidrato_g":0,"gordura_g":0,"fibra_g":0},"confianca":0.0,"observacao":""}"""


async def _chamar_gemini(parts: list[dict]) -> str:
    return await chamar_gemini({
        "contents": [{"parts": parts}],
        "generationConfig": {"temperature": 0.1, "maxOutputTokens": 1024},
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
    parts = [
        {"inline_data": {"mime_type": mime_type, "data": audio_base64}},
        {"text": "Transcreva e analise nutricionalmente. " + _PROMPT_ANALISE},
    ]
    texto = await _chamar_gemini(parts)
    return _parse_json_resposta(texto)


async def analisar_texto(descricao: str) -> dict:
    prompt = f'Refeição descrita: "{descricao}"\n\n{_PROMPT_ANALISE}'
    texto = await _chamar_gemini([{"text": prompt}])
    return _parse_json_resposta(texto)


async def analisar_refeicao(modalidade: str, dados_entrada: dict) -> dict:
    """Dispatcher: 'foto' | 'audio' | 'texto'"""
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
