USE [pdan_bd_sistema_riesgo_crediticio];
GO

/* ==========================================================
   VISTAS - SISTEMA DE RIESGO CREDITICIO
   ========================================================== */

CREATE OR ALTER VIEW dbo.vw_clientes_naturales
AS
SELECT
    c.id AS id_cliente,
    pn.numero_documento,
    CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres) AS nombres_completos,
    pn.celular,
    pn.situacion_laboral
FROM dbo.clientes c
INNER JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id;
GO

CREATE OR ALTER VIEW dbo.vw_clientes_juridicos
AS
SELECT
    c.id AS id_cliente,
    pj.ruc,
    pj.razon_social,
    pj.tipo_empresa,
    pj.sector_economico,
    pj.estado_empresa
FROM dbo.clientes c
INNER JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id;
GO

CREATE OR ALTER VIEW dbo.vw_cuentas
AS
SELECT
    cu.num_cuenta,
    cu.moneda,
    cu.saldo,
    tc.nombre AS tipo_cuenta
FROM dbo.cuentas cu
INNER JOIN dbo.tipos_cuenta tc ON tc.id = cu.tipo_cuenta_id;
GO

CREATE OR ALTER VIEW dbo.vw_solicitudes
AS
SELECT
    s.codigo_solicitud,
    s.fecha_solicitud,
    CASE
        WHEN c.tipo_cliente = 'N' THEN CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres)
        ELSE pj.razon_social
    END AS cliente,
    pc.nombre AS producto_crediticio,
    s.monto_solicitado,
    s.estado
FROM dbo.solicitudes s
INNER JOIN dbo.clientes c ON c.id = s.cliente_id
LEFT JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id
LEFT JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id
INNER JOIN dbo.productos_crediticios pc ON pc.id = s.producto_crediticio_id;
GO

CREATE OR ALTER VIEW dbo.vw_evaluaciones_crediticias
AS
SELECT
    CASE
        WHEN c.tipo_cliente = 'N' THEN CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres)
        ELSE pj.razon_social
    END AS cliente,
    ec.score_riesgo,
    ec.nivel_endeudamiento,
    ec.ingresos_mensuales,
    ec.resultado AS resultado_evaluacion
FROM dbo.evaluaciones_crediticias ec
INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
INNER JOIN dbo.clientes c ON c.id = s.cliente_id
LEFT JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id
LEFT JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id;
GO

CREATE OR ALTER VIEW dbo.vw_creditos_vigentes
AS
SELECT *
FROM dbo.creditos
WHERE estado = 'vigente';
GO

CREATE OR ALTER VIEW dbo.vw_cartera_crediticia
AS
SELECT
    cr.numero_credito,
    CASE
        WHEN c.tipo_cliente = 'N' THEN CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres)
        ELSE pj.razon_social
    END AS cliente,
    pc.nombre AS producto,
    cr.monto,
    cr.saldo_credito,
    cr.estado
FROM dbo.creditos cr
INNER JOIN dbo.evaluaciones_crediticias ec ON ec.id = cr.evaluacion_crediticia_id
INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
INNER JOIN dbo.productos_crediticios pc ON pc.id = s.producto_crediticio_id
INNER JOIN dbo.clientes c ON c.id = s.cliente_id
LEFT JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id
LEFT JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id;
GO

CREATE OR ALTER VIEW dbo.vw_cuotas_pendientes
AS
SELECT
    cr.numero_credito AS credito,
    cu.num_cuota,
    cu.fecha_vencimiento,
    cu.total_cuota,
    cu.saldo_cuota AS saldo_pendiente
FROM dbo.cuotas cu
INNER JOIN dbo.creditos cr ON cr.id = cu.credito_id
WHERE cu.estado IN ('pendiente', 'pagada parcialmente')
  AND cu.saldo_cuota > 0;
GO

CREATE OR ALTER VIEW dbo.vw_indicadores_generales
AS
SELECT
    (SELECT COUNT(*) FROM dbo.clientes) AS total_clientes,
    (SELECT COUNT(*) FROM dbo.solicitudes) AS total_solicitudes,
    (SELECT COUNT(*) FROM dbo.creditos) AS total_creditos,
    (SELECT ISNULL(SUM(monto), 0) FROM dbo.creditos) AS total_desembolsado;
GO

