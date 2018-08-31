$ifndef SAPINSTPLAN_H;
$define SAPINSTPLAN_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* Estructuras **/

$typedef struct{
   long     numero_cliente; 
   int      corr_convenio; 
   double   deuda_origen;
   double   saldo_origen;
   double   deuda_convenida;
   int      numero_tot_cuotas;
   int      numero_ult_cuota;
   double   valor_cuota;
   double   valor_cuota_ini;
   long     lFechaVigencia;
   char     sFechaVigencia[9];
}ClsConve;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long  getCorrelativo(char*);

short LeoConve(ClsConve *);
void  InicializaConve(ClsConve *);
int   getFica(long);

/*
short CargaAltaCliente(ClsDepgar *);
*/
short	GenerarPlano(FILE *, int, ClsConve);
void	GeneraIPKEY(FILE *, ClsConve);
void  GeneraIPDATA(FILE *, int, int, double, ClsConve);
void	GeneraIPOPKY(FILE *, int, ClsConve);
void	GeneraENDE(FILE *, ClsConve);
/*
short   LeoInstalacion(ClsInstalacion *);
void    InicializaInstalacion(ClsInstalacion *);
short	CargaCambioTarifa(ClsInstalacion *);
*/


short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

short	ClienteYaMigrado(long, int*);
short	RegistraCliente(long, int);

char	*getFechaFactura(long, long);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
