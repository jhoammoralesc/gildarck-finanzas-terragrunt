// const AWS = require("aws-sdk");
const jwt = require("jsonwebtoken");
const jwkToPem = require("jwk-to-pem");
const axios = require("axios").default;
const {
  CognitoIdentityProviderClient,
  AdminGetUserCommand,
} = require("@aws-sdk/client-cognito-identity-provider");

const region = process.env.AWS_REGION || "us-east-1";
const userPoolId = process.env.USER_POOL_ID;

const allowedScopes = [
  "gildarck.renditions.read",
  "gildarck.externallogin.write",
  "gildarck.renditionsintrument.read",
];

// Cache para almacenar las claves públicas de Cognito
let cacheKeys = null;

/**
 * Obtiene las claves públicas del User Pool de Cognito
 */
const getPublicKeys = async () => {
  if (cacheKeys) return cacheKeys;

  const jwksUrl = `https://cognito-idp.${region}.amazonaws.com/${userPoolId}/.well-known/jwks.json`;
  const response = await axios.get(jwksUrl);

  const keys = {};
  response.data.keys.forEach((key) => {
    keys[key.kid] = jwkToPem(key);
  });

  cacheKeys = keys;
  return keys;
};

/**
 * Verifica el JWT token de Cognito
 */
const verifyToken = async (token) => {
  try {
    // Extrae el token si viene como "Bearer ..."
    if (token.startsWith("Bearer ")) {
      token = token.substring(7);
    }

    // Decodifica el token sin verificar para obtener el kid
    const decodedToken = jwt.decode(token, { complete: true });
    if (!decodedToken) {
      throw new Error("Token inválido");
    }

    const kid = decodedToken.header.kid;
    const keys = await getPublicKeys();
    const pem = keys[kid];

    if (!pem) {
      throw new Error("Clave pública no encontrada para verificar el token");
    }

    // Verifica y decodifica el token
    return jwt.verify(token, pem, { algorithms: ["RS256"] });
  } catch (error) {
    console.error("Error verificando token:", error);
    throw new Error("Token inválido o expirado");
  }
};

/**
 * Obtiene los atributos personalizados del usuario de Cognito
 */
const getUserAttributes = async (username) => {
  const client = new CognitoIdentityProviderClient({ region });

  try {
    const params = {
      UserPoolId: userPoolId,
      Username: username,
    };

    const command = new AdminGetUserCommand(params);
    const userData = await client.send(command);

    // Extraer atributos personalizados (custom:*)
    const customAttributes = {};
    userData.UserAttributes.forEach((attr) => {
      if (attr.Name.startsWith("custom:")) {
        customAttributes[attr.Name] = attr.Value;
      }
    });

    return customAttributes;
  } catch (error) {
    console.error("Error obteniendo atributos del usuario:", error);
    throw new Error("Error al obtener atributos del usuario");
  }
};

/**
 * Genera la política IAM para autorizar la solicitud
 */
const generatePolicy = (principalId, effect, resource, context) => {
  const authResponse = {
    principalId,
  };

  if (effect && resource) {
    const policyDocument = {
      Version: "2012-10-17",
      Statement: [
        {
          Action: "execute-api:Invoke",
          Effect: effect,
          Resource: resource,
        },
      ],
    };
    authResponse.policyDocument = policyDocument;
  }

  if (context) {
    authResponse.context = context;
  }

  return authResponse;
};

/**
 * Función principal del Lambda
 */
exports.handler = async (event, context, callback) => {
  try {
    //Print the source IP and if doesnt exist print uknown
    const sourceIp = event.requestContext?.identity?.sourceIp || "unknown";
    console.info("Source IP:", sourceIp);
    //Print the path
    console.info("Path:", event.path || "unknown");

    // Verifica si hay token de autorización
    const authHeader =
      event.headers?.Authorization || event.headers?.authorization;

    if (!authHeader) {
      return callback("Unauthorized");
    }

    // Verifica el token
    const decodedToken = await verifyToken(authHeader);

    const hasAnyScope = allowedScopes.some((scope) =>
      decodedToken.scope?.includes(scope)
    );

    if (!hasAnyScope) {
      return callback("Unauthorized");
    }

    // Obtiene el nombre de usuario de Cognito
    const username =
      decodedToken.username ||
      decodedToken["cognito:username"] ||
      decodedToken.sub;

    // Obtiene los atributos personalizados del usuario
    const userAttributes = await getUserAttributes(username);

    // Genera la política con los atributos del usuario en el contexto
    const methodArn = event.methodArn || "*";

    return callback(
      null,
      generatePolicy(username, "Allow", methodArn, userAttributes)
    );
  } catch (error) {
    console.error("Error en el authorizer:", error);
    return callback("Unauthorized");
  }
};
