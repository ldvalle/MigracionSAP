$ifndef SAPDOCFICA_H;
$define SAPDOCFICA_H;

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
   long     numero_cliente;
   char     cdc[11];
   char     tipo_iva[11];
   int      corr_convenio;
   char     estado_cobrabilida[2];
   char     tiene_convenio[2];
   char     tiene_cnr[2];
   char     tiene_cobro_int[2];
   char     tiene_cobro_rec[2];
   double   saldo_actual;
   double   saldo_int_acum;
   double   saldo_imp_no_suj_i;
   double   saldo_imp_suj_int;
   double   valor_anticipo;
   int      antiguedad_saldo;
   char     sucur_sap[11];
   char     sFechaVigTarifa[11];
   int      corr_facturacion;
   char     sFechaUltFactura[11];
}ClsCliente;

$typedef struct{
   char     codigo_impuesto[4]; 
   char     descripcion[31]; 
   double   saldo; 
   char     ind_afecto_int[2];
   char     hvorg[5]; 
   char     hkont[11]; 
   char     tvorg[5]; 
   char     optxt[61];
}ClsImpuesto;


/********* estructuras del objeto *********/
typedef struct{
   char  nroCliente[10];
   char  BUKRS[5];
   char  GSBER[5];
   char  GPART[11];
   char  VTREF[21];
   char  VKONT[13];
   char  HVORG[5];
   char  TVORG[5];
   char  KOFIZ[3];
   char  SPART[3];
   char  HKONT[11];
   char  MWSKZ[3];
   char  XANZA[2];
   char  STAKZ[2];
   char  BUDAT[11];
   char  OPTXT[61];
   char  FAEDN[11];
   char  BETRW[20];
   char  SBETW[20];
   char  AUGRS[2];
   char  SPERZ[2];
   char  BLART[3];
   char  FINRE[13];
   char  PSWBT[15];
   char  SEGMENT[11];
}ClsOP;

typedef struct{
   char  nroCliente[10];
   char  BUKRS[5];
   char  HKONT[11];
   char  PRCTR[11];
   char  KOSTL[11];
   char  BETRW[20];
   char  MWSKZ[3];
   char  SBASH[20];
   char  SBASW[20];
   char  KTOSL[4];
   char  STPRZ[8];
   char  KSCHL[5];
   char  SEGMENT[11];
}ClsOPK;

typedef struct{
   char  OPUPK[5];
   char  PROID[3];
   char  LOCKR[2];
   char  FDATE[11];
   char  TDATE[11];
}ClsOPL;

$typedef struct{
   char  tipo_saldo[4];
   int   corr_facturacion;
   long  fecha_vencimiento1;
   char  cod_cargo[4];
   double   valor_cargo;
   char  hvorg[5];
   char  hkont[11];
   char  tvorg[5];
   char  optxt[61];
}ClsAgeing;

$typedef struct{
   double   saldo_actual;
   double   saldo_int_acum;
   double   saldo_imp_no_suj_i;
   double   saldo_imp_suj_int;
}ClsConve;

$typedef struct{
   long  nro_saldo_disputa; 
   char  ndocum_enre[31]; 
   long  reclamo; 
   double   monto_disputa; 
   double   saldo_actual; 
   double   saldo_int_acum; 
   double   saldo_imp_no_suj_i; 
   double   saldo_imp_suj_int; 
   long     fecha_autoriza;
}ClsDisputa;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(char*);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long  getCorrelativo(char*);

double   getSaldoGral(ClsCliente);
short LeoCliente(ClsCliente * );
void  InicializaCliente(ClsCliente *);
short LeoImpuestos(ClsImpuesto *, long);
void  InicializaImpuesto(ClsImpuesto *);

void  ProcesaAgeing(ClsCliente);
short LeoAgeing(ClsAgeing *);
void  InicializaAgeing(ClsAgeing *);
void  CopiaClienteAgeToOp(ClsCliente, ClsAgeing, ClsOP *);

void  ProcesaConvenios(ClsCliente, char*);
short LeoConvenio(ClsConve *);
void  InicializaConvenio(ClsConve *);

void  ProcesaDisputa(ClsCliente, char*);
short LeoDisputa(ClsDisputa *);
void  InicializaDisputa(ClsDisputa *);

short LeoImpuDispu(ClsImpuesto *);
short LeoImpuConve(ClsImpuesto *);

void  inicializaOPL(ClsOPL **);
void  CargaOPL(ClsCliente, long, ClsOPL **, char *);

void  InicializaOP( ClsOP *);
void  InicializaOPK(ClsOPK *);
void  GeneraSaldoCliente(FILE *, ClsCliente);
void  GenerarPlanos(ClsCliente);
void  GenerarKO(FILE*, ClsCliente, int);
void  GenerarOP(FILE*, ClsOP, int, char*, int);
void  GenerarOPK(FILE*, ClsOPK, int, char*);
void  GenerarOPL(FILE*, ClsCliente, ClsOPL *, char*, int);
void  GeneraENDE(FILE *, ClsCliente, int);

void CopiaClienteToOp(ClsCliente, ClsOP *);
void CopiaClienteToOpk(ClsCliente, double, ClsOPK *);
void CopiaImpuToOp(ClsCliente, ClsImpuesto, ClsOP *);



short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

short	ClienteYaMigrado(long, long*, int*);
short	RegistraCliente(long, int);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
