package ppal;

//import javax.swing.*;
import entidades.ClienteDTO;
import dao.ClientesDAO;
import servicios.*;

public class startMuestreo {

	/**
	 * @param args
	 */
	public static void main(String[] args) {
		
		ClienteIndividual();

		//MoveIn();
	}

	
	private static void ClienteIndividual() {
		String sNroCliente;
		long lNroCliente;
		ClientesDAO miSrv = new ClientesDAO();
		ClienteDTO miReg = null;
/*		
		sNroCliente = JOptionPane.showInputDialog("Ingrese Nro.Cliente");
		lNroCliente=Long.parseLong(sNroCliente);
*/
		lNroCliente = 234567;
		miReg=miSrv.getCliente(lNroCliente);
		System.out.println("Sucursal Cliente:" + miReg.sucursal);
		//JOptionPane.showMessageDialog(null, "Sucursal Cliente " + miReg.sucursal);
		
	}
/*	
	private static void MoveIn() {
		servicios.MoveInSRV miSrv = new servicios.MoveInSRV();
		
		System.out.println("Procesando..");
		
		if( miSrv.GenMoveIn()) {
			JOptionPane.showMessageDialog(null,  "Termine");
		}else {
			JOptionPane.showMessageDialog(null,"FAllo");
		}
		
		
	}
*/	
}
