$ifndef SAPPARTNER_H;
$define SAPPARTNER_H;

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
	char	tipo_reparto[7];
   char  sAccount[21];
}ClsCliente;

$typedef struct{
	char	email1[51];
	char	email2[51];
	char	email3[51];
}ClsEmail;

$typedef struct{
	char	tipo_te[3];
	char	cod_area_te[6];
	char	prefijo_te[3];
	char    numero_te[15];
	char	ppal_te[2];
}ClsTelefonos;

$typedef struct{
	char	fp_banco[7];
	char	fp_tipocuenta[7];
	char	fp_nrocuenta[21];
	int		fp_sucursal;
	long	fecha_activacion;
	long	fecha_desactivac;
	char	fp_cbu[23];
	char	cod_tarjeta[11];
}ClsFormaPago;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
void  	CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
long    getCorrelativo(void);
short   LeoClientes(ClsCliente *, ClsFormaPago *);
short   LeoHijos(ClsCliente *, ClsFormaPago *);
void    InicializaCliente(ClsCliente *, ClsFormaPago *);
short	CargaTelefonos(ClsCliente, ClsTelefonos**, int *);
void    InicializaTelefonos(ClsTelefonos*);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
short	GenerarPlano(FILE *, ClsCliente, ClsFormaPago, ClsTelefonos*, ClsEmail, int, int, int);
char	*getTipoDD(char*, int *);
int		getTipoPersona(char*);
void	GeneraINIT(FILE *, ClsCliente);
void	GeneraBUT000(FILE *, ClsCliente);
void	GeneraBUT0ID(FILE *, ClsCliente);
void    GeneraBUTCOM(FILE *, ClsCliente, ClsTelefonos*, ClsEmail, int, int);
void 	GeneraBUT020(FILE *, ClsCliente, ClsEmail, long, int);
void	GeneraBUT0BK(FILE *, ClsCliente, ClsFormaPago);
void	GeneraBUT0CC(FILE *, ClsCliente, ClsFormaPago);
void	GeneraTAXNUM(FILE *, ClsCliente);
void	GeneraENDE(FILE *, ClsCliente);
short   LeoTelefonos(ClsTelefonos*);
short	ClienteYaMigrado(long, int, int*);
short	RegistraCliente(long, int);
short	RegistraCorpoT1(long);
short	BorraCorpoT1(void);
short	CorporativoT23(long);
short	LeoCorpoPropio(ClsCliente *, ClsFormaPago *);
short	RegistraArchivo(char*, long);
static char 	*strReplace(char *, char *, char *);
char    *getCodTarjeta(char*);
short CargaIdSF(ClsCliente *);

$endif;