CREATE OR ALTER VIEW dbo.vw_riesgo_crediticio
AS
SELECT
    c.id AS cliente_id,
    CASE
        WHEN c.tipo_cliente = 'N' THEN CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres)
        ELSE pj.razon_social
    END AS cliente,
    ec.score_riesgo,
    CASE
        WHEN ec.score_riesgo >= 700 THEN 'Riesgo Bajo'
        WHEN ec.score_riesgo >= 400 THEN 'Riesgo Medio'
        ELSE 'Riesgo Alto'
    END AS clasificacion_riesgo
FROM dbo.evaluaciones_crediticias ec
INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
INNER JOIN dbo.clientes c ON c.id = s.cliente_id
LEFT JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id
LEFT JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id;
GO

/* ==========================================================
   FUNCIONES ESCALARES
   ========================================================== */

CREATE OR ALTER FUNCTION dbo.fn_calcular_edad(@fecha_nacimiento DATE)
RETURNS INT
AS
BEGIN
    DECLARE @edad INT;
    SET @edad = DATEDIFF(YEAR, @fecha_nacimiento, GETDATE())
              - CASE WHEN DATEADD(YEAR, DATEDIFF(YEAR, @fecha_nacimiento, GETDATE()), @fecha_nacimiento) > CAST(GETDATE() AS DATE) THEN 1 ELSE 0 END;
    RETURN @edad;
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_igv_incluido(@monto DECIMAL(18,2))
RETURNS DECIMAL(18,2)
AS
BEGIN
    RETURN ROUND(ISNULL(@monto, 0) * 1.18, 2);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_score_clasificacion(@score DECIMAL(10,2))
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN CASE
        WHEN @score < 400 THEN 'Bajo'
        WHEN @score < 700 THEN 'Medio'
        ELSE 'Alto'
    END;
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_clasificar_saldo_credito(@saldo_credito DECIMAL(18,2))
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN CASE
        WHEN ISNULL(@saldo_credito, 0) <= 5000 THEN 'Normal'
        WHEN @saldo_credito <= 20000 THEN 'Observado'
        ELSE 'Crítico'
    END;
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_porcentaje_endeudamiento(
    @ingresos DECIMAL(18,2),
    @deudas DECIMAL(18,2)
)
RETURNS DECIMAL(10,2)
AS
BEGIN
    IF ISNULL(@ingresos, 0) = 0 RETURN 0;
    RETURN ROUND((ISNULL(@deudas, 0) / @ingresos) * 100, 2);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_total_cuota(
    @capital DECIMAL(18,2),
    @intereses DECIMAL(18,2),
    @seguros DECIMAL(18,2)
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    RETURN ISNULL(@capital, 0) + ISNULL(@intereses, 0) + ISNULL(@seguros, 0);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_valor_estimado_cuota(
    @monto_credito DECIMAL(18,2),
    @plazo INT
)
RETURNS DECIMAL(18,2)
AS
BEGIN
    IF ISNULL(@plazo, 0) <= 0 RETURN 0;
    RETURN ROUND(ISNULL(@monto_credito, 0) / @plazo, 2);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_dias_atraso(@fecha_vencimiento DATE)
RETURNS INT
AS
BEGIN
    RETURN CASE
        WHEN @fecha_vencimiento IS NULL THEN 0
        WHEN DATEDIFF(DAY, @fecha_vencimiento, CAST(GETDATE() AS DATE)) > 0
            THEN DATEDIFF(DAY, @fecha_vencimiento, CAST(GETDATE() AS DATE))
        ELSE 0
    END;
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_nivel_riesgo(
    @score DECIMAL(10,2),
    @endeudamiento DECIMAL(10,2)
)
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN CASE
        WHEN @score >= 700 AND @endeudamiento <= 30 THEN 'Verde'
        WHEN @score >= 400 AND @endeudamiento <= 60 THEN 'Amarillo'
        ELSE 'Rojo'
    END;
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_exposicion_crediticia_total(@cliente_id INT)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @total DECIMAL(18,2);

    SELECT @total = ISNULL(SUM(ISNULL(cr.saldo_credito, 0)
                      + ISNULL(ec.deuda_activa, 0)
                      + ISNULL(ec.deuda_activa_otras_entidades, 0)), 0)
    FROM dbo.clientes c
    LEFT JOIN dbo.solicitudes s ON s.cliente_id = c.id
    LEFT JOIN dbo.evaluaciones_crediticias ec ON ec.solicitud_id = s.id
    LEFT JOIN dbo.creditos cr ON cr.evaluacion_crediticia_id = ec.id
    WHERE c.id = @cliente_id;

    RETURN ISNULL(@total, 0);
END;
GO

/* ==========================================================
   FUNCIONES TABULARES
   ========================================================== */

CREATE OR ALTER FUNCTION dbo.fn_creditos_vigentes()
RETURNS TABLE
AS
RETURN
(
    SELECT *
    FROM dbo.creditos
    WHERE estado = 'vigente'
);
GO

CREATE OR ALTER FUNCTION dbo.fn_creditos_cliente(@cliente_id INT)
RETURNS TABLE
AS
RETURN
(
    SELECT cr.*
    FROM dbo.creditos cr
    INNER JOIN dbo.evaluaciones_crediticias ec ON ec.id = cr.evaluacion_crediticia_id
    INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
    WHERE s.cliente_id = @cliente_id
);
GO

CREATE OR ALTER FUNCTION dbo.fn_creditos_por_estado(@estado_credito VARCHAR(100))
RETURNS TABLE
AS
RETURN
(
    SELECT *
    FROM dbo.creditos
    WHERE estado = @estado_credito
);
GO

CREATE OR ALTER FUNCTION dbo.fn_solicitudes_por_anio(@anio INT)
RETURNS TABLE
AS
RETURN
(
    SELECT *
    FROM dbo.solicitudes
    WHERE YEAR(fecha_solicitud) = @anio
);
GO

CREATE OR ALTER FUNCTION dbo.fn_clientes_score_superior(@score_minimo DECIMAL(10,2))
RETURNS TABLE
AS
RETURN
(
    SELECT
        c.id AS cliente_id,
        CASE
            WHEN c.tipo_cliente = 'N' THEN CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres)
            ELSE pj.razon_social
        END AS cliente,
        ec.score_riesgo,
        ec.nivel_endeudamiento,
        ec.resultado
    FROM dbo.evaluaciones_crediticias ec
    INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
    INNER JOIN dbo.clientes c ON c.id = s.cliente_id
    LEFT JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id
    LEFT JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id
    WHERE ec.score_riesgo > @score_minimo
);
GO

