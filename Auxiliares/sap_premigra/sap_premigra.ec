/********************************************************************************
    Proyecto: Migracion al sistema SAP IS-U
    Aplicacion: sap_premigra
    
	Fecha : 15/05/2018

	Autor : Lucas Daniel Valle(LDV)

	Funcion del programa : 
		Calcular y grabar las fechas y estados de los clientes, para que sean tomados
      por los demás extractores.
		
	Descripcion de parametros :
		<Base de Datos> : Base de Datos <synergia>
		
		<Nro.Cliente>: Opcional

********************************************************************************/
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <time.h>
#include <synmail.h>

$include "sap_premigra.h";

/* Variables Globales */
$long	glNroCliente;
$int	giEstadoCliente;
$char	gsTipoGenera[2];
int   giTipoCorrida;
int   giTipoTabla;

FILE	*pFileDepgarUnx;

char	sArchDepgarUnx[100];
char	sSoloArchivoDepgar[100];

char	sPathSalida[100];
char	FechaGeneracion[9];	
char	MsgControl[100];
$char	fecha[9];
long	lCorrelativo;

long	cantProcesada;
long	cantBloque;


char	sMensMail[1024];	

/* Variables Globales Host */
$long lFechaPivote;
$long lFechaRti;
$long	lFechaLimiteInferior;
char  sFechaLimInf[11];
$long lFechaMac;
char  sFechaMac[11];
$char sFechaPivoteAux[11];

$WHENEVER ERROR CALL SqlException;

void main( int argc, char **argv ) 
{
$char 	nombreBase[20];
time_t 	hora;
int	iFlagMigra=0;
$long	   lCorrFactuIni;
$ClsCliente regCliente;
$ClsEstado  regEstado;
int				iNx;
$long			lFechaAlta;
$long			lFechaIniAnterior;
$long			lFechaHastaAnterior;
long			lDifDias;
char			sFechaAlta[9];
char        sFechaValTarifa[9];
long        lFechaValTarifa;

	if(! AnalizarParametros(argc, argv)){
		exit(0);
	}
	
	hora = time(&hora);
	
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));
	
	strcpy(nombreBase, argv[1]);
	
	$DATABASE :nombreBase;	
	
	$SET LOCK MODE TO WAIT;
	$SET ISOLATION TO DIRTY READ;
   $SET ISOLATION TO CURSOR STABILITY;	

	CreaPrepare();
		
	/* ********************************************
				INICIO AREA DE PROCESO
	********************************************* */
	cantProcesada=0;
	cantBloque=0;

   strcpy(sFechaLimInf, "01-12-2014");
   rdefmtdate(&lFechaLimiteInferior, "dd-mm-yyyy", sFechaLimInf);

   strcpy(sFechaMac, "24-09-1995");
   rdefmtdate(&lFechaMac, "dd-mm-yyyy", sFechaMac);   

   strcpy(sFechaValTarifa, "01-12-2014");
   rdefmtdate(&lFechaValTarifa, "dd-mm-yyyy", sFechaValTarifa);   

   strcpy(sFechaPivoteAux, "12-08-2017");
   rdefmtdate(&lFechaPivote, "dd-mm-yyyy", sFechaPivoteAux);   
   /*$EXECUTE selFechaPivote INTO :lFechaPivote;*/

   if(SQLCODE != 0){
      printf("Error no se levanto la fecha pivote\n");
      exit(1);
   }
      
   $EXECUTE selFechaRti INTO :lFechaRti;
   if(SQLCODE != 0){
      printf("Error no se levanto la fecha RTI\n");
      exit(1);
   }

	$OPEN curClientes;
	
	while(LeoCliente(&regCliente)){
      InicializaEstado(&regEstado);
      
      regEstado.numero_cliente = regCliente.numero_cliente;
      regEstado.lFechaPivote = lFechaPivote;

      /* Fecha Alta Real */
      regEstado.lFechaAlta = getAlta(regCliente);
      
      /* Fecha Validez de Tarifa */
      /* Ahora será una constante
      regEstado.lFechaValTar = getValTar(regCliente);
      */
      regEstado.lFechaValTar = lFechaValTarifa;
      
      /* Fecha Move In */
      regEstado.lFechaMoveIn = getMoveIn(regCliente, regEstado.lFechaAlta);
      
      /* Tarifa - UL y Motivo Alta */
      CargaEstados(regCliente, &regEstado);
      
      /* Grabar */
      $BEGIN WORK;
      
      if(!GrabaEstados(regEstado)){
         printf("No se grabo los estados para cliente %ld\n", regEstado.numero_cliente);
      }
       
      $COMMIT WORK;
			
      cantProcesada++;
      cantBloque++;
      
      if(cantBloque == 100000){
      	hora = time(&hora);
         printf("\tLlevo %ld Clientes. Hora Actual %s\n", cantProcesada, ctime(&hora));
         cantBloque=0;
      }
	}
   if(giTipoCorrida != 2){   
      $BEGIN WORK;
      if(giTipoTabla == 0){   
         $EXECUTE insParam USING :lFechaPivote, :lFechaLimiteInferior;
      }else{
         $EXECUTE insParamAux USING :lFechaPivote, :lFechaLimiteInferior;
      }
   
      $COMMIT WORK;
   }
   
	$CLOSE curClientes;

	$CLOSE DATABASE;

	$DISCONNECT CURRENT;

	/* ********************************************
				FIN AREA DE PROCESO
	********************************************* */


