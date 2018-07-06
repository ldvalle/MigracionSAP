$ifndef SAPDISCDOC_H;
$define SAPDISCDOC_H;

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
   char  fecha_corte[9]; 
   char  motivo_corte[3]; 
   char  accion_corte[3]; 
   char  funcionario_corte[9]; 
   char  fecha_ini_evento[9]; 
   char  sit_encon[3];
}ClsCorte;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	RutaArchivos( char*, char * );

short   LeoCortes(ClsCorte *);
void    InicializaCorte(ClsCorte *);

short	GenerarPlano(FILE *, ClsCorte);
void	GeneraHEADER(FILE *, ClsCorte);
void	GeneraFKKMAZ(FILE *, ClsCorte);
void	GeneraENDE(FILE *, ClsCorte);


char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
