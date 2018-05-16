package servicios;

import java.util.Collection;
import java.util.Vector;
import java.io.*;
import entidades.*;
import dao.*;


public class MoveInSRV {

	public Boolean GenMoveIn() {
		ClientesDAO miDAO = new ClientesDAO();
		Collection<MoveInDTO> miLista = null;
		
		FileWriter iArchivo=null;
		PrintWriter pw = null;
		
		try {
			System.out.println("Abriendo Achivo..");
			iArchivo = new FileWriter("C:\\Users\\ar17031095.ENELINT\\Documents\\SAP\\move_in.txt");
			pw = new PrintWriter(iArchivo);
			
			
			System.out.println("Cargando Lista");
			
			miLista = miDAO.getLstMoveIn("0003");
			System.out.println("Generando Plano");
			
			for(MoveInDTO fila : miLista) {
				GenerarPlano(fila, pw);
				
			}
			
		}catch(Exception e) {
			e.printStackTrace();
		}finally {
			try {
				if(iArchivo != null) {
					iArchivo.close();
				}
			}catch(Exception e2) {
				e2.printStackTrace();
			}
		}
		
		return true;
	}
	
	private void GenerarPlano(MoveInDTO fila, PrintWriter p) {
		
		//GeneraEverd(fila, p);
		GeneraEnde(fila, p);
		
	}
	
	private void GeneraEverd(MoveInDTO fila, PrintWriter p) {
		
	}
	
	
	private void GeneraEnde(MoveInDTO fila, PrintWriter p) {
		String sLinea;
		
		sLinea = String.format("T1%d\t&ENDE", fila.nroCliente);
		
		p.println(sLinea);
		
	}
}