/* ==========================================================
   PROCEDIMIENTOS ALMACENADOS
   ========================================================== */

CREATE OR ALTER PROCEDURE dbo.usp_listar_clientes
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.id AS cliente_id,
        CASE
            WHEN c.tipo_cliente = 'N' THEN CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres)
            ELSE pj.razon_social
        END AS cliente,
        CASE WHEN c.tipo_cliente = 'N' THEN 'Persona Natural' ELSE 'Persona Jurídica' END AS tipo_cliente
    FROM dbo.clientes c
    LEFT JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id
    LEFT JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_listar_cliente_por_id
    @cliente_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.id AS cliente_id,
        CASE
            WHEN c.tipo_cliente = 'N' THEN CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres)
            ELSE pj.razon_social
        END AS cliente,
        CASE WHEN c.tipo_cliente = 'N' THEN 'Persona Natural' ELSE 'Persona Jurídica' END AS tipo_cliente,
        pn.numero_documento,
        pj.ruc
    FROM dbo.clientes c
    LEFT JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id
    LEFT JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id
    WHERE c.id = @cliente_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_listar_productos_crediticios
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.productos_crediticios;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_solicitudes_por_estado
    @estado VARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.solicitudes WHERE estado = @estado;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_solicitudes_por_rango_fechas
    @fecha_inicio DATE,
    @fecha_fin DATE
