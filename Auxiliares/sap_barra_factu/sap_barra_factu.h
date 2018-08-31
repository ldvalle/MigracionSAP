$ifndef SAPBARRAFACTU_H;
$define SAPBARRAFACTU_H;

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
   long  numero_cliente; 
   int   corr_facturacion;
   long  numero_factura;
   char  sucursal[5];
   int   sector;
   int   zona;
   long  fecha_facturacion;
   char  fecha_vencimiento1[7];
   char  fecha_vencimiento2[5];
   double   total_a_pagar;
   double   saldo_anterior;
   char  centro_emisor[3];
   char  tipo_docto[3];
   
   char  tipo_nota[3];
   double recargo;
}ClsFactu;
   

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
void  CreaPrepare(void);

short LeoFacturas(ClsFactu *);
void  InicializaFacturas(ClsFactu *);
char  *getBarra(ClsFactu);
short setBarra(ClsFactu, char*);

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
