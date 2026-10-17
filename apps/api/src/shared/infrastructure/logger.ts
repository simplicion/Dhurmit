// shared/infrastructure/logger.ts
// Structured JSON logging without leaking sensitive financial amounts or auth credentials.

export interface LogPayload {
  level: 'debug' | 'info' | 'warn' | 'error';
  message: string;
  timestamp: string;
  requestId?: string;
  route?: string;
  method?: string;
  statusCode?: number;
  durationMs?: number;
  actorId?: string;
  errorCode?: string;
  [key: string]: unknown;
}

class Logger {
  info(message: string, context?: Record<string, unknown>): void {
    this.log('info', message, context);
  }

  warn(message: string, context?: Record<string, unknown>): void {
    this.log('warn', message, context);
  }

  error(message: string, context?: Record<string, unknown>): void {
    this.log('error', message, context);
  }

  debug(message: string, context?: Record<string, unknown>): void {
    if (process.env['LOG_LEVEL'] === 'debug') {
      this.log('debug', message, context);
    }
  }

  private log(level: LogPayload['level'], message: string, context?: Record<string, unknown>): void {
    const payload: LogPayload = {
      timestamp: new Date().toISOString(),
      level,
      message,
      ...this.sanitize(context),
    };
    if (level === 'error') {
      console.error(JSON.stringify(payload));
    } else {
      console.log(JSON.stringify(payload));
    }
  }

  private sanitize(context?: Record<string, unknown>): Record<string, unknown> {
    if (!context) return {};
    const sanitized = { ...context };
    const sensitiveKeys = ['password', 'token', 'authorization', 'secret', 'passwordHash', 'jwt'];
    for (const key of Object.keys(sanitized)) {
      if (sensitiveKeys.some((s) => key.toLowerCase().includes(s))) {
        sanitized[key] = '[REDACTED]';
      }
    }
    return sanitized;
  }
}

export const logger = new Logger();