AS
BEGIN
    SET NOCOUNT ON;
    SELECT *
    FROM dbo.solicitudes
    WHERE CAST(fecha_solicitud AS DATE) BETWEEN @fecha_inicio AND @fecha_fin;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_creditos_cliente
    @cliente_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.fn_creditos_cliente(@cliente_id);
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_cronograma_cuotas
    @credito_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        num_cuota,
        fecha_vencimiento,
        capital,
        intereses,
        seguros,
        total_cuota,
        saldo_cuota,
        estado
    FROM dbo.cuotas
    WHERE credito_id = @credito_id
    ORDER BY num_cuota;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_deuda_pendiente_credito
    @credito_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        @credito_id AS credito_id,
        ISNULL(SUM(saldo_cuota), 0) AS deuda_pendiente
    FROM dbo.cuotas
    WHERE credito_id = @credito_id
      AND estado IN ('pendiente', 'pagada parcialmente');
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_clientes_morosos
AS
BEGIN
    SET NOCOUNT ON;
    SELECT DISTINCT
        c.id AS cliente_id,
        CASE
            WHEN c.tipo_cliente = 'N' THEN CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres)
            ELSE pj.razon_social
        END AS cliente,
        pc.nombre AS producto_crediticio,
        cr.numero_credito,
        cu.fecha_vencimiento,
        cu.saldo_cuota
    FROM dbo.cuotas cu
    INNER JOIN dbo.creditos cr ON cr.id = cu.credito_id
    INNER JOIN dbo.evaluaciones_crediticias ec ON ec.id = cr.evaluacion_crediticia_id
    INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
    INNER JOIN dbo.productos_crediticios pc ON pc.id = s.producto_crediticio_id
    INNER JOIN dbo.clientes c ON c.id = s.cliente_id
    LEFT JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id
    LEFT JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id
    WHERE cu.fecha_vencimiento < GETDATE()
      AND cu.estado IN ('pendiente', 'pagada parcialmente')
      AND cu.saldo_cuota > 0;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_reporte_cliente_creditos_cuotas_pagos
    @cliente_id INT
