// shared/domain/errors.ts
// Standard application and domain error codes matching architecture specs.

export type ErrorCode =
  | 'VALIDATION_ERROR'
  | 'UNAUTHENTICATED'
  | 'FORBIDDEN'
  | 'NOT_FOUND'
  | 'CONFLICT'
  | 'IDEMPOTENCY_KEY_REUSED'
  | 'ALLOCATION_REQUIRED'
  | 'ALLOCATION_EXCEEDS_COLLECTION'
  | 'OVERPAYMENT_NOT_ALLOWED'
  | 'PARTIAL_PAYMENT_NOT_ALLOWED'
  | 'SCHEDULE_CHANGE_REQUIRES_PREVIEW'
  | 'INTERNAL_ERROR';

export interface ValidationErrorDetail {
  field: string;
  issue: string;
}

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly statusCode: number;
  readonly details?: ValidationErrorDetail[];

  constructor(
    code: ErrorCode,
    message: string,
    statusCode: number = 400,
    details?: ValidationErrorDetail[]
  ) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.statusCode = statusCode;
    this.details = details;
    Object.setPrototypeOf(this, new.target.prototype);
  }
}

export class DomainError extends AppError {
  constructor(code: ErrorCode, message: string, details?: ValidationErrorDetail[]) {
    super(code, message, 422, details);
    this.name = 'DomainError';
  }
}

export class NotFoundError extends AppError {
  constructor(message: string = 'Resource not found') {
    super('NOT_FOUND', message, 404);
    this.name = 'NotFoundError';
  }
}

export class ForbiddenError extends AppError {
  constructor(message: string = 'Permission denied for this workspace or resource') {
    super('FORBIDDEN', message, 403);
    this.name = 'ForbiddenError';
  }
}

export class UnauthenticatedError extends AppError {
  constructor(message: string = 'Authentication required') {
    super('UNAUTHENTICATED', message, 401);
    this.name = 'UnauthenticatedError';
  }
}

export class ConflictError extends AppError {
  constructor(message: string) {
    super('CONFLICT', message, 409);
    this.name = 'ConflictError';
  }
}

export class IdempotencyConflictError extends AppError {
  constructor(message: string = 'Idempotency key reused with different request payload') {
    super('IDEMPOTENCY_KEY_REUSED', message, 409);
    this.name = 'IdempotencyConflictError';
  }
}
