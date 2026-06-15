USE [BD_Peluqueria_SmartStyle]
GO

/* =============================================================
   PELUQUERIA SMARTSTYLE
   EJERCICIOS SQL + VISTAS + PROCEDIMIENTOS + FUNCIONES
   + MODELO DIMENSIONAL
   ============================================================= */

/* =============================================================
   1. EJERCICIOS DE DIFERENTE NIVEL (20)
   ============================================================= */

/* -------------------------
   NIVEL BASICO (1 - 7)
   ------------------------- */

-- 1. Mostrar todos los clientes registrados con sus datos personales.
SELECT 
    c.cliente_id,
    p.nombre,
    p.apellido_paterno,
    p.apellido_materno,
    p.nro_documento,
    p.celular,
    c.estado
FROM cliente c
INNER JOIN persona p ON c.persona_id = p.persona_id;
GO

-- 2. Listar todos los empleados activos.
SELECT 
    e.empleado_id,
    p.nombre,
    p.apellido_paterno,
    p.apellido_materno,
    e.fecha_ingreso,
    e.estado
FROM empleado e
INNER JOIN persona p ON e.persona_id = p.persona_id
WHERE e.estado = 1;
GO

-- 3. Mostrar todos los servicios activos.
SELECT 
    servicio_id,
    servicio,
    estado
FROM servicio
WHERE estado = 1;
GO

-- 4. Listar productos del inventario.
SELECT 
    inventario_id,
    nombre_producto,
    tipo_producto_id,
    stoct AS stock,
    fecha_vencimiento
FROM inventario;
GO

-- 5. Mostrar sedes registradas.
SELECT 
    sede_id,
    sede,
    estado
FROM sede;
GO

-- 6. Mostrar monedas activas.
SELECT 
    moneda_id,
    moneda,
    estado
FROM moneda
WHERE estado = 1;
GO

-- 7. Listar citas registradas ordenadas por fecha.
SELECT 
    cita_id,
    fecha_cita,
    detalle_cita,
    cliente_id,
    empleado_id,
    estado_cita_id
FROM cita
ORDER BY fecha_cita DESC;
GO

/* -------------------------
   NIVEL INTERMEDIO (8 - 14)
   ------------------------- */

-- 8. Mostrar clientes con tipo de documento y sexo.
SELECT 
    c.cliente_id,
    p.nombre,
    p.apellido_paterno,
    td.tipo_documento,
    p.nro_documento,
    sx.sexo
FROM cliente c
INNER JOIN persona p ON c.persona_id = p.persona_id
LEFT JOIN tipo_documento td ON p.tipo_documento_id = td.tipo_documento_id
LEFT JOIN sexo sx ON p.sexo_id = sx.sexo_id;
GO

-- 9. Listar empleados con cargo y sede.
SELECT 
    e.empleado_id,
    p.nombre,
    p.apellido_paterno,
    ca.cargo,
    s.sede,
    e.fecha_ingreso
FROM empleado e
INNER JOIN persona p ON e.persona_id = p.persona_id
LEFT JOIN cargo ca ON e.cargo_id = ca.cargo_id
LEFT JOIN sede s ON e.sede_id = s.sede_id;
GO

-- 10. Mostrar citas con nombre del cliente, empleado y estado.
SELECT 
    ci.cita_id,
    ci.fecha_cita,
    CONCAT(pc.nombre, ' ', pc.apellido_paterno, ' ', pc.apellido_materno) AS cliente,
    CONCAT(pe.nombre, ' ', pe.apellido_paterno, ' ', pe.apellido_materno) AS empleado,
    ec.estado_cita,
    ci.detalle_cita
FROM cita ci
INNER JOIN cliente cl ON ci.cliente_id = cl.cliente_id
INNER JOIN persona pc ON cl.persona_id = pc.persona_id
INNER JOIN empleado em ON ci.empleado_id = em.empleado_id
INNER JOIN persona pe ON em.persona_id = pe.persona_id
LEFT JOIN estado_cita ec ON ci.estado_cita_id = ec.estado_cita_id;
GO

