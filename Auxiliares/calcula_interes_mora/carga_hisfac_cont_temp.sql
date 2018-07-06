SET ISOLATION TO DIRTY READ;

--------------------------------------------------------------------------------
--
--  Fecha: 06/2015
--
--  Autor: Pablo D. Privitera
--
--  Objetivo: Carga clientes en una tabla semejante a HISFAC_CONT. A estos clientes se les
--            facturo mal el interes por mora porque se cargo mal la tasa.
--            Esta tabla es usada por el proceso calcula_interes_mora para recalcular los intereses
--
--------------------------------------------------------------------------------
/*
CREATE TEMP TABLE cli
(
    numero_cliente      INTEGER,
    corr_facturacion    SMALLINT,
    fecha_facturacion   DATE,
    monto_interes       DECIMAL(12,2)
);


LOAD FROM interes_mora_mal.unl
INSERT INTO cli;
*/

BEGIN WORK;

INSERT INTO hisfac_cont_temp
(numero_cliente             , -- h.numero_cliente       --01
corr_facturacion            , -- h.corr_facturacion     --02
numero_factura              , -- h.numero_factura       --03
sucursal                    , -- h.sucursal             --04
sector                      , -- h.sector               --05
zona                        , -- h.zona                 --06
fecha_facturacion           , -- h.fecha_facturacion    --07
fecha_vencimiento1          , -- h.fecha_vencimiento1   --08
fecha_vencimiento2          , -- h.fecha_vencimiento2   --09
fecha_vencimiento3          , -- h.fecha_vencimiento3   --10
tarifa                      , -- h.tarifa               --11
clase_servicio              , -- h.clase_servicio       --12
jurisdiccion                , -- h.jurisdiccion         --13
tipo_iva                    , -- h.tipo_iva             --14
consumo_sum                 , -- h.consumo_sum          --15
coseno_phi                  , -- h.coseno_phi           --16
suma_tarifa                 , -- h.suma_tarifa          --17
suma_impuestos              , -- h.suma_impuestos       --18
suma_recargo                , -- h.suma_recargo         --19
suma_intereses              , -- h.suma_intereses       --20
suma_convenio               , -- h.suma_convenio        --21
cl_suma_convenio            ,                           --22
cl_fecha_ultima_le          , -- **** ver               --23
cl_sum_imp_no_suj           ,                           --24
cl_sum_imp_suj_int          ,                           --25
total_facturado             , -- h.total_facturado      --26
cl_suma_capital             ,                           --27
consumo_forzado             , -- h.consumo_forzado      --28
subtarifa                   , -- h.subtarifa            --29
suma_cargos_man             , -- h.suma_cargos_man      --30
saldo_anterior              , -- h.saldo_anterior       --31
intereses_acum              , -- h.intereses_acum       --32
saldo_ant_suj_int           , -- h.saldo_ant_suj_int    --33
tot_fact_suj_int            , -- h.tot_fac_suj_int      --34
prox_c_est_suces            ,                           --35
prox_c_estimac              ,                           --36
prox_c_meses_cerra          ,                           --37
ind_act_estado_con          ,                           --38
co_deuda_convenida          ,                           --39
total_a_pagar               , -- h.total_a_pagar        --40
indica_refact               , -- h.indica_refact        --41
frec_facturacion            , -- h.tarifa[3]            --42
partido                     , -- h.partido              --43
tipo_fpago                  , -- h.tipo_fpago           --44
centro_emisor               , -- h.centro_emisor        --45
tipo_docto                     -- h.tipo_docto          --46
)
SELECT h.numero_cliente        ,                        --01
       h.corr_facturacion      ,                        --02
       h.numero_factura        ,                        --03
       h.sucursal              ,                        --04
       h.sector                ,                        --05
       h.zona                  ,                        --06
       h.fecha_facturacion     ,                        --07
       h.fecha_vencimiento1    ,                        --08
       h.fecha_vencimiento2    ,                        --09
       h.fecha_vencimiento3    ,                        --10
       h.tarifa                ,                        --11
       h.clase_servicio        ,                        --12
       h.jurisdiccion          ,                        --13
       h.tipo_iva              ,                        --14
       h.consumo_sum           ,                        --15
       h.coseno_phi            ,                        --16
       h.suma_tarifa           ,                        --17
       h.suma_impuestos        ,                        --18
       h.suma_recargo          ,                        --19
       h.suma_intereses        ,                        --20
       h.suma_convenio         ,                        --21
       0                       ,                        --22
       0                       ,                        --23
       0                       ,                        --24
       0                       ,                        --25
       h.total_facturado       ,                        --26
       0                       ,                        --27
       h.consumo_forzado       ,                        --28
       h.subtarifa             ,                        --29
       h.suma_cargos_man       ,                        --30
       h.saldo_anterior        ,                        --31
       h.intereses_acum        ,                        --32
       h.saldo_ant_suj_int     ,                        --33
       h.tot_fac_suj_int       ,                        --34
       0                       ,                        --35
       0                       ,                        --36
       0                       ,                        --37
       'N'                     ,                        --38
       0                       ,                        --39
       h.total_a_pagar         ,                        --40
       h.indica_refact         ,                        --41
       h.tarifa[3]             ,                        --42
       h.partido               ,                        --43
       h.tipo_fpago            ,                        --44
       h.centro_emisor         ,                        --45
       h.tipo_docto                                     --46
  FROM cliente c, hisfac h
 WHERE c.estado_cliente = 0
   AND c.tipo_sum NOT IN (5, 6)
   AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm 
	WHERE cm.numero_cliente = c.numero_cliente 
	AND cm.fecha_activacion < TODAY
	AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY))
   AND h.numero_cliente   = c.numero_cliente
   AND h.corr_facturacion = c.corr_facturacion;

COMMIT WORK;

