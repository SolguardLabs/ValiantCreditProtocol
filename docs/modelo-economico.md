# Modelo económico

## Capacidad y salud

Para colateral `C`, precio `P` con `d` decimales y factores en puntos básicos:

```text
valor(C) = C × P / 10^d
capacidad = valor(C) × collateralFactorBps / 10 000
umbral = valor(C) × liquidationThresholdBps / 10 000
health factor = umbral / deuda
```

La implementación aplica redondeos enteros en `HealthMath` y `PriceMath`; para límites exactos consulte las funciones del contrato, no una aproximación decimal de interfaz. Sin deuda, la salud se trata como ilimitada. `availableCredit` satura en cero cuando la deuda supera la capacidad.

## Interés y liquidez

La deuda global y las rutas mantienen importes escalados por el índice de préstamo. El índice avanza según `ValiantRateModel`. La utilización es `borrows / (cash − reserves + borrows)`, con efectivo neto de reservas limitado inferiormente a cero. El tipo aumenta hasta `kink` y usa una segunda pendiente después. Una fracción del interés acumulado se registra en `totalReserves`.

Ejemplo con efectivo 500, deuda 500 y reservas 0: utilización 50 %. Con tipo base 2 %, primera pendiente 8 % y `kink` 80 %, el tipo de préstamo es aproximadamente 7 % en ese punto. No es una proyección de rendimiento: precio, utilización y configuración cambian.

## Restricciones conjuntas

Una solicitud directa queda limitada por línea restante, crédito disponible del patrocinador, liquidez y cap global. La línea gestionada requiere autorización padre vigente al crearla. Revocar una línea impide nuevo uso, pero no cancela automáticamente deuda existente; esta se repaga por su ruta. Un cambio de precio puede volver una cuenta liquidable antes del vencimiento de la línea.

Los parámetros se revisan conjuntamente: elevar `collateralFactorBps` amplía capacidad, elevar `liquidationBonusBps` aumenta colateral entregado a liquidadores y reducir `maxPriceAge` aumenta sensibilidad a interrupciones del oráculo.
