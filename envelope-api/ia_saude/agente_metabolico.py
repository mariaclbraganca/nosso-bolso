"""Motor de cálculo metabólico: TMB, TDEE, macros, desconto de suplementos."""
from __future__ import annotations

FATOR_ATIVIDADE: dict[str, float] = {
    "sedentario":    1.2,
    "leve":          1.375,
    "moderado":      1.55,
    "intenso":       1.725,
    "muito_intenso": 1.9,
}

AJUSTE_OBJETIVO_KCAL: dict[str, int] = {
    "perda_peso":  -500,
    "manutencao":   0,
    "ganho_massa": +250,
}

# Distribuição percentual de macros por objetivo
_MACRO_PCT: dict[str, dict[str, float]] = {
    "perda_peso":  {"proteina": 0.30, "carbo": 0.40, "gordura": 0.30},
    "manutencao":  {"proteina": 0.25, "carbo": 0.45, "gordura": 0.30},
    "ganho_massa": {"proteina": 0.25, "carbo": 0.45, "gordura": 0.30},
}


def calcular_tmb(peso_kg: float, altura_cm: float, idade: int, sexo: str) -> float:
    """Mifflin-St Jeor. sexo: 'M' | 'F'.

    Aceita altura em metros (< 3.0) e converte automaticamente para cm.
    """
    if altura_cm < 3.0:
        altura_cm = altura_cm * 100
    base = 10 * peso_kg + 6.25 * altura_cm - 5 * idade
    return base + 5 if sexo.upper() == "M" else base - 161


def calcular_tdee(tmb: float, nivel_atividade: str, usa_registro_exercicio: bool = False) -> float:
    """
    TDEE = TMB × fator de atividade.
    Se usa_registro_exercicio=True, força fator sedentário (1.2 = NEAT puro).
    O exercício intencional será somado dinamicamente pelo módulo de exercício (V10).
    """
    fator = 1.2 if usa_registro_exercicio else FATOR_ATIVIDADE.get(nivel_atividade, 1.2)
    return round(tmb * fator, 1)


def calcular_meta_calorica(tdee: float, objetivo: str) -> float:
    ajuste = AJUSTE_OBJETIVO_KCAL.get(objetivo, 0)
    return round(tdee + ajuste, 1)


def calcular_macros(meta_kcal: float, objetivo: str) -> dict:
    pct = _MACRO_PCT.get(objetivo, _MACRO_PCT["manutencao"])
    return {
        "proteina_total_g":  round(meta_kcal * pct["proteina"] / 4),
        "carboidrato_g":     round(meta_kcal * pct["carbo"] / 4),
        "gordura_g":         round(meta_kcal * pct["gordura"] / 9),
    }


def descontar_suplementos(macros: dict, suplementos: list[dict]) -> dict:
    proteina_sup = sum(
        s.get("proteina_g_por_dose", 0)
        for s in suplementos
        if s.get("frequencia") == "diária" and s.get("proteina_g_por_dose", 0) > 0
    )
    macros["proteina_suplemento_g"] = round(proteina_sup)
    macros["proteina_via_comida_g"] = max(0, macros["proteina_total_g"] - round(proteina_sup))
    return macros


def calcular_meta_agua_ml(peso_kg: float) -> int:
    """35–40 ml/kg → média 37.5 ml/kg."""
    return round(peso_kg * 37.5)


def calcular_meta_fibra_g(peso_kg: float) -> int:
    """14 g por 1000 kcal é a referência; simplificado: max(25, 0.14 × peso_kg × 10)."""
    return max(25, round(peso_kg * 1.4))


def calcular_perfil_completo(perfil: dict) -> dict:
    """
    Recalcula todas as métricas metabólicas a partir do documento de perfil.
    Retorna dict com campos prontos para upsert em 'metabolico'.
    """
    antro = perfil.get("antropometria", {})
    objetivo = perfil.get("metabolico", {}).get("objetivo", "manutencao")
    nivel_atividade = perfil.get("metabolico", {}).get("nivel_atividade", "sedentario")
    usa_reg_exercicio = perfil.get("metabolico", {}).get("usa_registro_exercicio", False)
    suplementos = perfil.get("anamnese", {}).get("suplementos", [])

    tmb = calcular_tmb(
        peso_kg=antro.get("peso_kg", 70),
        altura_cm=antro.get("altura_cm", 170),
        idade=antro.get("idade", 30),
        sexo=antro.get("sexo", "M"),
    )
    tdee = calcular_tdee(tmb, nivel_atividade, usa_reg_exercicio)
    meta = calcular_meta_calorica(tdee, objetivo)
    macros = calcular_macros(meta, objetivo)
    macros = descontar_suplementos(macros, suplementos)
    peso = antro.get("peso_kg", 70)
    meta_agua = calcular_meta_agua_ml(peso)
    meta_fibra = calcular_meta_fibra_g(peso)

    return {
        "tmb_kcal": round(tmb),
        "tdee_kcal": round(tdee),
        "meta_calorica_kcal": round(meta),
        "proteina_suplemento_g": macros["proteina_suplemento_g"],
        "metas_macros": {
            "proteina_total_g":      macros["proteina_total_g"],
            "proteina_via_comida_g": macros["proteina_via_comida_g"],
            "carboidrato_g":         macros["carboidrato_g"],
            "gordura_g":             macros["gordura_g"],
        },
        "meta_agua_ml":  meta_agua,
        "meta_fibra_g":  meta_fibra,
        "nivel_atividade": nivel_atividade,
        "objetivo": objetivo,
        "usa_registro_exercicio": usa_reg_exercicio,
    }