/*	
	if(! EnviarMail(sArchResumenDos, sArchControlDos)){
		printf("Error al enviar mail con lista de respaldo.\n");
		printf("El mismo se pueden extraer manualmente en..\n");
		printf("     [%s]\n", sArchResumenDos);
	}else{
		sprintf(sCommand, "rm -f %s", sArchResumenDos);
		iRcv=system(sCommand);			
	}
*/

	printf("==============================================\n");
	printf("PRE-MIGRA.\n");
	printf("==============================================\n");
	printf("Proceso Concluido.\n");
	printf("==============================================\n");
	printf("Clientes Procesados :       %ld \n",cantProcesada);
	printf("==============================================\n");
	printf("\nHora antes de comenzar proceso : %s\n", ctime(&hora));						

	hora = time(&hora);
	printf("\nHora de finalizacion del proceso : %s\n", ctime(&hora));

	printf("Fin del proceso OK\n");	

	exit(0);
}	

short AnalizarParametros(argc, argv)
int		argc;
char	* argv[];
{

	if(argc != 4){
		MensajeParametros();
		return 0;
	}
	
   giTipoCorrida=atoi(argv[2]);
   giTipoTabla=atoi(argv[3]);
   
	return 1;
}

void MensajeParametros(void){
		printf("Error en Parametros.\n");
		printf("	<Base> = synergia.\n");
      printf("	<Univ.> 0=Total, 1=Reducida, 2=Actualiza \n");
      printf(" <Modo>  0=Normal, 1=Tabla Auxiliar\n");
}


