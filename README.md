# ValiantCreditProtocol

![banner](./assets/banner.png)

ValiantCreditProtocol es un mercado EVM de credito delegado. Los depositantes aportan liquidez, mantienen el colateral en el protocolo y pueden autorizar a operadores externos a abrir deuda dentro de limites definidos. El objetivo del diseno es separar custodia, autorizacion y ejecucion de prestamos sin mover colateral a las cuentas delegadas.

El repositorio usa Hardhat para compilar y probar los contratos Solidity.

## Caracteristicas

- Depositos y retiros con token de recibo.
- Lineas de credito directas entre sponsor y delegate.
- Lineas administradas para borrowers asignados por un manager.
- Limites, expiracion y revocacion de permisos.
- Borrow y repay por ruta.
- Acumulacion de intereses mediante indice global de deuda.
- Oraculo configurable con validacion de vigencia.
- Motor de riesgo para capacidad de credito, health factor y liquidaciones.
- Liquidaciones parciales con close factor y bonus.
- Lentes de mercado, escenarios y reporting.
- Scripts reproducibles para build, tests y control de LOC.

## Estructura

```text
src/
  accounting/        Journal auxiliar de eventos contables
  access/            Ownership, risk admins y keepers
  core/              Pausas, reentrancy guard y ledger auxiliar
  governance/        Timelocks y configuracion parametrica
  interfaces/        Superficies publicas
  interest/          Modelo de tipos
  lens/              Consultas agregadas y reporting
  libraries/         Matematicas, claves y tipos
  mocks/             ERC20 local para pruebas
  oracle/            Oraculo y guardas
  periphery/         Router de keeper
  risk/              Motores de riesgo y politicas
  tokens/            Token de recibo
  treasury/          Gestion de reservas
```

## Requisitos

- Node.js 22 o superior.
- npm.
- Git Bash, WSL o entorno compatible para los scripts `.sh`.

## Instalacion

```bash
npm install
npm run build
```

## Pruebas

```bash
npm test
```

La suite cubre:

- delegaciones directas;
- limites de credito;
- apertura de deuda;
- repagos parciales;
- revocacion;
- creditos administrados por manager;
- liquidacion parcial tras deterioro de precio.

## Validacion completa

```bash
npm run ci
```

El flujo ejecuta compilacion, tests y verificacion del tamano de `src/`.

En Windows tambien puede ejecutarse:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/ci.ps1
```

## Comandos utiles

```bash
npm run build
npm test
npm run loc
npm run test:trace
```

## Modelo operativo

Un sponsor deposita el activo del mercado y recibe `vCREDIT`. Despues puede abrir una linea directa para un delegate. El delegate puede pedir prestado contra la capacidad disponible del sponsor y devolver la deuda de la ruta. Si el sponsor habilita a un manager, ese manager puede asignar borrowers bajo una linea administrada con limite propio.

El protocolo valora el colateral con el oraculo configurado. Si la posicion cae bajo el umbral de liquidacion, un tercero puede repagar parte de la deuda y recibir colateral con el incentivo definido por parametros de riesgo.

## Integracion continua

GitHub Actions instala dependencias con `npm install` y llama a `bash scripts/ci.sh`. Dependabot esta configurado para npm y GitHub Actions.

## Licencia

MIT. Consulte [LICENSE](./LICENSE).
