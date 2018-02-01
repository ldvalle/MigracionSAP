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
}ClsCliente;


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

void  GenerarPlanos(ClsCliente);
void  GenerarKO(ClsCliente);
void  GenerarOP(ClsCliente, int, char *);
void  GenerarOPK(ClsCliente, int, double);
void  GenerarOPL(ClsCliente);
void  GeneraENDE(ClsCliente);

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