void CreaPrepare(void){
$char sql[10000];
$char sAux[1000];

	memset(sql, '\0', sizeof(sql));
	memset(sAux, '\0', sizeof(sAux));
	
	/******** Fecha Actual Formateada ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%Y%m%d') FROM dual ");
	
	$PREPARE selFechaActualFmt FROM $sql;

	/******** Fecha Actual  ****************/
	strcpy(sql, "SELECT TO_CHAR(TODAY, '%d/%m/%Y') FROM dual ");
	
	$PREPARE selFechaActual FROM $sql;	
	
   /******** Fecha Pivote  ****************/
   strcpy(sql, "SELECT TODAY - 420 FROM dual");
   
   $PREPARE selFechaPivote FROM $sql;
   
   /******** Fecha Rti  ****************/
   strcpy(sql, "SELECT fecha_modificacion ");
	strcat(sql, "FROM tabla ");
	strcat(sql, "WHERE nomtabla = 'SAPFAC' ");
	strcat(sql, "AND sucursal = '0000' ");
	strcat(sql, "AND codigo = 'RTI-1' ");
	strcat(sql, "AND fecha_activacion <= TODAY ");
	strcat(sql, "AND (fecha_desactivac IS NULL OR fecha_desactivac > TODAY) ");
   
   $PREPARE selFechaRti FROM $sql;   
   
	/******** Clientes  *********/
	strcpy(sql, "SELECT DISTINCT c.numero_cliente, ");
	strcat(sql, "c.sucursal, "); 
	strcat(sql, "c.sector, ");
	strcat(sql, "c.tarifa, ");
	strcat(sql, "c.tipo_sum, ");
	strcat(sql, "NVL(c.corr_facturacion, 0) corrFac, ");
	strcat(sql, "c.provincia, ");
	strcat(sql, "c.partido, ");
	strcat(sql, "c.comuna, ");
	strcat(sql, "c.tipo_iva, ");
	strcat(sql, "c.tipo_cliente, ");
	strcat(sql, "c.actividad_economic, ");
	strcat(sql, "NVL(c.nro_beneficiario, 0) beneficiario, ");
   
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' "); 
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' "); 
	strcat(sql, "	ELSE t1.cod_sap ");
	strcat(sql, "END, ");
    
	strcat(sql, "s.cod_ul_sap || "); 
	strcat(sql, "LPAD(CASE WHEN c.sector>60 AND c.sector < 81 THEN c.sector ELSE c.sector END, 2, 0) || ");  
	strcat(sql, "LPAD(c.zona,5,0) ");
   
	strcat(sql, "FROM cliente c, sap_transforma t1, sucur_centro_op s ");
   
if(giTipoCorrida == 1){
   strcat(sql, ", migra_activos ma ");
}
if(giTipoCorrida == 2){
   strcat(sql, ", sap_actuclie ma ");
}

	strcat(sql, "WHERE c.estado_cliente = 0 ");
	strcat(sql, "AND c.tipo_sum != 5 ");

if(giTipoCorrida == 1){
   strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
}   
if(giTipoCorrida == 2){
   strcat(sql, "AND ma.numero_cliente = c.numero_cliente ");
}
   
if(giTipoCorrida != 2 && giTipoTabla ==0){   
   strcat(sql, "AND not exists ( select 1 from sap_regi_cliente s where s.numero_cliente = c.numero_cliente ) ");
}

	strcat(sql, "AND t1.clave = 'TARIFTYP' " );
	strcat(sql, "AND t1.cod_mac = c.tarifa "); 
	strcat(sql, "AND s.cod_centro_op = c.sucursal "); 
	strcat(sql, "AND s.fecha_activacion <= TODAY "); 
	strcat(sql, "AND (s.fecha_desactivac IS NULL OR s.fecha_desactivac > TODAY) "); 
   
	strcat(sql, "AND NOT EXISTS (SELECT 1 FROM clientes_ctrol_med cm ");
	strcat(sql, "WHERE cm.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND cm.fecha_activacion < TODAY ");
	strcat(sql, "AND (cm.fecha_desactiva IS NULL OR cm.fecha_desactiva > TODAY)) ");
   
	$PREPARE selClientes FROM $sql;
	
	$DECLARE curClientes CURSOR WITH HOLD FOR selClientes;
		
   /******** FEcha Vig.Tarifa 1 *********/
	strcpy(sql, "SELECT MIN(fecha_lectura) FROM hislec ");
	strcat(sql, "WHERE numero_cliente = ? ");
	strcat(sql, "AND fecha_lectura > ? ");
	strcat(sql, "AND tipo_lectura NOT IN (5, 6, 8) ");
   
   $PREPARE selValTar1 FROM $sql;
            
   /******** FEcha Vig.Tarifa 2 *********/
	strcpy(sql, "SELECT fecha_terr_puser ");
	strcat(sql, "FROM estoc ");
	strcat(sql, "WHERE numero_cliente = ? ");
   
   $PREPARE selValTar2 FROM $sql;
            
   /******** FEcha Retiro *********/
	strcpy(sql, "SELECT DATE(MAX(m2.fecha_modif)) ");
	strcat(sql, "FROM modif m2 ");
	strcat(sql, "WHERE m2.numero_cliente = ? ");
	strcat(sql, "AND m2.codigo_modif = 58 ");   

   $PREPARE selRetiro FROM $sql;
      
   /******** FEcha Instalacion *********/
	strcpy(sql, "SELECT MIN(m.fecha_ult_insta) ");
	strcat(sql, "FROM medid m ");
	strcat(sql, "WHERE m.numero_cliente = ? ");
   
   $PREPARE selInstalacion FROM $sql;

   /******** FEcha Primera factura *********/
	strcpy(sql, "SELECT h1.fecha_facturacion ");
	strcat(sql, "FROM hisfac h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.corr_facturacion = (SELECT MIN(h2.corr_facturacion) ");
	strcat(sql, "	FROM hisfac h2 WHERE h2.numero_cliente = h1.numero_cliente) ");
   
   $PREPARE selPrimFactu FROM $sql;
            
   /******** FEcha Move In 1 *********/
	strcpy(sql, "SELECT MIN(h1.fecha_lectura) ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND tipo_lectura = 8 ");
	strcat(sql, "AND h1.fecha_lectura > (SELECT MIN(h2.fecha_lectura) ");
	strcat(sql, "	FROM hislec h2 "); 
	strcat(sql, " 	WHERE h2.numero_cliente = h1.numero_cliente ");
	strcat(sql, "  AND h2.tipo_lectura IN (1,2,3,4) ");
	strcat(sql, "  AND h2.fecha_lectura > ?) ");

	strcpy(sql, "SELECT MIN(h1.fecha_lectura + 1) ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.fecha_lectura >= ? ");
	strcat(sql, "AND tipo_lectura in (1, 2, 3, 4) ");
      
   $PREPARE selMoveIn FROM $sql;
               
   /******** FEcha Move In 2 *********/
	strcpy(sql, "SELECT MIN(h1.fecha_lectura + 1) ");
	strcat(sql, "FROM hislec h1 ");
	strcat(sql, "WHERE h1.numero_cliente = ? ");
	strcat(sql, "AND h1.fecha_lectura >= ? ");
	strcat(sql, "AND tipo_lectura in (6, 7) ");
      
   $PREPARE selMoveIn2 FROM $sql;
                  
   /******** Estados *********/
	strcpy(sql, "SELECT first 1 ");
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN h.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' "); 
	strcat(sql, "	WHEN h.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' "); 
	strcat(sql, "	ELSE t1.cod_sap ");
	strcat(sql, "END, "); 
	strcat(sql, "s.cod_ul_sap || "); 
	strcat(sql, "LPAD(CASE WHEN h.sector>60 AND h.sector < 81 THEN h.sector ELSE h.sector END, 2, 0) || ");  
	strcat(sql, "LPAD(h.zona,5,0), ");
	strcat(sql, "h.corr_facturacion ");
	strcat(sql, "FROM cliente c, hisfac h, sap_transforma t1, sucur_centro_op s "); 
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND h.numero_cliente = c.numero_cliente ");
	strcat(sql, "AND h.fecha_lectura >= ? ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' " );
	strcat(sql, "AND t1.cod_mac = h.tarifa "); 
	strcat(sql, "AND s.cod_centro_op = h.sucursal "); 
	strcat(sql, "AND s.fecha_activacion <= TODAY "); 
	strcat(sql, "AND (s.fecha_desactivac IS NULL OR s.fecha_desactivac > TODAY) "); 
	strcat(sql, "ORDER BY h.corr_facturacion ASC ");
         
   $PREPARE selEstados FROM $sql;
               
   /********** Estados 2 ************/
	strcpy(sql, "SELECT ");
	strcat(sql, "CASE ");
	strcat(sql, "	WHEN c.tarifa[2] != 'P' AND c.tipo_sum IN(1,2,3,6) THEN 'T1-GEN-NOM' "); 
	strcat(sql, "	WHEN c.tarifa[2] = 'P' AND c.tipo_sum = 6 THEN 'T1-AP' "); 
	strcat(sql, "	ELSE t1.cod_sap ");
	strcat(sql, "END, "); 
	strcat(sql, "s.cod_ul_sap || "); 
	strcat(sql, "LPAD(CASE WHEN c.sector>60 AND c.sector < 81 THEN c.sector ELSE c.sector END, 2, 0) || ");  
	strcat(sql, "LPAD(c.zona,5,0) ");
	strcat(sql, "FROM cliente c, sap_transforma t1, sucur_centro_op s "); 
	strcat(sql, "WHERE c.numero_cliente = ? ");
	strcat(sql, "AND t1.clave = 'TARIFTYP' " );
	strcat(sql, "AND t1.cod_mac = c.tarifa "); 
	strcat(sql, "AND s.cod_centro_op = c.sucursal "); 
	strcat(sql, "AND s.fecha_activacion <= TODAY "); 
	strcat(sql, "AND (s.fecha_desactivac IS NULL OR s.fecha_desactivac > TODAY) "); 
   
   $PREPARE selEstados2 FROM $sql;
   
   /******** Motivo Alta *********/
	strcpy(sql, "SELECT e.cod_motivo "); 
	strcat(sql, "FROM solicitud s, est_sol e " );
	strcat(sql, "WHERE s.numero_cliente = ? " );
	strcat(sql, "AND e.nro_solicitud = s.nro_solicitud ");
   
   $PREPARE selMotAlta FROM $sql;   
   
   /******** Inserta Estados *********/
	strcpy(sql, "INSERT INTO sap_regi_cliente (numero_cliente, "); 
	strcat(sql, "fecha_val_tarifa, "); 
	strcat(sql, "fecha_alta_real, ");
	strcat(sql, "fecha_move_in, "); 
	strcat(sql, "fecha_pivote, ");
   strcat(sql, "fecha_limi_inf,");
	strcat(sql, "tarifa, ");
	strcat(sql, "ul, ");
	strcat(sql, "motivo_alta, ");
   strcat(sql, "tarifa_actual, ");
   strcat(sql, "ul_actual, ");
   strcat(sql, "device ");
	strcat(sql, " )VALUES( ?,?,?,?,?,?,?,?,?,?,?,?) ");
   
   $PREPARE insRegiMigra FROM $sql;   
   
   /******** Inserta parametro *********/
	strcpy(sql, "INSERT INTO sap_regi_cliente (numero_cliente, "); 
	strcat(sql, "fecha_pivote, ");
   strcat(sql, "fecha_limi_inf ");
	strcat(sql, " )VALUES( 0,?,?) ");
   
   $PREPARE insParam FROM $sql;   
   
   /********* Actualiza Estados ********/
   strcpy( sql, "UPDATE sap_regi_cliente SET ");
	strcat(sql, "fecha_val_tarifa = ?, "); 
	strcat(sql, "fecha_alta_real = ?, ");
	strcat(sql, "fecha_move_in = ?, "); 
	strcat(sql, "fecha_pivote = ?, ");
   strcat(sql, "fecha_limi_inf = ?,");
	strcat(sql, "tarifa = ?, ");
	strcat(sql, "ul = ?, ");
	strcat(sql, "motivo_alta = ?, ");
   strcat(sql, "tarifa_actual = ?, ");
   strcat(sql, "ul_actual = ?, ");
   strcat(sql, "device = ? ");
   strcat(sql, "WHERE numero_cliente = ? ");
   
   $PREPARE updParam FROM $sql;


   /******** Inserta Estados AUX *********/
	strcpy(sql, "INSERT INTO sap_regi_cliaux (numero_cliente, "); 
	strcat(sql, "fecha_val_tarifa, "); 
	strcat(sql, "fecha_alta_real, ");
	strcat(sql, "fecha_move_in, "); 
	strcat(sql, "fecha_pivote, ");
   strcat(sql, "fecha_limi_inf,");
	strcat(sql, "tarifa, ");
	strcat(sql, "ul, ");
	strcat(sql, "motivo_alta, ");
   strcat(sql, "tarifa_actual, ");
   strcat(sql, "ul_actual, ");
   strcat(sql, "device ");
	strcat(sql, " )VALUES( ?,?,?,?,?,?,?,?,?,?,?,?) ");
   
   $PREPARE insRegiMigraAux FROM $sql;   
   
   /******** Inserta parametro AUX *********/
	strcpy(sql, "INSERT INTO sap_regi_cliaux (numero_cliente, "); 
	strcat(sql, "fecha_pivote, ");
   strcat(sql, "fecha_limi_inf ");
	strcat(sql, " )VALUES( 0,?,?) ");
   
   $PREPARE insParamAux FROM $sql;   
   
   /********* Actualiza Estados AUX ********/
   strcpy( sql, "UPDATE sap_regi_cliaux SET ");
	strcat(sql, "fecha_val_tarifa = ?, "); 
	strcat(sql, "fecha_alta_real = ?, ");
	strcat(sql, "fecha_move_in = ?, "); 
	strcat(sql, "fecha_pivote = ?, ");
   strcat(sql, "fecha_limi_inf = ?,");
	strcat(sql, "tarifa = ?, ");
	strcat(sql, "ul = ?, ");
	strcat(sql, "motivo_alta = ?, ");
   strcat(sql, "tarifa_actual = ?, ");
   strcat(sql, "ul_actual = ?, ");
   strcat(sql, "device = ? ");
   strcat(sql, "WHERE numero_cliente = ? ");
   
   $PREPARE updParamAux FROM $sql;
   
   /****** Medidor Actual ******/
   $PREPARE selMedidor FROM "SELECT 'T1' || numero_medidor || marca_medidor || modelo_medidor 
      FROM medid
      WHERE numero_cliente = ?
      AND estado = 'I' ";
   
}


