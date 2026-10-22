# Operación y controles

## Antes de una entrega

1. Fijar Bun y resolver dependencias con `bun install --frozen-lockfile`.
2. Ejecutar `bash scripts/ci.sh`: compilación, formato, pruebas y control de LOC de contratos.
3. Revisar configuración, oráculo, tesorería y permisos por separado del código de mercado.
4. Tras integrar en `main`, comprobar CI de `main`, `production` y tag. `release-integrity` exige que las tres referencias apunten al mismo commit.

La rama y el tag son referencias de código. Un release de GitHub no despliega contratos ni configura RPC, direcciones o claves. Esos pasos necesitan otro procedimiento y evidencias propias.

## Observabilidad

Registrar `Deposited`, `Withdrawn`, `CreditDelegated`, `ManagedCreditDelegated`, `Borrowed`, `Repaid`, `Liquidated` y `Accrued` junto a `marketState`. Reconciliar `totalScaledDebt` con deuda derivada del índice y `totalReserves` con tesorería. Un cambio de oráculo debe contrastarse con `maxPriceAge`, decimales y rango de precio antes de reanudar préstamos.

Las pausas de suministro, delegación, préstamo, repago y liquidación son independientes. Ante un incidente, identificar la acción afectada, conservar trazas y revisar el efecto de pausar repagos o liquidaciones antes de aplicarlo. Una pausa no modifica deuda pendiente ni devuelve activos.
