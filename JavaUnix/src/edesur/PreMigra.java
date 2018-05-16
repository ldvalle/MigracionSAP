package edesur;

import servicios.ClienteSRV;
import java.util.Collection;
import java.util.Date;
import java.text.SimpleDateFormat;

public class PreMigra {

	public static void main(String[] args) {
		Boolean iVal;
		Date dIni = new Date();
		
		SimpleDateFormat sdf = new SimpleDateFormat("dd-MM-yyyy h:mm a");
		
		System.out.println("Pre Proceso de Migracion SYNERGIA");

		ClienteSRV miSrv = new ClienteSRV();
		
		//iVal=miSrv.procClientes();
		iVal=miSrv.procClientes2();

		Date dFin = new Date();

		System.out.println("Fecha Inicio " + sdf.format(dIni));
		System.out.println("Fecha Final " + sdf.format(dFin));
		
	}

}
