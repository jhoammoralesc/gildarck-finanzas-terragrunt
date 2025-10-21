const {
  CognitoIdentityProviderClient,
  AdminUpdateUserAttributesCommand,
  InitiateAuthCommand,
} = require("@aws-sdk/client-cognito-identity-provider");

const client = new CognitoIdentityProviderClient({
  region: process.env.AWS_REGION,
});

// Configuration
const CONFIG = {
  USER_POOL_ID: process.env.USER_POOL_ID,
  CLIENT_ID: process.env.CLIENT_ID,
  REGION: process.env.AWS_REGION,
};

// Class to handle custom errors
class AuthError extends Error {
  constructor(message, statusCode) {
    super(message);
    this.statusCode = statusCode;
  }
}

// Main Lambda function
exports.handler = async (event) => {
  try {
    if (event.httpMethod !== "POST") {
      throw new AuthError("Method Not Allowed", 405);
    }

    const authHeader = event.headers?.Authorization;
    if (!authHeader) {
      return createResponse(401, {
        error: "MISSING_CREDENTIALS",
        message: "Authentication required",
      });
    }

    if (event.path === "/auth/refresh") {
      if (!authHeader.startsWith("Bearer ")) {
        return createResponse(401, {
          error: "INVALID_AUTH_TYPE",
          message: "Bearer token required for refresh",
        });
      }
      return handleRefreshToken(event);
    } else if (event.path === "/auth/login") {
      if (!authHeader.startsWith("Basic ")) {
        return createResponse(401, {
          error: "INVALID_AUTH_TYPE",
          message: "Basic authentication required for login",
        });
      }
      return handleLogin(event);
    } else {
      return createResponse(404, {
        error: "PATH_NOT_FOUND",
        message: "Path not found",
      });
    }
  } catch (error) {
    console.error("Error:", error);
    return createResponse(500, {
      error: "INTERNAL_SERVER_ERROR",
      message: "An internal server error occurred",
    });
  }
};

const handleLogin = async (event) => {
  if (!event.headers?.Scope && !event.headers?.scope) {
    return createResponse(400, {
      error: "MISSING_SCOPE",
      message: "Scope header is required",
    });
  }

  // Decode credentials
  const credentials = decodeCredentials(event.headers.Authorization);
  if (!credentials) {
    return createResponse(400, {
      error: "INVALID_CREDENTIALS",
      message: "Invalid credentials format",
    });
  }
  const { username, password } = credentials;

  // Validate scopes
  const scope = event.headers?.Scope
    ? event.headers?.Scope?.split(" ")
    : event.headers?.scope?.split(" ");
  const requestedScopes = scope;
  const validationScopes = validateScopes(requestedScopes);
  if (!validationScopes) {
    return createResponse(400, {
      error: "INVALID_SCOPE",
      message: "Invalid scope format",
    });
  }

  // Authenticate user
  const authResult = await authenticateUser(
    username,
    password,
    requestedScopes
  );

  if (!authResult) {
    return createResponse(401, {
      error: "INVALID_CREDENTIALS",
      message: "Invalid username or password",
    });
  }

  if (
    authResult.ChallengeName &&
    authResult.ChallengeName === "NEW_PASSWORD_REQUIRED"
  ) {
    return createResponse(401, {
      error: "INVALID_CREDENTIALS",
      message: "Please change your temporal password using the APIM portal.",
    });
  }

  // Generate response
  return createResponse(200, {
    access_token: authResult.AuthenticationResult.AccessToken,
    refresh_token: authResult.AuthenticationResult.RefreshToken,
    expires_in: authResult.AuthenticationResult.ExpiresIn,
  });
};

const handleRefreshToken = async (event) => {
  try {
    const refreshToken = event.headers.Authorization.replace(
      "Bearer ",
      ""
    ).trim();

    const params = {
      AuthFlow: "REFRESH_TOKEN_AUTH",
      ClientId: CONFIG.CLIENT_ID,
      UserPoolId: CONFIG.USER_POOL_ID,
      AuthParameters: {
        REFRESH_TOKEN: refreshToken,
      },
    };

    const command = new InitiateAuthCommand(params);
    const result = await client.send(command);

    return createResponse(200, {
      access_token: result.AuthenticationResult.AccessToken,
      expires_in: result.AuthenticationResult.ExpiresIn,
    });
  } catch (error) {
    console.error("Refresh Token Error:", error);
    return createResponse(401, {
      error: "INVALID_REFRESH_TOKEN",
      message: "Invalid refresh token",
    });
  }
};

// Function to decode credentials
const decodeCredentials = (authHeader) => {
  try {
    const base64Credentials = authHeader.split(" ")[1];
    const credentials = Buffer.from(base64Credentials, "base64").toString(
      "ascii"
    );
    const [username, password] = credentials.split(":");

    if (!username || !password) {
      return false;
    }

    return { username, password };
  } catch (error) {
    return false;
  }
};

// Function to validate scopes
const validateScopes = (scopes) => {
  const validScopePattern = /^[a-z]+(?:\.[a-z]+)*$/;
  const isValid = scopes.every((scope) => validScopePattern.test(scope));

  if (!isValid) {
    return false;
  }
  return true;
};

// Function to authenticate user with Cognito
const authenticateUser = async (username, password, requestedScopes) => {
  try {
    const params = {
      AuthFlow: "USER_PASSWORD_AUTH",
      ClientId: CONFIG.CLIENT_ID,
      UserPoolId: CONFIG.USER_POOL_ID,
      AuthParameters: {
        USERNAME: username,
        PASSWORD: password,
      },
    };

    // Set request scopes in custom attribute
    const updateParams = {
      UserPoolId: CONFIG.USER_POOL_ID,
      Username: username,
      UserAttributes: [
        {
          Name: "custom:requested_scopes",
          Value: requestedScopes.join(" "),
        },
      ],
    };

    await client.send(new AdminUpdateUserAttributesCommand(updateParams));
    const command = new InitiateAuthCommand(params);
    return await client.send(command);
  } catch (error) {
    return false;
  }
};

// Function to create HTTP response
const createResponse = (statusCode, body, headers = {}) => {
  return {
    statusCode,
    headers: {
      "Content-Type": "application/json",
      "Access-Control-Allow-Origin": "*", // Configure according to your CORS needs
      "Access-Control-Allow-Headers": "Content-Type,Authorization,Scope",
      ...headers,
    },
    body: JSON.stringify(body),
  };
};
