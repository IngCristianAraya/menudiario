'use client'

import { useEffect } from 'react'
import { useSearchParams } from 'next/navigation'
import Link from 'next/link'

export default function ErrorPage() {
  const searchParams = useSearchParams()
  const error = searchParams?.get('error')
  
  // Mensajes de error personalizados
  const errorMessages: Record<string, string> = {
    'Configuration': 'Hay un problema con la configuración del servidor.',
    'AccessDenied': 'No tienes permiso para acceder a esta página.',
    'Verification': 'El enlace de verificación ha caducado o ya ha sido utilizado.',
    'Default': 'Ocurrió un error al intentar autenticarte.',
  }

  // Obtener el mensaje de error correspondiente
  const errorMessage = error && error in errorMessages 
    ? errorMessages[error as keyof typeof errorMessages]
    : errorMessages['Default']

  return (
    <div className="min-h-screen flex items-center justify-center bg-gray-50 py-12 px-4 sm:px-6 lg:px-8">
      <div className="max-w-md w-full space-y-8 text-center">
        <div>
          <h2 className="mt-6 text-center text-3xl font-extrabold text-gray-900">
            Error de autenticación
          </h2>
          <p className="mt-2 text-center text-gray-600">
            {errorMessage}
          </p>
          {error && (
            <p className="mt-4 p-3 bg-gray-100 rounded-md text-sm text-gray-700">
              Código de error: <span className="font-mono">{error}</span>
            </p>
          )}
        </div>

        <div className="mt-8 space-y-4">
          <Link
            href="/auth/login"
            className="w-full flex justify-center py-2 px-4 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 focus:outline-none focus:ring-2 focus:ring-offset-2 focus:ring-indigo-500"
          >
            Volver al inicio de sesión
          </Link>
          
          <p className="text-center text-sm text-gray-600">
            ¿Neitas ayuda?{' '}
            <a
              href="mailto:soporte@tudominio.com"
              className="font-medium text-indigo-600 hover:text-indigo-500"
            >
              Contáctanos
            </a>
          </p>
        </div>
      </div>
    </div>
  )
}