AS
BEGIN
    SET NOCOUNT ON;

    SELECT cr.*
    FROM dbo.fn_creditos_cliente(@cliente_id) cr;

    SELECT cu.*
    FROM dbo.cuotas cu
    INNER JOIN dbo.creditos cr ON cr.id = cu.credito_id
    INNER JOIN dbo.evaluaciones_crediticias ec ON ec.id = cr.evaluacion_crediticia_id
    INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
    WHERE s.cliente_id = @cliente_id;

    SELECT p.*, dcp.cuota_id, dcp.monto_pagado
    FROM dbo.pagos p
    INNER JOIN dbo.detalle_cuotas_pagos dcp ON dcp.pago_id = p.id
    INNER JOIN dbo.cuotas cu ON cu.id = dcp.cuota_id
    INNER JOIN dbo.creditos cr ON cr.id = cu.credito_id
    INNER JOIN dbo.evaluaciones_crediticias ec ON ec.id = cr.evaluacion_crediticia_id
    INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
    WHERE s.cliente_id = @cliente_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_aprobar_solicitud
    @solicitud_id INT,
    @score_riesgo DECIMAL(10,2),
    @nivel_endeudamiento DECIMAL(10,2),
    @deuda_activa DECIMAL(18,2),
    @deuda_activa_otras_entidades DECIMAL(18,2),
    @linea_credito DECIMAL(18,2),
    @linea_credito_otras_entidades DECIMAL(18,2),
    @valor_patrimonio DECIMAL(18,2),
    @ingresos_mensuales DECIMAL(18,2),
    @plazo_meses INT,
    @tea DECIMAL(10,2),
    @tcea DECIMAL(10,2),
    @desgravamen DECIMAL(18,2),
    @cuenta_id INT
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @evaluacion_id INT;
        DECLARE @monto DECIMAL(18,2);
        DECLARE @fecha_inicio DATE = CAST(GETDATE() AS DATE);
        DECLARE @fecha_fin DATE;
        DECLARE @numero_credito INT;
        DECLARE @valor_cuota DECIMAL(18,2);
        DECLARE @tasa_mensual DECIMAL(18,10);

        SELECT @monto = monto_solicitado
        FROM dbo.solicitudes
        WHERE id = @solicitud_id;

        IF @monto IS NULL
            THROW 50001, 'La solicitud indicada no existe.', 1;

        UPDATE dbo.solicitudes
        SET estado = 'aprobada'
        WHERE id = @solicitud_id;

        INSERT INTO dbo.evaluaciones_crediticias
        (
            solicitud_id, score_riesgo, nivel_endeudamiento, deuda_activa,
            deuda_activa_otras_entidades, linea_credito, linea_credito_otras_entidades,
            valor_patrimonio, ingresos_mensuales, resultado
        )
        VALUES
        (
            @solicitud_id, @score_riesgo, @nivel_endeudamiento, @deuda_activa,
            @deuda_activa_otras_entidades, @linea_credito, @linea_credito_otras_entidades,
            @valor_patrimonio, @ingresos_mensuales, 'Aprobado'
        );

        SET @evaluacion_id = SCOPE_IDENTITY();
        SET @fecha_fin = DATEADD(MONTH, @plazo_meses, @fecha_inicio);
        SELECT @numero_credito = ISNULL(MAX(numero_credito), 0) + 1 FROM dbo.creditos;

        SET @tasa_mensual = POWER(1 + (@tea / 100.0), 1.0 / 12.0) - 1;
        SET @valor_cuota = CASE
            WHEN @plazo_meses <= 0 THEN 0
            WHEN @tasa_mensual = 0 THEN ROUND(@monto / @plazo_meses, 2)
            ELSE ROUND(@monto * ((@tasa_mensual * POWER(1 + @tasa_mensual, @plazo_meses)) / (POWER(1 + @tasa_mensual, @plazo_meses) - 1)), 2)
        END;

        INSERT INTO dbo.creditos
        (
            evaluacion_crediticia_id, monto, plazo_meses, tea, tcea, valor_cuota,
            fecha_inicio, fecha_fin, fecha_desembolso, numero_credito, fecha_vencimiento,
            estado, saldo_credito, desgravamen, cuenta_id
        )
        VALUES
        (
            @evaluacion_id, @monto, @plazo_meses, @tea, @tcea, @valor_cuota,
            @fecha_inicio, @fecha_fin, GETDATE(), @numero_credito, @fecha_fin,
            'vigente', @monto, @desgravamen, @cuenta_id
        );

        COMMIT TRANSACTION;

        SELECT SCOPE_IDENTITY() AS credito_id_generado, @numero_credito AS numero_credito;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_registrar_pago
    @cuota_id INT,
    @num_operacion VARCHAR(50),
    @monto DECIMAL(18,2),
    @metodo_pago VARCHAR(50),
    @observaciones VARCHAR(200) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @pago_id INT;
        DECLARE @saldo_actual DECIMAL(18,2);
        DECLARE @nuevo_saldo DECIMAL(18,2);

        SELECT @saldo_actual = saldo_cuota
        FROM dbo.cuotas
        WHERE id = @cuota_id;

        IF @saldo_actual IS NULL
            THROW 50002, 'La cuota indicada no existe.', 1;

        IF @monto <= 0
            THROW 50003, 'El monto del pago debe ser mayor a cero.', 1;

        INSERT INTO dbo.pagos(num_operacion, monto, fecha_pago, metodo_pago, observaciones)
        VALUES(@num_operacion, @monto, GETDATE(), @metodo_pago, @observaciones);

        SET @pago_id = SCOPE_IDENTITY();

        INSERT INTO dbo.detalle_cuotas_pagos(cuota_id, pago_id, monto_pagado)
        VALUES(@cuota_id, @pago_id, @monto);

        SET @nuevo_saldo = CASE WHEN @saldo_actual - @monto < 0 THEN 0 ELSE @saldo_actual - @monto END;

        UPDATE dbo.cuotas
        SET saldo_cuota = @nuevo_saldo,
            estado = CASE
                WHEN @nuevo_saldo = 0 THEN 'pagada'
                WHEN @nuevo_saldo < total_cuota THEN 'pagada parcialmente'
                ELSE 'pendiente'
            END
        WHERE id = @cuota_id;

        UPDATE cr
        SET saldo_credito = ISNULL((SELECT SUM(cu.saldo_cuota) FROM dbo.cuotas cu WHERE cu.credito_id = cr.id), 0)
        FROM dbo.creditos cr
        INNER JOIN dbo.cuotas c ON c.credito_id = cr.id
        WHERE c.id = @cuota_id;

        COMMIT TRANSACTION;
        SELECT @pago_id AS pago_id, @nuevo_saldo AS nuevo_saldo_cuota;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_refinanciar_credito
    @credito_id INT,
    @nuevo_plazo_meses INT,
    @nueva_tea DECIMAL(10,2),
    @nueva_tcea DECIMAL(10,2),
    @observacion VARCHAR(200)
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @evaluacion_id INT;
        DECLARE @saldo DECIMAL(18,2);
        DECLARE @cuenta_id INT;
        DECLARE @desgravamen DECIMAL(18,2);
        DECLARE @numero_credito INT;
        DECLARE @fecha_inicio DATE = CAST(GETDATE() AS DATE);
        DECLARE @fecha_fin DATE;
        DECLARE @valor_cuota DECIMAL(18,2);
        DECLARE @tasa_mensual DECIMAL(18,10);

        SELECT
            @evaluacion_id = evaluacion_crediticia_id,
            @saldo = saldo_credito,
            @cuenta_id = cuenta_id,
            @desgravamen = desgravamen
        FROM dbo.creditos
        WHERE id = @credito_id;

        IF @saldo IS NULL
            THROW 50004, 'El crédito indicado no existe.', 1;

        UPDATE dbo.creditos
        SET estado = 'refinanciado'
        WHERE id = @credito_id;

        SET @fecha_fin = DATEADD(MONTH, @nuevo_plazo_meses, @fecha_inicio);
        SELECT @numero_credito = ISNULL(MAX(numero_credito), 0) + 1 FROM dbo.creditos;
        SET @tasa_mensual = POWER(1 + (@nueva_tea / 100.0), 1.0 / 12.0) - 1;
        SET @valor_cuota = CASE
            WHEN @nuevo_plazo_meses <= 0 THEN 0
            WHEN @tasa_mensual = 0 THEN ROUND(@saldo / @nuevo_plazo_meses, 2)
            ELSE ROUND(@saldo * ((@tasa_mensual * POWER(1 + @tasa_mensual, @nuevo_plazo_meses)) / (POWER(1 + @tasa_mensual, @nuevo_plazo_meses) - 1)), 2)
        END;

        INSERT INTO dbo.creditos
        (
            evaluacion_crediticia_id, monto, plazo_meses, tea, tcea, valor_cuota,
            fecha_inicio, fecha_fin, fecha_desembolso, numero_credito, fecha_vencimiento,
            estado, saldo_credito, desgravamen, cuenta_id
        )
        VALUES
        (
            @evaluacion_id, @saldo, @nuevo_plazo_meses, @nueva_tea, @nueva_tcea, @valor_cuota,
            @fecha_inicio, @fecha_fin, GETDATE(), @numero_credito, @fecha_fin,
            'vigente', @saldo, @desgravamen, @cuenta_id
        );

        INSERT INTO dbo.pagos(num_operacion, monto, fecha_pago, metodo_pago, observaciones)
        VALUES(CONCAT('REF-', @credito_id, '-', @numero_credito), 0, GETDATE(), 'Refinanciación', @observacion);

        COMMIT TRANSACTION;
        SELECT SCOPE_IDENTITY() AS registro_observacion_id, @numero_credito AS nuevo_numero_credito;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_reporte_ejecutivo
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ISNULL(SUM(cr.saldo_credito), 0) AS total_cartera,
        ISNULL(SUM(cr.monto), 0) AS total_desembolsado,
        ISNULL((SELECT SUM(cu.saldo_cuota) FROM dbo.cuotas cu WHERE cu.estado IN ('pendiente', 'pagada parcialmente')), 0) AS total_pendiente,
        ISNULL((SELECT SUM(cu.saldo_cuota) FROM dbo.cuotas cu WHERE cu.fecha_vencimiento < GETDATE() AND cu.estado IN ('pendiente', 'pagada parcialmente')), 0) AS total_morosidad
    FROM dbo.creditos cr;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_ranking_clientes_exposicion
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        c.id AS cliente_id,
        CASE
            WHEN c.tipo_cliente = 'N' THEN CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres)
            ELSE pj.razon_social
        END AS cliente,
        dbo.fn_exposicion_crediticia_total(c.id) AS exposicion_crediticia_total,
        DENSE_RANK() OVER (ORDER BY dbo.fn_exposicion_crediticia_total(c.id) DESC) AS ranking
    FROM dbo.clientes c
    LEFT JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id
    LEFT JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id
    ORDER BY exposicion_crediticia_total DESC;
