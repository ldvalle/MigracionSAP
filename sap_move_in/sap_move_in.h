$ifndef SAPMOVEIN_H;
$define SAPMOVEIN_H;

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
	long	numero_cliente; 
	char	tarifa[4];
	char	tipo_cliente[4];
	char	sucursal_sap[5];
	long	nro_beneficiario;
	long	corr_facturacion;
	char	fecha_alta[9];
	char	fecha_alta_sistema[9];
	char	sElectro[3];
	char	sCDC[21];
   char  sMotivoAlta[3];
   char  sAsset[21];
}ClsAltas;


/** Prototipos de Funciones **/
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);
short CargaAltaReal(ClsAltas *);
short   LeoAltas(ClsAltas *);
void    InicializaAltas(ClsAltas *);
short CargaAlta(ClsAltas *);

short	GenerarPlanoAltas(FILE *, ClsAltas);
void	GeneraEVER(FILE *, ClsAltas);
void	GeneraENDE(FILE *, ClsAltas);
short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);
short	ClienteYaMigrado(long, int*);
short	RegistraCliente(ClsAltas, int);
char	*getFechaFactura(long, long);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
