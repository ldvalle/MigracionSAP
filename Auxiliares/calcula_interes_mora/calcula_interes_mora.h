EXEC SQL ifndef CALCULA_INTERES_MORA;
EXEC SQL define CALCULA_INTERES_MORA;

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ustring.h>
#include <macmath.h>
#include <unistd.h>
#include <errno.h>
#include <time.h>
#include "sqlerror.h"
$include hisfac_cont.h;
$include cliente.h;
$include hisfac.h;
$include datos_gen.h;
$include calc_inter.h;
$include errores.h;
$include rec_tot_nd_nc.h;
$include recu_val.h;
$include fecha.h;   
$include val_tar2.h;
$include conc_calc.h;
$include sqltypes ;

#define TRACE { printf("TRACE - archivo %s   funcion %s   linea %d\n", __FILE__, __FUNCTION__, __LINE__); }

#define max(a,b)  (((a) > (b)) ? (a) : (b))

#define ERROR                           0
#define OK                              1
#define CANTIDAD_PARAMETROS             3
/*
EXEC SQL WHENEVER ERROR CALL SqlError;
*/
EXEC SQL WHENEVER SQLERROR CALL SqlException ;
EXEC SQL ifdef DEBUG ;
    EXEC SQL WHENEVER SQLWARNING CALL SqlException ;
EXEC SQL endif ;


EXEC SQL BEGIN DECLARE SECTION;
    /*DATETIME YEAR TO SECOND dtHoraIniProc;*/
    char           sBaseSynergia[50];
    char           sSucursal[5];
    long           lFechaFacturacion;
EXEC SQL END DECLARE SECTION;

FILE *fEvenCalInt = NULL;


int  ValidarParametros(int, char **);
int  IniciaAmbiente(void);
void TerminaAmbiente(int);
int  FetchHisfacContTemp(ThisfacCont *, Tcliente *, Thisfac *);
int  AbreArchivo(char *, FILE **, char *);
void PreparaQuerys(void);
short GrabaInteres(long, long, double);
EXEC SQL endif;