END;
GO

/* ==========================================================
   RETO FINAL - OBJETOS DE CONSULTA CREDITICIA
   ========================================================== */

CREATE OR ALTER VIEW dbo.vw_reto_clientes_resumen
AS
SELECT
    c.id AS cliente_id,
    CASE
        WHEN c.tipo_cliente = 'N' THEN CONCAT(pn.apellido_paterno, ' ', pn.apellido_materno, ' ', pn.nombres)
        ELSE pj.razon_social
    END AS cliente,
    CASE WHEN c.tipo_cliente = 'N' THEN 'Persona Natural' ELSE 'Persona Jurídica' END AS tipo_cliente,
    pn.numero_documento,
    pj.ruc
FROM dbo.clientes c
LEFT JOIN dbo.personas_naturales pn ON pn.cliente_id = c.id
LEFT JOIN dbo.personas_juridicas pj ON pj.cliente_id = c.id;
GO

CREATE OR ALTER VIEW dbo.vw_reto_indicadores_crediticios
AS
SELECT
    COUNT(DISTINCT c.id) AS total_clientes,
    COUNT(DISTINCT cr.id) AS total_creditos,
    ISNULL(SUM(cr.monto), 0) AS total_desembolsado,
    ISNULL(SUM(cr.saldo_credito), 0) AS total_saldo_credito