-- 11. Contar cuantas citas tiene cada empleado.
SELECT 
    e.empleado_id,
    CONCAT(p.nombre, ' ', p.apellido_paterno) AS empleado,
    COUNT(c.cita_id) AS total_citas
FROM empleado e
INNER JOIN persona p ON e.persona_id = p.persona_id
LEFT JOIN cita c ON e.empleado_id = c.empleado_id
GROUP BY e.empleado_id, p.nombre, p.apellido_paterno
ORDER BY total_citas DESC;
GO

-- 12. Mostrar stock actual por tipo de producto.
SELECT 
    tp.tipo_producto,
    SUM(ISNULL(i.stoct, 0)) AS stock_total
FROM tipo_producto tp
LEFT JOIN inventario i ON tp.tipo_producto_id = i.tipo_producto_id
GROUP BY tp.tipo_producto
ORDER BY stock_total DESC;
GO

-- 13. Obtener total de ventas por moneda.
SELECT 
    m.moneda,
    SUM(ISNULL(dv.monto, 0) * ISNULL(dv.cantidad, 0) - ISNULL(dv.descuento, 0)) AS total_vendido
FROM venta v
INNER JOIN moneda m ON v.moneda_id = m.moneda_id
INNER JOIN detalle_venta dv ON v.venta_id = dv.venta_id
GROUP BY m.moneda;
GO

-- 14. Mostrar los servicios mas vendidos.
SELECT 
    s.servicio_id,
    s.servicio,
    SUM(ISNULL(dv.cantidad, 0)) AS cantidad_vendida
FROM servicio s
INNER JOIN detalle_venta dv ON s.servicio_id = dv.servicio_id
GROUP BY s.servicio_id, s.servicio
ORDER BY cantidad_vendida DESC;
GO

/* -------------------------
   NIVEL AVANZADO (15 - 20)
   ------------------------- */

-- 15. Obtener monto total vendido por cada servicio.
SELECT 
    s.servicio,
    SUM(ISNULL(dv.monto, 0) * ISNULL(dv.cantidad, 0) - ISNULL(dv.descuento, 0)) AS total_vendido
FROM servicio s
INNER JOIN detalle_venta dv ON s.servicio_id = dv.servicio_id
GROUP BY s.servicio
ORDER BY total_vendido DESC;
GO

-- 16. Ranking de empleados por cantidad de citas atendidas.
SELECT 
    RANK() OVER (ORDER BY COUNT(ci.cita_id) DESC) AS ranking,
    e.empleado_id,
    CONCAT(p.nombre, ' ', p.apellido_paterno) AS empleado,
    COUNT(ci.cita_id) AS total_citas
FROM empleado e
INNER JOIN persona p ON e.persona_id = p.persona_id
LEFT JOIN cita ci ON e.empleado_id = ci.empleado_id
GROUP BY e.empleado_id, p.nombre, p.apellido_paterno;
GO

-- 17. Identificar clientes con mas de 2 citas registradas.
SELECT 
    cl.cliente_id,
    CONCAT(p.nombre, ' ', p.apellido_paterno) AS cliente,
    COUNT(ci.cita_id) AS total_citas
FROM cliente cl
INNER JOIN persona p ON cl.persona_id = p.persona_id
INNER JOIN cita ci ON cl.cliente_id = ci.cliente_id
GROUP BY cl.cliente_id, p.nombre, p.apellido_paterno
HAVING COUNT(ci.cita_id) > 2
ORDER BY total_citas DESC;
GO

-- 18. Calcular ingresos generados por sede segun empleado que registro la venta.
SELECT 
    se.sede,
    SUM(ISNULL(dv.monto, 0) * ISNULL(dv.cantidad, 0) - ISNULL(dv.descuento, 0)) AS ingresos
FROM venta v
INNER JOIN usuario u ON v.usuario_id = u.usuario_id
INNER JOIN empleado e ON u.empleado_id = e.empleado_id
INNER JOIN sede se ON e.sede_id = se.sede_id
INNER JOIN detalle_venta dv ON v.venta_id = dv.venta_id
GROUP BY se.sede
ORDER BY ingresos DESC;
GO

