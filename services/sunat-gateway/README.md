# Gateway SUNAT

Servicio en PHP 8.3 que arma, firma y envía los comprobantes a SUNAT usando [Greenter](https://github.com/thegreenter/greenter), y genera los PDF. No guarda nada: recibe todo en cada petición y responde.

Solo lo llaman la API y el worker, con la cabecera `X-Token-Interno`. No debe quedar expuesto a internet.

## Ejecutar

```bash
docker build -t sunat-gateway .
docker run -p 127.0.0.1:4211:4210 -e SUNAT_GATEWAY_TOKEN="$TOKEN" sunat-gateway
```

`$TOKEN` es el mismo valor de `SUNAT_GATEWAY_TOKEN` que usa la API. Al arrancar crea un certificado autofirmado para beta si no le montas uno. Las variables disponibles están en `.env.example`.

## Rutas

| Ruta | Para qué |
|---|---|
| `POST /factura` | Factura y boleta |
| `POST /nota` | Notas de crédito y débito |
| `POST /resumen`, `POST /baja` | Resumen diario y comunicación de baja |
| `POST /ticket` | Consulta el resultado de un resumen o baja |
| `POST /guia`, `POST /guia-estado` | Guía de remisión |
| `POST /consulta-cpe` | Recupera el CDR de un comprobante ya enviado |
| `POST /pdf` | PDF en A4, 80 mm o 58 mm, con cinco plantillas |
| `POST /probar` | Prueba de firma y de conexión |
| `GET /salud` | Estado del servicio |

## Plantillas

Hay cinco diseños: `clasica`, `moderna`, `minimalista`, `ejecutiva` y `compacta`. Todos llevan los mismos datos que exige SUNAT. En beta se imprime una marca de agua «PRUEBA», y en los anulados, «ANULADO».
