# Integración

La interfaz de escritura expone `deposit`, `withdraw`, `delegateCredit`, `subdelegateCredit`, `borrow`, `borrowWithSubdelegation`, `repay` y `repayManaged`. Antes de enviar, la integración debe comprobar red, dirección del contrato, activo, decimales y allowance.

```js
const { ValiantPositionClient } = require("../client/ValiantPositionClient");
const client = new ValiantPositionClient(protocol);
const quote = await client.inspectDirect(sponsorAddress, delegateAddress);
console.log(quote.executableNow.toString());
```

`inspectDirect` consulta en paralelo cuenta, línea y liquidez. Devuelve colateral, deuda, capacidad, uso de línea y el mínimo orientativo entre `availableCredit`, `line.remaining` y `marketLiquidity`. Si la línea no está activa o el colateral está deshabilitado, devuelve cero. Cubre **solo** líneas directas; no predice `borrowWithSubdelegation`.

Secuencia directa: el patrocinador aprueba el activo y deposita 1 000 unidades; autoriza 400 a un delegado; el delegado lee la línea y pide 150; más tarde devuelve 50 con `repay(sponsor, borrower, amount)`. El frontend debe leer nuevamente tras cada confirmación. Una estimación puede quedar obsoleta por otros préstamos, interés, cambios de precio, revocaciones o pausas; la transacción es la autoridad final.