-- 19. Mostrar productos proximos a vencer en los siguientes 30 dias.
SELECT 
    inventario_id,
    nombre_producto,
    stoct AS stock,
    fecha_vencimiento
FROM inventario
WHERE fecha_vencimiento BETWEEN CAST(GETDATE() AS DATE) AND DATEADD(DAY, 30, CAST(GETDATE() AS DATE))
ORDER BY fecha_vencimiento;
GO

-- 20. Reporte consolidado de cliente, cita, empleado, servicio y precio.
SELECT 
    ci.cita_id,
    ci.fecha_cita,
    CONCAT(pc.nombre, ' ', pc.apellido_paterno) AS cliente,
    CONCAT(pe.nombre, ' ', pe.apellido_paterno) AS empleado,
    s.servicio,
    sc.precio,
    sc.cantidad,
    ec.estado_cita
FROM cita ci
INNER JOIN cliente cl ON ci.cliente_id = cl.cliente_id
INNER JOIN persona pc ON cl.persona_id = pc.persona_id
INNER JOIN empleado em ON ci.empleado_id = em.empleado_id
INNER JOIN persona pe ON em.persona_id = pe.persona_id
LEFT JOIN servicio_cita sc ON ci.cita_id = sc.cita_id
LEFT JOIN servicio s ON sc.servicio_id = s.servicio_id
LEFT JOIN estado_cita ec ON ci.estado_cita_id = ec.estado_cita_id
ORDER BY ci.fecha_cita DESC;
GO

/* =============================================================
   2. VISTAS, PROCEDIMIENTOS ALMACENADOS Y FUNCIONES (10)
   ============================================================= */

/* -------------------------
   VISTAS (4)
   ------------------------- */

CREATE OR ALTER VIEW vw_clientes_detalle
AS
SELECT 
    c.cliente_id,
    p.persona_id,
    p.nombre,
    p.apellido_paterno,
    p.apellido_materno,
    td.tipo_documento,
    p.nro_documento,
    p.celular,
    p.direccion,
    sx.sexo,
    c.estado
FROM cliente c
INNER JOIN persona p ON c.persona_id = p.persona_id
LEFT JOIN tipo_documento td ON p.tipo_documento_id = td.tipo_documento_id
LEFT JOIN sexo sx ON p.sexo_id = sx.sexo_id;
GO

CREATE OR ALTER VIEW vw_empleados_cargos_sedes
AS
SELECT 
    e.empleado_id,
    CONCAT(p.nombre, ' ', p.apellido_paterno, ' ', p.apellido_materno) AS empleado,
    ca.cargo,
    se.sede,
    e.fecha_ingreso,
    e.estado
FROM empleado e
INNER JOIN persona p ON e.persona_id = p.persona_id
LEFT JOIN cargo ca ON e.cargo_id = ca.cargo_id
LEFT JOIN sede se ON e.sede_id = se.sede_id;
GO

CREATE OR ALTER VIEW vw_citas_completas
AS
SELECT 
    ci.cita_id,
    ci.fecha_cita,
    CONCAT(pc.nombre, ' ', pc.apellido_paterno, ' ', pc.apellido_materno) AS cliente,
    CONCAT(pe.nombre, ' ', pe.apellido_paterno, ' ', pe.apellido_materno) AS empleado,
    ec.estado_cita,
    ci.detalle_cita
FROM cita ci
INNER JOIN cliente cl ON ci.cliente_id = cl.cliente_id
INNER JOIN persona pc ON cl.persona_id = pc.persona_id
INNER JOIN empleado em ON ci.empleado_id = em.empleado_id
INNER JOIN persona pe ON em.persona_id = pe.persona_id
LEFT JOIN estado_cita ec ON ci.estado_cita_id = ec.estado_cita_id;
GO

CREATE OR ALTER VIEW vw_ventas_detalle
AS
SELECT 
    v.venta_id,
    v.nro_operacion,
    v.fecha_venta,
    v.nro_serie,
    v.nro_documento,
    s.servicio,
    dv.cantidad,
    dv.monto,
    dv.descuento,
    (ISNULL(dv.monto, 0) * ISNULL(dv.cantidad, 0) - ISNULL(dv.descuento, 0)) AS total_linea,
    m.moneda,
    tt.tipo_transacciones
