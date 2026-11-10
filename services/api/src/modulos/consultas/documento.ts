const PESOS_RUC = [5, 4, 3, 2, 7, 6, 5, 4, 3, 2];

export function rucValido(ruc: string): boolean {
  if (!/^(10|15|16|17|20)\d{9}$/.test(ruc)) return false;
  const suma = PESOS_RUC.reduce((acumulado, peso, indice) => acumulado + Number(ruc[indice]) * peso, 0);
  const resto = 11 - (suma % 11);
  const digito = resto === 10 ? 0 : resto === 11 ? 1 : resto;
  return digito === Number(ruc[10]);
}

export const dniValido = (dni: string): boolean => /^\d{8}$/.test(dni);