short LeoCliente(reg)
$ClsCliente *reg;
{
	InicializaCliente(reg);

	$FETCH curClientes INTO
      :reg->numero_cliente,
      :reg->sucursal,
      :reg->sector,
      :reg->tarifa,
      :reg->tipo_sum,
      :reg->corr_facturacion,
      :reg->provincia,
      :reg->partido,
      :reg->comuna,
      :reg->tipo_iva,
      :reg->tipo_cliente,
      :reg->actividad_economic,
      :reg->sNroBeneficiario,
      :reg->sTarifaActual,
      :reg->sULactual;
   
    if ( SQLCODE != 0 ){
    	if(SQLCODE == 100){
			return 0;
		}else{
			printf("Error al leer Cursor de CLIENTES !!!\nProceso Abortado.\n");
			exit(1);	
		}
    }			

	return 1;	
}


void InicializaCliente(reg)
$ClsCliente	*reg;
{
   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   memset(reg->sucursal, '\0', sizeof(reg->sucursal)); 
   rsetnull(CINTTYPE, (char *) &(reg->sector));
   memset(reg->tarifa, '\0', sizeof(reg->tarifa));
   rsetnull(CINTTYPE, (char *) &(reg->tipo_sum));
   rsetnull(CINTTYPE, (char *) &(reg->corr_facturacion));
   memset(reg->provincia, '\0', sizeof(reg->provincia));
   memset(reg->partido, '\0', sizeof(reg->partido));
   memset(reg->comuna, '\0', sizeof(reg->comuna));
   memset(reg->tipo_iva, '\0', sizeof(reg->tipo_iva));
   memset(reg->tipo_cliente, '\0', sizeof(reg->tipo_cliente));
   memset(reg->actividad_economic, '\0', sizeof(reg->actividad_economic));
   memset(reg->sNroBeneficiario, '\0', sizeof(reg->sNroBeneficiario));
   
   memset(reg->sULactual, '\0', sizeof(reg->sULactual));
   memset(reg->sTarifaActual, '\0', sizeof(reg->sTarifaActual));

}