FROM venta v
INNER JOIN detalle_venta dv ON v.venta_id = dv.venta_id
INNER JOIN servicio s ON dv.servicio_id = s.servicio_id
LEFT JOIN moneda m ON v.moneda_id = m.moneda_id
LEFT JOIN tipo_transacciones tt ON v.tipo_transacciones_id = tt.tipo_transacciones_id;
GO

/* -------------------------
   PROCEDIMIENTOS ALMACENADOS (3)
   ------------------------- */

CREATE OR ALTER PROCEDURE sp_citas_por_empleado
    @empleado_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM vw_citas_completas
    WHERE cita_id IN (
        SELECT cita_id
        FROM cita
        WHERE empleado_id = @empleado_id
    )
    ORDER BY fecha_cita DESC;
END
GO

CREATE OR ALTER PROCEDURE sp_buscar_cliente_documento
    @nro_documento VARCHAR(20)
AS
BEGIN
    SET NOCOUNT ON;

    SELECT *
    FROM vw_clientes_detalle
    WHERE nro_documento = @nro_documento;
END
GO

CREATE OR ALTER PROCEDURE sp_productos_por_tipo
    @tipo_producto_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT 
        i.inventario_id,
        i.nombre_producto,
        tp.tipo_producto,
        i.stoct AS stock,
        i.fecha_vencimiento
    FROM inventario i
    INNER JOIN tipo_producto tp ON i.tipo_producto_id = tp.tipo_producto_id
    WHERE i.tipo_producto_id = @tipo_producto_id;
END
GO

/* -------------------------
   FUNCIONES (3)
   ------------------------- */

CREATE OR ALTER FUNCTION fn_total_ventas()
RETURNS MONEY
AS
BEGIN
    DECLARE @total MONEY;

    SELECT @total = SUM(ISNULL(monto, 0) * ISNULL(cantidad, 0) - ISNULL(descuento, 0))
    FROM detalle_venta;

    RETURN ISNULL(@total, 0);
END
GO

CREATE OR ALTER FUNCTION fn_cantidad_citas_empleado(@empleado_id INT)
RETURNS INT
AS
BEGIN
    DECLARE @cantidad INT;

    SELECT @cantidad = COUNT(*)
    FROM cita
    WHERE empleado_id = @empleado_id;

    RETURN ISNULL(@cantidad, 0);
END
GO

CREATE OR ALTER FUNCTION fn_stock_producto(@inventario_id INT)
RETURNS INT
AS
BEGIN
    DECLARE @stock INT;

    SELECT @stock = stoct
    FROM inventario
    WHERE inventario_id = @inventario_id;

    RETURN ISNULL(@stock, 0);
END
GO

/* =============================================================
   3. MODELO DIMENSIONAL
   ============================================================= */

-- Crear esquema dimensional.
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dw')
BEGIN
    EXEC('CREATE SCHEMA dw');
END
GO

CREATE TABLE dw.dim_tiempo (
    fecha_id INT NOT NULL PRIMARY KEY,
    fecha DATE NOT NULL,
    dia INT NOT NULL,
    mes INT NOT NULL,
    nombre_mes VARCHAR(20) NOT NULL,
    trimestre INT NOT NULL,
    anio INT NOT NULL
);
GO

CREATE TABLE dw.dim_cliente (
    cliente_key INT IDENTITY(1,1) PRIMARY KEY,
    cliente_id INT,
    nombre_completo VARCHAR(200),
    tipo_documento VARCHAR(50),
    nro_documento VARCHAR(20),
    sexo VARCHAR(50),
    celular VARCHAR(20),
    direccion VARCHAR(200),
    estado BIT
);
GO

CREATE TABLE dw.dim_empleado (
    empleado_key INT IDENTITY(1,1) PRIMARY KEY,
    empleado_id INT,
    nombre_completo VARCHAR(200),
    cargo VARCHAR(50),
    sede VARCHAR(50),
    fecha_ingreso DATE,
    estado BIT
);
GO

