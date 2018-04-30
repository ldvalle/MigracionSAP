$ifndef SAPINSTALACION_H;
$define SAPINSTALACION_H;

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
	char  cod_ul[9];
	char	estado_cliente[2];
	char	codigo_voltaje[3];
	char	catego_electrodependiente[7];
	char  fecha_vig_tarifa[9];
	char	tarifa[20];
	char	actividad_economic[5];
	char	fecha_instalacion[9];
	char	cod_porcion[9];
	long	nro_beneficiario;
	long	corr_facturacion;

	char	nro_subestacion[7];
	char	tec_nom_subest[26];
	char	tec_alimentador[12];
	char	tec_centro_trans[21];
	char	tec_fase[2];
	int	tec_acometida;
	char	tec_tipo_instala[21];
	char	tec_nom_calle[26];
	char	tec_nro_dir[6];
	char	tec_piso_dir[7];
	char	tec_depto_dir[7];
	char	tec_entre_calle1[26];
	char	tec_entre_calle2[26];
	char	tec_manzana[6];
	char	tec_barrio[26];
	char	tec_localidad[26];
	char	tec_partido[26];
	char	tec_sucursal[26];
	double	ubi_x;
	double	ubi_y;
	double	ubi_lat;
	double	ubi_long;
	double	potencia_inst_fp;

	char	tipo_obra[5];
	char	toma[5];

	char	tipo_conexion[7];
	char	acometida[2];
	int		cantidad_medidores;

	char	fase_neutro[6];
	char	neutro_metal[6];
   
   char  sFechaAltaReal[9];
   char  sPod[21];
	long  correlativo_ruta;
}ClsInstalacion;

$typedef struct{
	long	lFecha;
	char	tarifa[4];
	char	fecha_facturacion[9];	
}ClsHisfac;

/* Prototipos de Funciones */
short	AnalizarParametros(int, char **);
void	MensajeParametros(void);
short	AbreArchivos(void);
void  CreaPrepare(void);
void 	FechaGeneracionFormateada( char *);
void 	RutaArchivos( char*, char * );
long   getCorrelativo(char*);

short   LeoInstalacion(ClsInstalacion *);
void    InicializaInstalacion(ClsInstalacion *);
short	CargaCambioTarifa(ClsInstalacion *);
short   CargaAltaCliente(ClsInstalacion *);
short   CargaAltaCliente2(ClsInstalacion *);

short	GenerarPlano(FILE *, ClsInstalacion);
void	GeneraKEY(FILE *, ClsInstalacion);
void	GeneraDATA(FILE *, ClsInstalacion);
void	GeneraENDE(FILE *, ClsInstalacion);

short	RegistraArchivo(void);
char 	*strReplace(char *, char *, char *);
void	CerrarArchivos(void);
void	FormateaArchivos(void);

short	ClienteYaMigrado(long, int*);
short	RegistraCliente(long, char *, long, char *, int);
char	*getFechaFactura(long, long);

short CargaAltaReal(ClsInstalacion *);
short CargaIdSF(ClsInstalacion *);
void  CargaLimiteInferior(void);
short CargaTarifaInstal(ClsInstalacion *);

/*
short	EnviarMail( char *, char *);
void  	ArmaMensajeMail(char **);
short	CargaEmail(ClsCliente, ClsEmail*, int *);
void    InicializaEmail(ClsEmail*);
*/

$endif;