void InicializaEstado(reg)
$ClsEstado	*reg;
{

   rsetnull(CLONGTYPE, (char *) &(reg->numero_cliente));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaValTar));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaAlta));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaMoveIn));
   rsetnull(CLONGTYPE, (char *) &(reg->lFechaPivote));

   memset(reg->sTarifa, '\0', sizeof(reg->sTarifa));
   memset(reg->sUL, '\0', sizeof(reg->sUL));
   memset(reg->sMotivoAlta, '\0', sizeof(reg->sMotivoAlta));
   
   memset(reg->sULactual, '\0', sizeof(reg->sULactual));
   memset(reg->sTarifaActual, '\0', sizeof(reg->sTarifaActual));
   memset(reg->sMedidorActual, '\0', sizeof(reg->sMedidorActual));

}

long getValTar(reg)
$ClsCliente reg;
{
   $long lFecha;
   $long lBenef;
   
   if(reg.corr_facturacion > 0){
      $EXECUTE selValTar1 INTO :lFecha USING :reg.numero_cliente, :lFechaLimiteInferior;
      
      if(SQLCODE != 0){
         printf("No se encontró Fecha Val.Tar para cliente %ld\n", reg.numero_cliente);
         lFecha = lFechaLimiteInferior;
      }else{
         if(lFechaLimiteInferior > lFecha)
            lFecha=lFechaLimiteInferior;
      } 
   }else{
      $EXECUTE selValTar2 INTO :lFecha USING :reg.numero_cliente;
      
      if(SQLCODE != 0){
         lBenef=atol(reg.sNroBeneficiario);
         if(lBenef > 0){
            $EXECUTE selRetiro INTO :lFecha USING :lBenef;
            
            if(SQLCODE != 0){
               printf("No se encontró Fecha Val.Tar para beneficiario %ld\n", lBenef);
               lFecha = lFechaLimiteInferior;
            }
         }else{
            lFecha = lFechaLimiteInferior;
         }
      }else{
         if(lFechaLimiteInferior > lFecha)
            lFecha=lFechaLimiteInferior;
      }
   }
   
   return lFecha;
}

