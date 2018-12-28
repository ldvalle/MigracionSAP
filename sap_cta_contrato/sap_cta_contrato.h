$ifndef SAPCTACONTRATO_H;
$define SAPCTACONTRATO_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/** Estructuras ****/

$typedef struct{
	long	numero_cliente;
	char	tipo_cliente[3];
	char	tipo_fpago[2];
	long	minist_repart;
	char	tipo_vencimiento[11];
	char  tipo_iva[4];
	char  tipo_reparto[7];
	char  cod_provincia[11];
	char  comuna[4];
	char	estado_cliente[2];
	char	sCodCorpoT23[9];
	char	sCodCorpoPadreT23[9];
	char	sTipoRepartoSAP[2];
	char	sFacturaDigital[2];
	char	sCategoCuenta[3];
	char	sTipoSum[3];
   char  sTipoDebito[2];
   char  sEstadoCobrabilidad[11];
   char  tiene_corte_rest[2];
   char  tiene_cobro_int[2];
   char  sTipoEntidadDebito[2];
   char  sCodSucurSap[5];
   char  sElectrodependiente[2];
}ClsCliente;

$typedef struct{
   long     numero_cliente;
   char     cod_cargo[4];
   double   porc;
   char     sFechaDesde[9];
   char     sFechaHasta[9];
   double   porc_sap;
   char     MWSKZ[3];
   char     KSCHL[5];
   double   EXRAT;
}ClsExencion;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
short	AbreArchivos(void);
long  getCorrelativo(char *);
void	CierroArchivos(void);

void	MensajeParametros(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
short	EnviarMail( char *, char *);
void  ArmaMensajeMail(char **);

short LeoCorpoT1(ClsCliente *);

short LeoClientes(ClsCliente *);
void  InicializaCliente(ClsCliente *);
short LeoExencion(ClsExencion *);
void  InicializaExencion(ClsExencion *);

short	ClienteYaMigrado(long, int*);
short	CorporativoT23(ClsCliente *);
short	GenerarPlanoT1(FILE *, ClsCliente, int);
short	GenerarPlanoT23(FILE *, ClsCliente);

short	RegistraCliente(ClsCliente, char *,  int);

short	LeoCorpoPropio(ClsCliente *);
short	RegistraArchivo(char*, char *, long);
void	AdministraPlanos(void);

char  *getTipoDebito(long);
char  *getTipoEntidad(long);
short getPorcentajeExe(ClsExencion *, int);
short LeoIndiIva(ClsExencion *);

static char 	*strReplace(char *, char *, char *);

void	GeneraINIT(FILE *, ClsCliente, char*, int);
void	GeneraVK(FILE *, ClsCliente, int);
void	GeneraVKP(FILE *, ClsCliente, char*, int);
void  GeneraVKLOCK(FILE *, ClsCliente, char*, int, char *);
void 	ProcesaVKTXEX(FILE *, ClsCliente, ClsExencion, int);
void 	GeneraVKTXEX(FILE *, ClsCliente, ClsExencion, int);
void	GeneraENDE(FILE *, ClsCliente, int);

void 	FormateaArchivos(void);

$endif;
