import { entorno } from '../config/entorno.js';
import { crearLlamadaGateway } from './cliente.js';

export const llamarGateway = crearLlamadaGateway({ url: entorno.SUNAT_GATEWAY_URL, token: entorno.SUNAT_GATEWAY_TOKEN });
