$ifndef SAPMOVEOUT_H;
$define SAPMOVEOUT_H;

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
	char	clase_tarifa[20];
	char	tipo_cliente[4];
	char	sucursal_sap[5];
	char	fecha_alta[9];
	char	fecha_baja[9];
	long	lFechaBaja;
	char	proced[21];
	char	fecha_retiro[9];
	long	nro_beneficiario;
	char	fecha_alta_sistema[9];
}ClsBajas;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);

short   LeoBajas(ClsBajas *);
void    InicializaBajas(ClsBajas *);

short	GenerarPlanoBajas(FILE *, ClsBajas);
void	GeneraEAUSD(FILE *, ClsBajas);
void	GeneraEAUSVD(FILE *, ClsBajas);
void	GeneraENDE(FILE *, ClsBajas);

short	GenerarPlanoAltas(FILE *, ClsBajas);
void	GeneraEVERD(FILE *, ClsBajas);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);
short	ClienteYaMigrado(long, int*);
short	RegistraCliente(long, int);

/**
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
