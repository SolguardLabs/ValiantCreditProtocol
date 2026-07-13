# Politica de seguridad

ValiantCreditProtocol mantiene un proceso coordinado para revisar hallazgos que afecten a los contratos, scripts y herramientas de este repositorio.

## Alcance

Estan dentro del alcance:

- contratos bajo `src/`;
- depositos, retiros y contabilidad de deuda;
- autorizaciones de credito delegado;
- rutas de prestamo administradas por managers;
- repagos, revocaciones y liquidaciones;
- oraculos, modelos de tipos, motores de riesgo y lentes;
- scripts de despliegue y validacion mantenidos en el repositorio.

Normalmente quedan fuera del alcance:

- interfaces de terceros no incluidas aqui;
- parametros de despliegue modificados fuera de las recomendaciones del proyecto;
- credenciales, RPCs o servicios externos comprometidos;
- copias alteradas por integradores.

## Invariantes esperadas

- Ninguna cuenta debe retirar colateral que respalde deuda abierta.
- Las lineas de credito deben respetar limites, expiracion y revocacion.
- Los repagos deben reducir deuda de ruta, deuda de borrower y exposicion contable.
- Las liquidaciones solo deben ejecutarse sobre cuentas por debajo del umbral configurado.
- Los precios usados para admision y liquidacion deben ser validos y recientes.
- Las reservas acumuladas no deben mezclarse con liquidez disponible para retiros ordinarios.

## Comunicacion privada

Informe los hallazgos por el canal privado indicado por los mantenedores. Incluya:

- componente afectado;
- commit o version;
- condiciones previas;
- impacto tecnico y economico;
- pasos de reproduccion minimos;
- pruebas, trazas o transacciones relevantes;
- mitigaciones temporales si existen.

No publique detalles tecnicos en canales publicos antes de coordinar una respuesta. No comparta claves privadas ni credenciales.

## Proceso

El equipo buscara acusar recibo en dos dias laborables, triage inicial en cinco dias laborables y actualizaciones semanales mientras el analisis continue. La prioridad se asigna segun fondos en riesgo, permisos requeridos, reproducibilidad y alcance.

## Validacion local

Antes de reportar, ejecute cuando sea posible:

```bash
npm run build
npm test
bash scripts/check-loc.sh
```

Los resultados locales ayudan a separar problemas de entorno de defectos del protocolo.
