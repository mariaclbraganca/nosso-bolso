from datetime import datetime, timedelta
from ia_compras.models_compras import CategoriaItem

SHELF_LIFE: dict[CategoriaItem, timedelta] = {
    CategoriaItem.HORTIFRUTI:   timedelta(days=6),
    CategoriaItem.PADARIA:      timedelta(days=5),
    CategoriaItem.LATICINIOS:   timedelta(days=14),
    CategoriaItem.PROTEINAS:    timedelta(days=7),
    CategoriaItem.CONGELADOS:   timedelta(days=45),
    CategoriaItem.BEBIDAS:      timedelta(days=30),
    CategoriaItem.LANCHES:      timedelta(days=21),
    CategoriaItem.CARBOIDRATOS: timedelta(days=30),
    CategoriaItem.TEMPEROS:     timedelta(days=60),
    CategoriaItem.LIMPEZA:      timedelta(days=60),
    CategoriaItem.HIGIENE:      timedelta(days=45),
    CategoriaItem.GRAOS:        timedelta(days=45),
    CategoriaItem.OUTROS:       timedelta(days=30),
}


def calcular_data_feedback(data_compra: datetime, categoria: CategoriaItem) -> datetime:
    return data_compra + SHELF_LIFE.get(categoria, timedelta(days=30))
