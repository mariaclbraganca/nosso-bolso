"""Catálogo de exercícios (METs) e cálculo de calorias por atividade.

MET values from Compendium of Physical Activities (Ainsworth et al., 2011).
Formula: kcal = MET × peso_kg × (duracao_min / 60)
"""
from __future__ import annotations

CATALOGO_EXERCICIOS: list[dict] = [
    # Cardio
    {"nome": "Caminhada leve",        "categoria": "cardio",        "met": 2.8},
    {"nome": "Caminhada moderada",    "categoria": "cardio",        "met": 3.5},
    {"nome": "Caminhada rápida",      "categoria": "cardio",        "met": 4.3},
    {"nome": "Corrida (8 km/h)",      "categoria": "cardio",        "met": 8.3},
    {"nome": "Corrida (10 km/h)",     "categoria": "cardio",        "met": 10.0},
    {"nome": "Corrida (12 km/h)",     "categoria": "cardio",        "met": 11.5},
    {"nome": "Ciclismo moderado",     "categoria": "cardio",        "met": 7.5},
    {"nome": "Ciclismo intenso",      "categoria": "cardio",        "met": 10.0},
    {"nome": "Natação",               "categoria": "cardio",        "met": 8.0},
    {"nome": "Pular corda",           "categoria": "cardio",        "met": 11.8},
    {"nome": "HIIT",                  "categoria": "cardio",        "met": 8.0},
    {"nome": "Elíptico",              "categoria": "cardio",        "met": 5.0},
    {"nome": "Remo (ergômetro)",      "categoria": "cardio",        "met": 7.0},
    {"nome": "Escada (stepper)",      "categoria": "cardio",        "met": 9.0},
    # Força
    {"nome": "Musculação (leve)",     "categoria": "forca",         "met": 3.5},
    {"nome": "Musculação (moderada)", "categoria": "forca",         "met": 5.0},
    {"nome": "Musculação (intensa)",  "categoria": "forca",         "met": 6.0},
    {"nome": "Crossfit",              "categoria": "forca",         "met": 7.0},
    {"nome": "Calistenia",            "categoria": "forca",         "met": 5.0},
    {"nome": "Levantamento olímpico", "categoria": "forca",         "met": 6.0},
    # Flexibilidade / mente-corpo
    {"nome": "Yoga",                  "categoria": "flexibilidade", "met": 2.5},
    {"nome": "Pilates",               "categoria": "flexibilidade", "met": 3.0},
    {"nome": "Alongamento",           "categoria": "flexibilidade", "met": 2.3},
    # Esportes
    {"nome": "Futebol",               "categoria": "esporte",       "met": 7.0},
    {"nome": "Basquete",              "categoria": "esporte",       "met": 8.0},
    {"nome": "Tênis",                 "categoria": "esporte",       "met": 7.3},
    {"nome": "Vôlei",                 "categoria": "esporte",       "met": 4.0},
    {"nome": "Artes marciais",        "categoria": "esporte",       "met": 7.0},
    {"nome": "Escalada",              "categoria": "esporte",       "met": 7.5},
    # Lazer / outros
    {"nome": "Dança",                 "categoria": "lazer",         "met": 5.5},
    {"nome": "Surf / Bodyboard",      "categoria": "lazer",         "met": 3.0},
    {"nome": "Skate",                 "categoria": "lazer",         "met": 5.0},
]

# Emoji por categoria (usado no app Flutter)
CATEGORIA_EMOJI: dict[str, str] = {
    "cardio":        "🏃",
    "forca":         "💪",
    "flexibilidade": "🧘",
    "esporte":       "⚽",
    "lazer":         "🎭",
}


def calcular_calorias(met: float, peso_kg: float, duracao_min: int) -> int:
    """Calcula calorias queimadas usando o MET padrão."""
    return max(1, round(met * peso_kg * duracao_min / 60))