long getAlta(reg)
$ClsCliente reg;
{
   $long lFecha=0;
   $long lBenef=0;
   
   $EXECUTE selValTar2 INTO :lFecha USING :reg.numero_cliente;
   
   if(SQLCODE != 0){
      lBenef=atol(reg.sNroBeneficiario);
      if(lBenef > 0){
         $EXECUTE selRetiro INTO :lFecha USING :lBenef;
         
         if(SQLCODE != 0){
            lFecha = lFechaMac;
         }
      }else{
         $EXECUTE selInstalacion INTO :lFecha USING :reg.numero_cliente;
         
         if(SQLCODE !=0){
            lFecha = lFechaMac;
         }
      }
   }

   if(lFecha<=0 || risnull(CLONGTYPE, (char *) &lFecha)){
      $EXECUTE selPrimFactu INTO :lFecha USING :reg.numero_cliente;
   }

   if(lFecha<=0 || risnull(CLONGTYPE, (char *) &lFecha)){
      lFecha = lFechaMac;
   }
      
   return lFecha;
}

long getMoveIn(reg, lFechaAlta)
$ClsCliente reg;
$long       lFechaAlta;
{
   $long lFecha=0;

   /*$EXECUTE selMoveIn INTO :lFecha USING :reg.numero_cliente, :lFechaRti;*/
   
   if(lFechaAlta < lFechaPivote ){
      $EXECUTE selMoveIn INTO :lFecha USING :reg.numero_cliente, :lFechaPivote;
   }else{
      $EXECUTE selMoveIn2 INTO :lFecha USING :reg.numero_cliente, :lFechaPivote;
   }
   
   if(SQLCODE != 0){
      lFecha = lFechaPivote;
   }

   if(lFecha<=0 || risnull(CLONGTYPE, (char *) &lFecha)){
      lFecha = lFechaPivote; 
   }

   return lFecha;
}