FROM dbo.clientes c
LEFT JOIN dbo.solicitudes s ON s.cliente_id = c.id
LEFT JOIN dbo.evaluaciones_crediticias ec ON ec.solicitud_id = s.id
LEFT JOIN dbo.creditos cr ON cr.evaluacion_crediticia_id = ec.id;
GO

CREATE OR ALTER FUNCTION dbo.fn_reto_calcular_riesgo(@score DECIMAL(10,2), @endeudamiento DECIMAL(10,2))
RETURNS VARCHAR(20)
AS
BEGIN
    RETURN dbo.fn_nivel_riesgo(@score, @endeudamiento);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_reto_total_pendiente_cliente(@cliente_id INT)
RETURNS DECIMAL(18,2)
AS
BEGIN
    DECLARE @total DECIMAL(18,2);
    SELECT @total = ISNULL(SUM(cu.saldo_cuota), 0)
    FROM dbo.cuotas cu
    INNER JOIN dbo.creditos cr ON cr.id = cu.credito_id
    INNER JOIN dbo.evaluaciones_crediticias ec ON ec.id = cr.evaluacion_crediticia_id
    INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
    WHERE s.cliente_id = @cliente_id;
    RETURN ISNULL(@total, 0);
END;
GO

CREATE OR ALTER FUNCTION dbo.fn_reto_creditos_cliente(@cliente_id INT)
RETURNS TABLE
AS
RETURN
(
    SELECT
        cr.id AS credito_id,
        cr.numero_credito,
        cr.monto,
        cr.saldo_credito,
        cr.estado,
        cr.fecha_inicio,
        cr.fecha_fin
    FROM dbo.creditos cr
    INNER JOIN dbo.evaluaciones_crediticias ec ON ec.id = cr.evaluacion_crediticia_id
    INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
    WHERE s.cliente_id = @cliente_id
);
GO

CREATE OR ALTER PROCEDURE dbo.usp_reto_consultar_cliente
    @cliente_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.vw_reto_clientes_resumen WHERE cliente_id = @cliente_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_reto_consultar_creditos_pagos
    @cliente_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT * FROM dbo.fn_reto_creditos_cliente(@cliente_id);

    SELECT
        p.id AS pago_id,
        p.num_operacion,
        p.monto,
        p.fecha_pago,
        p.metodo_pago,
        p.observaciones,
        cu.credito_id,
        cu.num_cuota
    FROM dbo.pagos p
    INNER JOIN dbo.detalle_cuotas_pagos dcp ON dcp.pago_id = p.id
    INNER JOIN dbo.cuotas cu ON cu.id = dcp.cuota_id
    INNER JOIN dbo.creditos cr ON cr.id = cu.credito_id
    INNER JOIN dbo.evaluaciones_crediticias ec ON ec.id = cr.evaluacion_crediticia_id
    INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
    WHERE s.cliente_id = @cliente_id;
END;
GO

CREATE OR ALTER PROCEDURE dbo.usp_reto_indicadores_cliente
    @cliente_id INT
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        @cliente_id AS cliente_id,
        dbo.fn_exposicion_crediticia_total(@cliente_id) AS exposicion_crediticia_total,
        dbo.fn_reto_total_pendiente_cliente(@cliente_id) AS total_pendiente,
        (SELECT TOP 1 dbo.fn_nivel_riesgo(ec.score_riesgo, ec.nivel_endeudamiento)
         FROM dbo.evaluaciones_crediticias ec
         INNER JOIN dbo.solicitudes s ON s.id = ec.solicitud_id
         WHERE s.cliente_id = @cliente_id
         ORDER BY ec.id DESC) AS riesgo_actual;
END;
GO