CREATE TABLE dw.dim_servicio (
    servicio_key INT IDENTITY(1,1) PRIMARY KEY,
    servicio_id INT,
    servicio VARCHAR(100),
    estado BIT
);
GO

CREATE TABLE dw.dim_sede (
    sede_key INT IDENTITY(1,1) PRIMARY KEY,
    sede_id INT,
    sede VARCHAR(50),
    estado BIT
);
GO

CREATE TABLE dw.dim_moneda (
    moneda_key INT IDENTITY(1,1) PRIMARY KEY,
    moneda_id INT,
    moneda VARCHAR(50),
    estado BIT
);
GO

CREATE TABLE dw.fact_ventas (
    fact_venta_id INT IDENTITY(1,1) PRIMARY KEY,
    venta_id INT,
    fecha_id INT,
    cliente_key INT NULL,
    empleado_key INT NULL,
    servicio_key INT NULL,
    sede_key INT NULL,
    moneda_key INT NULL,
    cantidad INT,
    monto MONEY,
    descuento MONEY,
    total_linea MONEY,
    CONSTRAINT FK_fact_tiempo FOREIGN KEY (fecha_id) REFERENCES dw.dim_tiempo(fecha_id),
    CONSTRAINT FK_fact_cliente FOREIGN KEY (cliente_key) REFERENCES dw.dim_cliente(cliente_key),
    CONSTRAINT FK_fact_empleado FOREIGN KEY (empleado_key) REFERENCES dw.dim_empleado(empleado_key),
    CONSTRAINT FK_fact_servicio FOREIGN KEY (servicio_key) REFERENCES dw.dim_servicio(servicio_key),
    CONSTRAINT FK_fact_sede FOREIGN KEY (sede_key) REFERENCES dw.dim_sede(sede_key),
    CONSTRAINT FK_fact_moneda FOREIGN KEY (moneda_key) REFERENCES dw.dim_moneda(moneda_key)
);
GO

/* -------------------------
   CARGA DE DATOS AL MODELO DIMENSIONAL
   ------------------------- */

INSERT INTO dw.dim_tiempo (fecha_id, fecha, dia, mes, nombre_mes, trimestre, anio)
SELECT DISTINCT
    CONVERT(INT, FORMAT(fecha_venta, 'yyyyMMdd')) AS fecha_id,
    CAST(fecha_venta AS DATE) AS fecha,
    DAY(fecha_venta) AS dia,
    MONTH(fecha_venta) AS mes,
    DATENAME(MONTH, fecha_venta) AS nombre_mes,
    DATEPART(QUARTER, fecha_venta) AS trimestre,
    YEAR(fecha_venta) AS anio
FROM venta
WHERE fecha_venta IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM dw.dim_tiempo dt
      WHERE dt.fecha_id = CONVERT(INT, FORMAT(venta.fecha_venta, 'yyyyMMdd'))
  );
GO

INSERT INTO dw.dim_cliente (cliente_id, nombre_completo, tipo_documento, nro_documento, sexo, celular, direccion, estado)
SELECT 
    c.cliente_id,
    CONCAT(p.nombre, ' ', p.apellido_paterno, ' ', p.apellido_materno),
    td.tipo_documento,
    p.nro_documento,
    sx.sexo,
    p.celular,
    p.direccion,
    c.estado
FROM cliente c
INNER JOIN persona p ON c.persona_id = p.persona_id
LEFT JOIN tipo_documento td ON p.tipo_documento_id = td.tipo_documento_id
LEFT JOIN sexo sx ON p.sexo_id = sx.sexo_id;
GO

INSERT INTO dw.dim_empleado (empleado_id, nombre_completo, cargo, sede, fecha_ingreso, estado)
SELECT 
    e.empleado_id,
    CONCAT(p.nombre, ' ', p.apellido_paterno, ' ', p.apellido_materno),
    ca.cargo,
    se.sede,
    e.fecha_ingreso,
    e.estado
FROM empleado e
INNER JOIN persona p ON e.persona_id = p.persona_id
LEFT JOIN cargo ca ON e.cargo_id = ca.cargo_id
LEFT JOIN sede se ON e.sede_id = se.sede_id;
GO

