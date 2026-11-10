export class ErrorReintentable extends Error {
  constructor(
    mensaje: string,
    readonly esperaBaseMs?: number,
  ) {
    super(mensaje);
    this.name = 'ErrorReintentable';
  }
}

export class ErrorDefinitivo extends Error {
  constructor(mensaje: string) {
    super(mensaje);
    this.name = 'ErrorDefinitivo';
  }
}