void CargaEstados(regCliente, regEstado)
$ClsCliente regCliente;
$ClsEstado  *regEstado;
{

   strcpy(regEstado->sTarifaActual, regCliente.sTarifaActual);
   strcpy(regEstado->sULactual, regCliente.sULactual);

   $EXECUTE selEstados INTO :regEstado->sTarifa, 
                            :regEstado->sUL
                       USING :regCliente.numero_cliente,
                             :regEstado->lFechaMoveIn;    /* :lFechaPivote; */ 
                             
   if(SQLCODE != 0){
      if(SQLCODE != SQLNOTFOUND){
         printf("No se encontro Tarifa y UL para cliente %ld en fecha MoveIn\n", regCliente.numero_cliente);
      }
         $EXECUTE selEstados2 INTO :regEstado->sTarifa, 
                                  :regEstado->sUL
                             USING :regCliente.numero_cliente;
      
         if(SQLCODE != 0){
            printf("ERROR. No se encontro Tarifa y UL para cliente %ld en CLIENTE\n", regCliente.numero_cliente);
         }
   }                             

   alltrim(regEstado->sTarifa, ' ');
   alltrim(regEstado->sUL, ' ');

   if(strcmp(regEstado->sTarifa, "")==0 || strcmp(regEstado->sUL, "")==0){
      printf("ERROR. No se encontro Tarifa y UL para cliente %ld en CLIENTE\n", regCliente.numero_cliente);
   }

   $EXECUTE selMotAlta INTO :regEstado->sMotivoAlta USING :regCliente.numero_cliente;

   if(SQLCODE != 0){
      strcpy(regEstado->sMotivoAlta, "N2");  
   }else{
      alltrim(regEstado->sMotivoAlta, ' ');
      if(strcmp(regEstado->sMotivoAlta, "S16")==0){
         strcpy(regEstado->sMotivoAlta, "N1");
      }else{
         strcpy(regEstado->sMotivoAlta, "N2");
      }
   }                             

   alltrim(regEstado->sMotivoAlta, ' ');
   
   if(strcmp(regEstado->sMotivoAlta, "")==0){
      printf("ERROR. No se encontro Motivo Alta para cliente %ld en CLIENTE\n", regCliente.numero_cliente);
   }
   
   strcpy(regEstado->sMedidorActual, getMedidor(regCliente.numero_cliente));
      
}

