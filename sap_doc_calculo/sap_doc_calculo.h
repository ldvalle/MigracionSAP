$ifndef SAPDOCCALCULO_H;
$define SAPDOCCALCULO_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* Estructuras ***/
$typedef struct{
   long  numero_cliente;
   int   corr_facturacion;
   char  cod_portion[9];
   char  cod_ul[9];
   char  cdc[11];
   char  tipo_fpago[2];
   char  cod_agrupa[10];
   long  minist_repart;
}ClsCliente;


$typedef struct{
   long     numero_cliente;
   int      corr_facturacion;
   char     fecha_lectura[9];
   char     fecha_vencimiento[9];
   char     fecha_facturacion[9];
   long     lFechaFacturacion;
   char     centro_emisor[3];
   char     tipo_docto[3];
   long     numero_factura;
   char     tipo_tarifa[11];
   char     tipo_iva[11];
   double   consumo_sum;
   int      subtarifa;
   char     indica_refact[2];
   
   char     fecha_lectura_anterior[9];
   int      dias_periodo;
   double   consumo_normalizado;
   int      corr_refacturacion;
}ClsHisfac;

$typedef struct{
  char     codigo_cargo[4];
  double   valor_cargo;
  char     unidad[5]; 
  char     clase_pos_doc[10];
  char     contrapartida[10];
  char     cte_de_calculo[10];
  char     tipo_precio[10];
  char     tarifa[10];
  char     deriv_contable[10];
  double   precio_unitario;
  char     tipo_cargo_tarifa[2];  
}ClsDetalle;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(char*);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long  getCorrelativo(char*);

short LeoCliente(ClsCliente * );
void  InicializaCliente(ClsCliente *);
short CorporativoT23(ClsCliente *);
short CorporativoPropio(ClsCliente *);

short LeoFacturasCabe(ClsHisfac *);
void  InicializaFacturasCabe(ClsHisfac *);
short getFechaLectuAnterior(ClsHisfac *);
void  Calculos(ClsHisfac *);
short TraeRefacturada(ClsHisfac *);
short LeoFacturasDeta(ClsHisfac, ClsDetalle *, int);
void  InicializaDetalle(ClsDetalle *);
short getPrecioUnitario(ClsHisfac, ClsDetalle *);

void  GenerarCabecera(ClsCliente, ClsHisfac);
void  GenerarDetalle(ClsCliente, ClsHisfac, ClsDetalle, int);
void  GeneraENDE(ClsHisfac, ClsDetalle, int);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

short	ClienteYaMigrado(long, int*);
short	RegistraCliente(long, int);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
