"""
Compra parcelada no cartão: a 1ª parcela é compra do mês (transação) e as
parcelas 2..n viram um lançamento futuro em cartao_compromissos.

As duas gravações andam juntas: se a das parcelas futuras falhar, a transação
é desfeita, para o "Futuro" nunca ficar sem as parcelas de uma compra lançada.
"""
from fastapi import HTTPException


def somar_meses(mes: str, n: int) -> str:
    total = int(mes[:4]) * 12 + int(mes[5:7]) - 1 + n
    return f"{total // 12}-{total % 12 + 1:02d}"


def valor_parcela(total: float, parcelas: int) -> float:
    return round(float(total) / parcelas, 2)


def compromisso_da_parcelada(fam: str, descricao: str, valor_parcela: float, parcelas: int, mes_compra: str) -> dict:
    """Parcelas 2..n: a 1ª vem na fatura do mês seguinte à compra; a 2ª na
    fatura de dois meses depois."""
    return {
        "familia_id": fam, "descricao": descricao, "valor": valor_parcela,
        "mes_fatura": somar_meses(mes_compra, 2), "parcela_atual": 2, "total_parcelas": parcelas,
    }


def gravar_parcelas_ou_desfazer(db, transacao_id: str, compromisso: dict) -> None:
    """Grava as parcelas futuras; se falhar, apaga a transação recém-criada."""
    try:
        r = db.table("cartao_compromissos").insert(compromisso).execute()
        if not r.data:
            raise RuntimeError("insert sem retorno")
    except Exception as exc:
        db.table("transacoes").delete().eq("id", transacao_id).execute()
        raise HTTPException(
            500, f"Não consegui registrar as parcelas futuras; a compra não foi lançada. Tente de novo. ({exc})"
        )
