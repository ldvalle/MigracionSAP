$ifndef SAPOBJCONEXION_H;
$define SAPOBJCONEXION_H;

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
	char	nombre[41];
	char 	tipo_cliente[3];
	char	actividad_economic[5];

	char	cod_calle[7];
	char	nom_calle[36];
	char	nro_dir[6];
	char	piso_dir[7];
	char	depto_dir[7];
	char	nom_entre[26];
	char	nom_entre1[26];
	char	provincia[4];
	char	partido[4];
	char	nom_partido[26];
	char	comuna[4];
	char	nom_comuna[26];
	int	cod_postal;
	char	obs_dir[61];
	
	char	telefono[10];
	char	rut[12];
	char	tip_doc[7];
	double	nro_doc;
	char	tipo_fpago[2];
	long	minist_repart;
	char	estado_cliente[2];
	char	tipo_sum[3];
	char	sucursal[5];
	char	info_adic_lectura[25];
	char	descrip_info_adic[41];
   
   char  comuna_caba[101];
}ClsCliente;


/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long    getCorrelativo(char*);
short   LeoClientes(ClsCliente *);
void    InicializaCliente(ClsCliente *);
short	ClienteYaMigrado(char*, long, int*);
short	RegistraCliente(char*, long, int);
short	RegistraArchivo(void);
static char 	*strReplace(char *, char *, char *);
void	GeneraENDE(FILE *, ClsCliente);
int		getTipoPersona(char*);
void	CerrarArchivos(void);
void	FormateaArchivos(void);
short	GenerarPlanoObjConex(FILE *, ClsCliente);
short	GenerarPlanoPtoSumin(FILE *, ClsCliente);
short	GenerarPlanoUbicApa(FILE *, ClsCliente);
void	GeneraCO_EHA(FILE *, ClsCliente);
void	GeneraCO_ADR(FILE *, ClsCliente);
void	GeneraEVBSD(FILE *, ClsCliente);
void	GeneraEGPLD(FILE *, ClsCliente);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
void    InicializaEmail(ClsEmail*);
*/

$endif;
