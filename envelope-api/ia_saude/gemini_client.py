"""Cliente Gemini centralizado com rotação automática de chaves na cota esgotada (429)."""
from __future__ import annotations

import asyncio
import os
from typing import Any

import httpx

GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
_GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"


def _carregar_chaves() -> list[str]:
    """Lê GEMINI_API_KEY_1/2/3 e, como fallback, GEMINI_API_KEY."""
    chaves = []
    for i in (1, 2, 3):
        k = os.environ.get(f"GEMINI_API_KEY_{i}", "").strip()
        if k:
            chaves.append(k)
    fallback = os.environ.get("GEMINI_API_KEY", "").strip()
    if fallback and fallback not in chaves:
        chaves.append(fallback)
    return chaves


async def chamar_gemini(payload: dict[str, Any], model: str | None = None) -> str:
    """
    Envia payload para a API Gemini e retorna o texto da resposta.

    Rotação de chaves: ao receber 429 (cota esgotada) tenta a próxima chave
    imediatamente. Para outros erros 5xx faz backoff exponencial na mesma chave.
    Lança RuntimeError se todas as chaves falharem.
    """
    chaves = _carregar_chaves()
    if not chaves:
        raise RuntimeError(
            "Nenhuma chave Gemini configurada. "
            "Defina GEMINI_API_KEY_1, GEMINI_API_KEY_2 ou GEMINI_API_KEY."
        )

    url = _GEMINI_URL.format(model=model or GEMINI_MODEL)
    ultimo_erro: Exception | None = None

    for chave in chaves:
        for tentativa in range(3):
            try:
                async with httpx.AsyncClient(timeout=60.0) as client:
                    resp = await client.post(url, params={"key": chave}, json=payload)

                    if resp.status_code == 429:
                        # Cota esgotada nesta chave → tenta a próxima imediatamente
                        ultimo_erro = Exception(f"429 cota esgotada (chave ...{chave[-6:]})")
                        break  # sai do loop de tentativas, avança para próxima chave

                    if resp.status_code in (500, 502, 503, 504):
                        ultimo_erro = Exception(f"HTTP {resp.status_code}: {resp.text[:200]}")
                        await asyncio.sleep(2 ** tentativa)
                        continue

                    if resp.status_code == 400:
                        body = resp.text[:300]
                        raise RuntimeError(f"Gemini rejeitou a requisição (400): {body}")

                    resp.raise_for_status()
                    data = resp.json()
                    return data["candidates"][0]["content"]["parts"][0]["text"]

            except (httpx.TimeoutException, httpx.ConnectError) as e:
                ultimo_erro = e
                await asyncio.sleep(2 ** tentativa)

    raise RuntimeError(
        f"Gemini falhou em todas as {len(chaves)} chave(s). Último erro: {ultimo_erro}"
    )
