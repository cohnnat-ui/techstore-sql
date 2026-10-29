# RetailPro Analytics

Solución integral de Business Intelligence para **RetailPro**, una distribuidora de tecnología (ficticia) con clientes mayoristas y minoristas. El proyecto transforma los datos transaccionales de ventas en un modelo analítico y un dashboard ejecutivo que responde cinco preguntas de negocio sobre facturación, margen, mix de productos, tipo de cliente y descuentos.

> Proyecto desarrollado en el marco de un curso de Data Analytics. Los datos son ficticios y de volumen reducido; los hallazgos ilustran la metodología y no deben generalizarse.

---

## Tabla de contenidos

- [Objetivos y preguntas de negocio](#objetivos-y-preguntas-de-negocio)
- [Arquitectura de la solución](#arquitectura-de-la-solución)
- [Modelo de datos](#modelo-de-datos)
- [Medidas DAX principales](#medidas-dax-principales)
- [Estructura del repositorio](#estructura-del-repositorio)
- [Instalación y reproducción](#instalación-y-reproducción)
- [KPIs del dashboard](#kpis-del-dashboard)
- [Principales hallazgos](#principales-hallazgos)
- [Limitaciones y próximos pasos](#limitaciones-y-próximos-pasos)

---

## Objetivos y preguntas de negocio

| # | Pregunta | Visualización |
|---|----------|---------------|
| P1 | ¿Cómo evoluciona el margen mes a mes? | Gráfico de líneas |
| P2 | ¿Qué categorías combinan mayor volumen y mayor margen? | Gráfico de barras |
| P3 | ¿Cómo difieren ticket promedio y volumen entre mayoristas y minoristas? | Gráfico de barras |
| P4 | ¿Qué margen neto genera cada responsable comercial / territorio? | Gráfico de barras |
| P5 | ¿Existe correlación entre tasa de descuento y margen? | Gráfico de dispersión |

---

## Arquitectura de la solución

```
┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐    ┌──────────────────┐
│  Datos fuente    │    │  ETL             │    │  Modelo          │    │  Presentación    │
│                  │    │                  │    │                  │    │                  │
│  Base relacional │───▶│  Power Query (M) │───▶│  Esquema estrella│───▶│  Dashboard       │
│  SQL Server      │    │  limpieza, tipos,│    │  Power BI        │    │  ejecutivo       │
│  (ventas,        │    │  normalización   │    │  + medidas DAX   │    │  Power BI        │
│  clientes, ...)  │    │                  │    │                  │    │                  │
└──────────────────┘    └──────────────────┘    └──────────────────┘    └──────────────────┘
        │
        └── Scripts SQL de creación de la base y consultas de análisis (/sql)
```

### 1. Datos transaccionales

Tablas relacionales: `ventas` (transacciones), `clientes`, `productos`, `categorias` y `territorios` (sucursales y responsables comerciales). Las consultas SQL de `/sql` corresponden al análisis exploratorio realizado en las pre-entregas, previo al modelado.

### 2. ETL con Power Query (Lenguaje M)

Cada tabla se importa y transforma en Power Query antes de cargarse al modelo:

- **Tipado explícito:** fechas como `date`, importes como número decimal fijo, claves como entero.
- **Limpieza:** eliminación de duplicados, espacios y filas sin clave.
- **Columnas calculadas en origen:** importe de línea calculado en la consulta, no en el visual.
- **Desnormalización de dimensiones:** la categoría se integra en la tabla `productos` para mantener un esquema estrella.

Ejemplo de paso de transformación:

```m
let
    Origen        = Sql.Database("SERVIDOR", "RetailPro"),
    Ventas        = Origen{[Schema = "dbo", Item = "ventas"]}[Data],
    Tipado        = Table.TransformColumnTypes(Ventas, {
                        {"id_venta", Int64.Type},
                        {"fecha_venta", type date},
                        {"cantidad", Int64.Type},
                        {"precio_unitario", Currency.Type}
                    }),
    SinDuplicados = Table.Distinct(Tipado, {"id_venta"}),
    ImporteLinea  = Table.AddColumn(SinDuplicados, "importe_bruto",
                        each [cantidad] * [precio_unitario], Currency.Type)
in
    ImporteLinea
```

### 3. Modelado relacional en estrella

Una tabla de hechos (`ventas`) rodeada de dimensiones, con relaciones uno a muchos y filtro en una sola dirección (dimensión → hecho).

### 4. Medidas core en DAX

Todas las métricas del dashboard se calculan como medidas explícitas (no columnas calculadas ni agregaciones implícitas), agrupadas en una tabla `_Medidas`.

---

## Modelo de datos

```
                       ┌─────────────────┐
                       │   calendario    │
                       │   fecha (PK)    │
                       └────────┬────────┘
                                │ 1
                                │
                                │ *
┌──────────────┐ 1     * ┌──────┴──────────┐ *     1 ┌──────────────┐
│  clientes    ├─────────┤     ventas      ├─────────┤  productos   │
│  id_cliente  │         │  id_venta       │         │  id_producto │
│  tipo_cliente│         │  fecha_venta    │         │  categoria   │
└──────────────┘         │  id_cliente     │         └──────────────┘
                         │  id_producto    │
                         │  id_territorio  │
                         │  cantidad       │
                         │  precio_unitario│
                         └──────┬──────────┘
                                │ *
                                │
                                │ 1
                       ┌────────┴────────┐
                       │   territorios   │
                       │   id_territorio │
                       │   responsable   │
                       └─────────────────┘
```

| Tabla | Tipo | Granularidad |
|-------|------|--------------|
| `ventas` | Hechos | Una fila por línea de venta |
| `clientes` | Dimensión | Un cliente (mayorista / minorista) |
| `productos` | Dimensión | Un producto, con su categoría |
| `territorios` | Dimensión | Una sucursal y su responsable comercial |
| `calendario` | Dimensión | Un día; marcada como tabla de fechas |

---

## Medidas DAX principales

```dax
Facturación Bruta =
    SUMX ( ventas, ventas[cantidad] * ventas[precio_unitario] )

Pedidos =
    DISTINCTCOUNT ( ventas[id_venta] )

Ticket Promedio =
    DIVIDE ( [Facturación Bruta], [Pedidos] )

Descuento Total =
    SUMX ( ventas, ventas[cantidad] * ventas[precio_unitario] * ventas[descuento] )

Facturación Neta =
    [Facturación Bruta] - [Descuento Total]

Tasa de Descuento Promedio =
    DIVIDE ( [Descuento Total], [Facturación Bruta] )

Costo Total =
    SUMX ( ventas, ventas[cantidad] * RELATED ( productos[costo_unitario] ) )

Margen Neto =
    [Facturación Neta] - [Costo Total]

Margen Neto % =
    DIVIDE ( [Margen Neto], [Facturación Neta] )

Facturación Mes Anterior =
    CALCULATE ( [Facturación Bruta], DATEADD ( calendario[fecha], -1, MONTH ) )

Variación MoM % =
    DIVIDE ( [Facturación Bruta] - [Facturación Mes Anterior], [Facturación Mes Anterior] )
```

> `Pedidos` cuenta `id_venta`. Si el origen incorpora un identificador de pedido con varias líneas, reemplazarlo por `DISTINCTCOUNT ( ventas[id_pedido] )` para que el ticket promedio sea por pedido y no por línea. Las medidas de descuento y margen requieren las columnas `descuento` en `ventas` y `costo_unitario` en `productos`.

---

## Estructura del repositorio

```
retailpro-analytics/
├── README.md
└── sql/
    ├── ventas_tech_db.sql        # Creación de la base de datos y carga de las tablas
    ├── m4_consultas_negocio.sql  # Módulo 4: resumen ejecutivo mensual y ranking de productos
    └── m5_consultas_joins.sql    # Módulo 5: vista base del proyecto (INNER JOIN)
```

---

## Instalación y reproducción

### Requisitos

- SQL Server (Express o Developer)
- SQL Server Management Studio
- Git

### Pasos

1. **Clonar el repositorio**

   ```bash
   git clone https://github.com/<usuario>/retailpro-analytics.git
   cd retailpro-analytics
   ```

2. **Crear la base de datos**

   Abrir `sql/ventas_tech_db.sql` en SQL Server Management Studio y ejecutarlo con F5. El script crea la base y carga las tablas `ventas`, `clientes`, `productos`, `categorias` y `territorios`.

3. **Ejecutar las consultas de análisis**

   Con la base creada seleccionada, abrir y ejecutar en este orden:

   ```
   m4_consultas_negocio.sql → m5_consultas_joins.sql
   ```

   El resumen mensual de `m4_consultas_negocio.sql` debe devolver una facturación total de $6.444,00 en 10 registros de venta.

---

## KPIs del dashboard

| KPI | Definición | Pregunta |
|-----|-----------|----------|
| Facturación bruta | Cantidad × precio unitario, antes de descuentos | P1, P2 |
| Margen de ganancia neto | (Facturación neta − costo) / facturación neta | P1, P2, P4 |
| Ticket promedio (AOV) | Facturación / pedidos | P3 |
| Tasa de descuento promedio | Descuento total / facturación bruta | P5 |
| Volumen por tipo de cliente | Unidades y pedidos, mayorista vs. minorista | P3 |

---

## Principales hallazgos

Sobre el dataset disponible (10 registros de venta correspondientes a un único mes):

1. **Alta concentración de la facturación.** Un solo producto explica el 55,9% de la facturación total ($3.600 de $6.444) y dos productos concentran el 76,8%. Es un riesgo de dependencia a monitorear.
2. **Volumen y valor no coinciden.** El producto con más unidades vendidas (13, la mitad del Top 5) aporta solo el 5,6% de la facturación. Priorizar por unidades llevaría a conclusiones comerciales equivocadas.
3. **El período analizado es de un solo mes.** Todas las ventas corresponden al mes 3 ($6.444 facturados, ticket promedio de $644,40 por línea de venta). Con un único período no es posible identificar tendencias ni estacionalidad, por lo que la pregunta P1 queda pendiente hasta contar con más meses de datos.

> Sin datos de costo, los hallazgos se basan en facturación, no en margen. Ver [Limitaciones](#limitaciones-y-próximos-pasos).

---

## Limitaciones y próximos pasos

- **Volumen y período:** ampliar el dataset a varios meses para habilitar P1 y comparaciones interanuales.
- **Costo y margen:** incorporar `costo_unitario` para calcular margen neto real.
- **Pedidos vs. líneas:** agregar un identificador de pedido para medir el ticket promedio por pedido.
- **Precio histórico:** verificar que `precio_unitario` en `ventas` refleje el precio al momento de la venta.

---

## Autora

**Natalia Cohn**: [LinkedIn](https://www.linkedin.com/in/<usuario>)