INSERT INTO dw.dim_servicio (servicio_id, servicio, estado)
SELECT servicio_id, servicio, estado
FROM servicio;
GO

INSERT INTO dw.dim_sede (sede_id, sede, estado)
SELECT sede_id, sede, estado
FROM sede;
GO

INSERT INTO dw.dim_moneda (moneda_id, moneda, estado)
SELECT moneda_id, moneda, estado
FROM moneda;
GO

INSERT INTO dw.fact_ventas (
    venta_id,
    fecha_id,
    cliente_key,
    empleado_key,
    servicio_key,
    sede_key,
    moneda_key,
    cantidad,
    monto,
    descuento,
    total_linea
)
SELECT 
    v.venta_id,
    CONVERT(INT, FORMAT(v.fecha_venta, 'yyyyMMdd')) AS fecha_id,
    NULL AS cliente_key,
    de.empleado_key,
    ds.servicio_key,
    dse.sede_key,
    dm.moneda_key,
    dv.cantidad,
    dv.monto,
    dv.descuento,
    (ISNULL(dv.monto, 0) * ISNULL(dv.cantidad, 0) - ISNULL(dv.descuento, 0)) AS total_linea
FROM venta v
INNER JOIN detalle_venta dv ON v.venta_id = dv.venta_id
LEFT JOIN servicio s ON dv.servicio_id = s.servicio_id
LEFT JOIN dw.dim_servicio ds ON s.servicio_id = ds.servicio_id
LEFT JOIN usuario u ON v.usuario_id = u.usuario_id
LEFT JOIN empleado e ON u.empleado_id = e.empleado_id
LEFT JOIN dw.dim_empleado de ON e.empleado_id = de.empleado_id
LEFT JOIN sede se ON e.sede_id = se.sede_id
LEFT JOIN dw.dim_sede dse ON se.sede_id = dse.sede_id
LEFT JOIN moneda m ON v.moneda_id = m.moneda_id
LEFT JOIN dw.dim_moneda dm ON m.moneda_id = dm.moneda_id
WHERE v.fecha_venta IS NOT NULL;
GO

/* -------------------------
   CONSULTAS ANALITICAS DEL MODELO DIMENSIONAL
   ------------------------- */

-- A. Ventas por mes.
SELECT 
    dt.anio,
    dt.mes,
    dt.nombre_mes,
    SUM(fv.total_linea) AS total_ventas
FROM dw.fact_ventas fv
INNER JOIN dw.dim_tiempo dt ON fv.fecha_id = dt.fecha_id
GROUP BY dt.anio, dt.mes, dt.nombre_mes
ORDER BY dt.anio, dt.mes;
GO

-- B. Ventas por sede.
SELECT 
    ds.sede,
    SUM(fv.total_linea) AS total_ventas
FROM dw.fact_ventas fv
LEFT JOIN dw.dim_sede ds ON fv.sede_key = ds.sede_key
GROUP BY ds.sede
ORDER BY total_ventas DESC;
GO

-- C. Servicios mas vendidos.
SELECT 
    ds.servicio,
    SUM(fv.cantidad) AS cantidad_vendida,
    SUM(fv.total_linea) AS total_ventas
FROM dw.fact_ventas fv
LEFT JOIN dw.dim_servicio ds ON fv.servicio_key = ds.servicio_key
GROUP BY ds.servicio
ORDER BY cantidad_vendida DESC;
GO

-- D. Empleados con mayor facturacion.
SELECT 
    de.nombre_completo AS empleado,
    de.cargo,
    de.sede,
    SUM(fv.total_linea) AS total_facturado
FROM dw.fact_ventas fv
LEFT JOIN dw.dim_empleado de ON fv.empleado_key = de.empleado_key
GROUP BY de.nombre_completo, de.cargo, de.sede
ORDER BY total_facturado DESC;
GO

-- E. Ventas por moneda.
SELECT 
    dm.moneda,
    SUM(fv.total_linea) AS total_ventas
FROM dw.fact_ventas fv
LEFT JOIN dw.dim_moneda dm ON fv.moneda_key = dm.moneda_key
GROUP BY dm.moneda;
GO
