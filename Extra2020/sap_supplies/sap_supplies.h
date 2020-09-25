$ifndef SAPSUPPLIES_H;
$define SAPSUPPLIES_H;

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
	long	numero_cliente;
   char  razonSocial[50];
	char	nombre[50];
   char  apellido[50];
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
	char  numero_te[15];
	char	ppal_te[2];
}ClsTelefonos;

$typedef struct{
	char	fp_banco[7];
	char	fp_tipocuenta[7];
	char	fp_nrocuenta[21];
	int	fp_sucursal;
	long	fecha_activacion;
	long	fecha_desactivac;
	char	fp_cbu[23];
	char	cod_tarjeta[11];
}ClsFormaPago;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long  getCorrelativo(char*);

short LeoDepgar(ClsDepgar *);
void  InicializaDepgar(ClsDepgar *);

short CargaAltaCliente(ClsDepgar *);

short	GenerarPlano(FILE *, ClsDepgar);
void	GeneraSEC_D(FILE *, ClsDepgar);
void	GeneraSEC_C(FILE *, ClsDepgar);
void	GeneraENDE(FILE *, ClsDepgar);
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
