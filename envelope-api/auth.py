"""Autenticação JWT via Supabase Auth.

Toda rota que recebe `user: AuthUser = Depends(get_current_user)` exige um
header `Authorization: Bearer <jwt>` com um token válido emitido pelo
Supabase Auth (mesmo JWT que o Flutter já tem em
`Supabase.instance.client.auth.currentSession`).

A validação chama `supabase.auth.get_user(jwt)` — o próprio Supabase
verifica assinatura e expiração. Não precisamos manter o JWT secret no
backend (poderia ser otimizado depois com PyJWT local + cache).

Antes desse middleware, o cliente enviava `familia_id` e `usuario_id` no
payload e o backend confiava cego — qualquer um com a URL da API podia
ler/escrever em qualquer família trocando o UUID. Com `get_current_user`
o `familia_id` e `usuario_id` vêm do JWT verificado, não do cliente.
"""
from dataclasses import dataclass
from typing import Optional

from fastapi import Depends, Header, HTTPException, status

from database import get_supabase


@dataclass
class AuthUser:
    id: str          # UUID, mesmo de auth.users.id e usuarios.id
    familia_id: str  # UUID da familia
    email: str
    role: str = "membro"  # 'membro' | 'admin' (vindo da tabela usuarios)


def get_current_user(
    authorization: Optional[str] = Header(None, alias="Authorization"),
) -> AuthUser:
    """FastAPI Dependency que valida o JWT e devolve o usuário autenticado.

    Lança HTTPException 401 se:
      - header Authorization ausente ou mal-formado
      - JWT inválido / expirado
    Lança HTTPException 403 se:
      - usuário não tem registro em public.usuarios
      - usuário não tem familia_id vinculado
    """
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token JWT ausente. Envie 'Authorization: Bearer <token>'.",
            headers={"WWW-Authenticate": "Bearer"},
        )
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise HTTPException(401, "Token vazio")

    db = get_supabase()
    try:
        resp = db.auth.get_user(token)
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Token inválido: {e}",
            headers={"WWW-Authenticate": "Bearer"},
        )
    user = getattr(resp, "user", None)
    if user is None:
        raise HTTPException(401, "Token inválido (usuário não retornado)")

    auth_id = str(user.id)
    email = user.email or ""

    perfil = (
        db.table("usuarios")
        .select("familia_id, role")
        .eq("id", auth_id)
        .maybe_single()
        .execute()
    )
    if not perfil.data:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuário autenticado mas sem perfil em 'usuarios'",
        )
    familia_id = perfil.data.get("familia_id")
    if not familia_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Usuário sem família vinculada — complete o onboarding",
        )

    return AuthUser(
        id=auth_id,
        familia_id=str(familia_id),
        email=email,
        role=perfil.data.get("role") or "membro",
    )


def assert_mesma_familia(user: AuthUser, familia_id_no_payload) -> str:
    """Valida que o `familia_id` enviado no payload bate com o do JWT.

    Devolve o `familia_id` autoritativo (do JWT) pra usar no banco. Se o
    cliente mandou outro UUID, lança 403 — tentativa de cross-tenant.
    Aceita None no payload (alguns endpoints vão deixar de exigir o campo).
    """
    if familia_id_no_payload is None:
        return user.familia_id
    if str(familia_id_no_payload) != user.familia_id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="familia_id do payload não bate com o do token",
        )
    return user.familia_id


def assert_mesmo_usuario(user: AuthUser, usuario_id_no_payload) -> str:
    """Idem para usuario_id — não permite escrever em nome de outro."""
    if usuario_id_no_payload is None:
        return user.id
    if str(usuario_id_no_payload) != user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="usuario_id do payload não bate com o do token",
        )
    return user.id
