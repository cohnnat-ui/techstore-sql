USE Ventas_Tech_DB;

/* Consulta 1 — Resumen ejecutivo mensual
Objetivo: Total facturado (cantidad * precio_unitario), cantidad de pedidos y ticket promedio por mes
*/

SELECT 
    DATEPART(month, fecha_venta) AS mes,
    SUM(cantidad * precio_unitario) AS total_facturado,
    COUNT(*) AS cantidad_pedidos,
    AVG(cantidad * precio_unitario) AS ticket_promedio
FROM ventas
GROUP BY DATEPART(month, fecha_venta)
ORDER BY mes ASC;

/* Consulta 2 — Ranking de productos (Top 5 por facturación)
*/

SELECT TOP 5
    id_producto,
    SUM(cantidad) AS unidades_vendidas,
    SUM(cantidad * precio_unitario) AS total_facturado
FROM ventas
GROUP BY id_producto
ORDER BY total_facturado DESC;

/* Consulta 3 — Clientes recurrentes
*/

SELECT 
    id_cliente,
    COUNT(*) AS total_pedidos,
    SUM(cantidad * precio_unitario) AS total_gastado
FROM ventas
GROUP BY id_cliente
HAVING COUNT(*) > 1
ORDER BY total_pedidos DESC;


/* Consulta 4 — Meses por encima/por debajo del promedio mensual
*/

SELECT 
    DATEPART(month, fecha_venta) AS mes,
    SUM(cantidad * precio_unitario) AS total_mes,
    CASE 
        WHEN SUM(cantidad * precio_unitario) >= (
            SELECT AVG(total_mensual)
            FROM (
                SELECT SUM(cantidad * precio_unitario) AS total_mensual
                FROM ventas
                GROUP BY DATEPART(month, fecha_venta)
            ) AS subconsulta
        ) THEN 'Por encima'
        ELSE 'Por debajo'
    END AS estado_promedio
FROM ventas
GROUP BY DATEPART(month, fecha_venta)
ORDER BY mes ASC;


/* HALLAZGOS DEL NEGOCIO:
1. El producto con id_producto 1 lidera el ranking de ventas con una facturación total de $3600.
2.  El 100% de los clientes analizados registró una recurrencia exacta de 2 pedidos. 
La disparidad de ingresos radica en el valor acumulado (con un rango entre $510 
y $2.640), lo que evidencia que la diferencia de facturación está impulsada por 
el tipo/mix de productos adquiridos y no por la frecuencia de compra.
3. El mes 3 tuvo el desempeño más alto del período, situándose 'Por encima' del promedio general mensual.
*/