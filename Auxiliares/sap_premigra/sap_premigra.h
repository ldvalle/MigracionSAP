$ifndef SAPPREMIGRA_H;
$define SAPPREMIGRA_H;

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
	long numero_cliente;
	char sucursal[5]; 
	int  sector;
	char tarifa[4];
	int  tipo_sum;
	int  corr_facturacion;
	char provincia[4];
	char partido[4];
	char comuna[4];
	char tipo_iva[4];
	char tipo_cliente[3];
	char actividad_economic[5];
	char sNroBeneficiario[17];
}ClsCliente;

$typedef struct{
	long numero_cliente;
	long lFechaValTar;
	long lFechaAlta;
	long lFechaMoveIn;
	long lFechaPivote;
	char sTarifa[11];
	char sUL[11];
	char sMotivoAlta[4];
}ClsEstado;
   

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
void  CreaPrepare(void);

short LeoCliente(ClsCliente *);
void  InicializaCliente(ClsCliente *);
void  InicializaEstado(ClsEstado *);

long  getValTar(ClsCliente);
long  getAlta(ClsCliente);
long  getMoveIn(ClsCliente, long);
void  CargaEstados(ClsCliente, ClsEstado *);
short GrabaEstados(ClsEstado);

/*
short   LeoInstalacion(ClsInstalacion *);
void    InicializaInstalacion(ClsInstalacion *);
short	CargaCambioTarifa(ClsInstalacion *);
*/


char 	*strReplace(char *, char *, char *);


/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
