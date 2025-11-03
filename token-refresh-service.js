/**
 * Token Refresh Service - Google Photos Style
 * Mantiene tokens frescos automáticamente durante uploads largos
 */

class TokenRefreshService {
    constructor() {
        this.refreshPromise = null;
        this.tokenExpiryBuffer = 5 * 60 * 1000; // 5 minutos antes de expirar
        this.apiBaseUrl = 'https://gslxbu791e.execute-api.us-east-1.amazonaws.com/dev';
    }

    /**
     * Obtiene token válido, renovándolo si es necesario
     */
    async getValidToken() {
        const currentToken = localStorage.getItem('accessToken');
        
        if (!currentToken) {
            throw new Error('No authentication token found');
        }

        // Verificar si el token está próximo a expirar
        if (this.isTokenExpiringSoon(currentToken)) {
            return await this.refreshToken();
        }

        return currentToken;
    }

    /**
     * Verifica si el token expira en los próximos 5 minutos
     */
    isTokenExpiringSoon(token) {
        try {
            const payload = JSON.parse(atob(token.split('.')[1]));
            const expiryTime = payload.exp * 1000;
            const now = Date.now();
            
            return (expiryTime - now) < this.tokenExpiryBuffer;
        } catch (error) {
            console.warn('Error parsing token:', error);
            return true; // Asumir que expira si no se puede parsear
        }
    }

    /**
     * Renueva el token usando refresh token
     */
    async refreshToken() {
        // Evitar múltiples refreshes simultáneos
        if (this.refreshPromise) {
            return await this.refreshPromise;
        }

        this.refreshPromise = this.performTokenRefresh();
        
        try {
            const newToken = await this.refreshPromise;
            this.refreshPromise = null;
            return newToken;
        } catch (error) {
            this.refreshPromise = null;
            throw error;
        }
    }

    /**
     * Ejecuta el refresh del token
     */
    async performTokenRefresh() {
        const refreshToken = localStorage.getItem('refreshToken');
        
        if (!refreshToken) {
            throw new Error('No refresh token available');
        }

        try {
            const response = await fetch(`${this.apiBaseUrl}/auth/refresh`, {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    refreshToken: refreshToken
                })
            });

            if (!response.ok) {
                throw new Error(`Token refresh failed: ${response.status}`);
            }

            const data = await response.json();
            
            if (!data.success) {
                throw new Error(data.message || 'Token refresh failed');
            }
            
            // Actualizar tokens en localStorage
            localStorage.setItem('accessToken', data.data.access_token);
            localStorage.setItem('idToken', data.data.id_token);

            console.log('✅ Token refreshed successfully');
            return data.data.access_token;
            
        } catch (error) {
            console.error('❌ Token refresh error:', error);
            // Redirigir a login si el refresh falla
            this.handleRefreshFailure();
            throw error;
        }
    }

    /**
     * Maneja fallos de refresh redirigiendo a login
     */
    handleRefreshFailure() {
        localStorage.removeItem('accessToken');
        localStorage.removeItem('refreshToken');
        localStorage.removeItem('idToken');
        window.location.href = '/login';
    }

    /**
     * Wrapper para requests con token automático - Google Photos style
     */
    async makeAuthenticatedRequest(url, options = {}) {
        const token = await this.getValidToken();
        
        const authOptions = {
            ...options,
            headers: {
                ...options.headers,
                'Authorization': `Bearer ${token}`
            }
        };

        const response = await fetch(url, authOptions);
        
        // Si recibimos 401, intentar refresh una vez más
        if (response.status === 401) {
            console.log('🔄 Received 401, attempting token refresh...');
            const newToken = await this.refreshToken();
            
            authOptions.headers['Authorization'] = `Bearer ${newToken}`;
            return await fetch(url, authOptions);
        }

        return response;
    }
}

// Instancia global
const tokenService = new TokenRefreshService();

// Exportar para uso en módulos
if (typeof module !== 'undefined' && module.exports) {
    module.exports = TokenRefreshService;
} else {
    window.TokenRefreshService = TokenRefreshService;
    window.tokenService = tokenService;
}
