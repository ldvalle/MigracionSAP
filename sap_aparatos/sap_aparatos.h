$ifndef SAPAPARATOS_H;
$define SAPAPARATOS_H;

#include "ustring.h"
#include "macmath.h"

$include sqltypes.h;
$include sqlerror.h;
$include datetime.h;

#define BORRAR(x)       memset(&x, 0, sizeof x)
#define BORRA_STR(str)  memset(str, 0, sizeof str)

#define SYN_CLAVE "DD_NOVOUT"

/* Estructuras ---*/

$typedef struct{
	char	marca[4];
	char	modelo[3];
	long	numero;
	char	med_ubic[4]; 
	char	med_codubic[11];
	long	numero_cliente;
	int		med_anio;
	char	fabricante[31];
	char	mat_codigo[11];
	char	emplazamiento[5];
	char	gp_numeradores[9];
	char	tipo_medidor[2];
	
	char	med_precinto1[8];
	char	med_precinto2[8];
	char	med_clase[6];
	char	med_fase[4];
}ClsMedidor;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);

short   LeoMedidores(ClsMedidor *);
void    InicializaMedidor(ClsMedidor *);
short	CargaEmplazamiento(ClsMedidor *);
short	GenerarPlano(FILE *, ClsMedidor);
void	GeneraVEQUI(FILE *, ClsMedidor);
void    GeneraEGERS(FILE *, ClsMedidor);
void	GeneraEGERH(FILE *, ClsMedidor);
void	GeneraENDE(FILE *, ClsMedidor);

short	GenerarPlanoExt(FILE *, ClsMedidor);
void	GeneraEQUI(FILE *, ClsMedidor);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
char	*getEmplazaSAP(char*);
char	*getEmplazaT23(char*);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