short GrabaEstados(reg)
$ClsEstado  reg;
{

   if(giTipoTabla==0){
      if(giTipoCorrida != 2){
         $EXECUTE insRegiMigra USING
            :reg.numero_cliente,
            :reg.lFechaValTar,
            :reg.lFechaAlta,
            :reg.lFechaMoveIn,
            :reg.lFechaPivote,
            :lFechaLimiteInferior,
            :reg.sTarifa,
            :reg.sUL,
            :reg.sMotivoAlta,
            :reg.sTarifaActual,
            :reg.sULactual,
            :reg.sMedidorActual;
      }else{
         $EXECUTE updParam USING
            :reg.lFechaValTar,
            :reg.lFechaAlta,
            :reg.lFechaMoveIn,
            :reg.lFechaPivote,
            :lFechaLimiteInferior,
            :reg.sTarifa,
            :reg.sUL,
            :reg.sMotivoAlta,
            :reg.sTarifaActual,
            :reg.sULactual,
            :reg.sMedidorActual,
            :reg.numero_cliente;
      }
   }else{
      if(giTipoCorrida != 2){
         $EXECUTE insRegiMigraAux USING
            :reg.numero_cliente,
            :reg.lFechaValTar,
            :reg.lFechaAlta,
            :reg.lFechaMoveIn,
            :reg.lFechaPivote,
            :lFechaLimiteInferior,
            :reg.sTarifa,
            :reg.sUL,
            :reg.sMotivoAlta
            :reg.sTarifaActual,
            :reg.sULactual,
            :reg.sMedidorActual;
            
      }else{
         $EXECUTE updParamAux USING
            :reg.lFechaValTar,
            :reg.lFechaAlta,
            :reg.lFechaMoveIn,
            :reg.lFechaPivote,
            :lFechaLimiteInferior,
            :reg.sTarifa,
            :reg.sUL,
            :reg.sMotivoAlta,
            :reg.sTarifaActual,
            :reg.sULactual,
            :reg.sMedidorActual,
            :reg.numero_cliente;
      }
   
   }      
   if(SQLCODE != 0){
      return 0;
   }
   return 1;
}

char  *getMedidor(lNroCliente)
$long lNroCliente;
{
   $char device[16];
   
   memset(device, '\0', sizeof(device));
   
   $EXECUTE selMedidor INTO :device USING :lNroCliente;
   
   if(SQLCODE != 0){
      printf("No se encontró medidor para cliente %ld\n", lNroCliente);
      return;
   }

   return device;
}


/****************************
		GENERALES
*****************************/

void command(cmd,buff_cmd)
char *cmd;
char *buff_cmd;
{
   FILE *pf;
   char *p_aux;
   pf =  popen(cmd, "r");
   if (pf == NULL)
       strcpy(buff_cmd, "E   Error en ejecucion del comando");
   else
       {
       strcpy(buff_cmd,"\n");
       while (fgets(buff_cmd + strlen(buff_cmd),512,pf))
           if (strlen(buff_cmd) > 5000)
              break;
       }
   p_aux = buff_cmd;
   *(p_aux + strlen(buff_cmd) + 1) = 0;
   pclose(pf);
}

/*
short EnviarMail( Adjunto1, Adjunto2)
char *Adjunto1;
char *Adjunto2;
{
    char 	*sClave[] = {SYN_CLAVE};
    char 	*sAdjunto[3]; 
    int		iRcv;
    
    sAdjunto[0] = Adjunto1;
    sAdjunto[1] = NULL;
    sAdjunto[2] = NULL;

	iRcv = synmail(sClave[0], sMensMail, NULL, sAdjunto);
	
	if(iRcv != SM_OK){
		return 0;
	}
	
    return 1;
}

void  ArmaMensajeMail(argv)
char	* argv[];
{
$char	FechaActual[11];

	
	memset(FechaActual,'\0', sizeof(FechaActual));
	$EXECUTE selFechaActual INTO :FechaActual;
	
	memset(sMensMail,'\0', sizeof(sMensMail));
	sprintf( sMensMail, "Fecha de Proceso: %s<br>", FechaActual );
	if(strcmp(argv[1],"M")==0){
		sprintf( sMensMail, "%sNovedades Monetarias<br>", sMensMail );		
	}else{
		sprintf( sMensMail, "%sNovedades No Monetarias<br>", sMensMail );		
	}
	if(strcmp(argv[2],"R")==0){
		sprintf( sMensMail, "%sRegeneracion<br>", sMensMail );
		sprintf(sMensMail,"%sOficina:%s<br>",sMensMail, argv[3]);
		sprintf(sMensMail,"%sF.Desde:%s|F.Hasta:%s<br>",sMensMail, argv[4], argv[5]);
	}else{
		sprintf( sMensMail, "%sGeneracion<br>", sMensMail );
	}		
	
}
*/


char *strReplace(sCadena, cFind, cRemp)
char sCadena[1000];
char cFind[2];
char cRemp[2];
{
	char sNvaCadena[1000];
	int lLargo;
	int lPos;
	int dPos=0;
	
	lLargo=strlen(sCadena);

	for(lPos=0; lPos<lLargo; lPos++){

		if(sCadena[lPos]!= cFind[0]){
			sNvaCadena[dPos]=sCadena[lPos];
			dPos++;
		}else{
			if(strcmp(cRemp, "")!=0){
				sNvaCadena[dPos]=cRemp[0];	
				dPos++;
			}
		}
	}
	
	sNvaCadena[dPos]='\0';

	return sNvaCadena;
}

