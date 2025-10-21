const jwt = require("jsonwebtoken");
const axios = require("axios").default;
const jwkToPem = require("jwk-to-pem");
let JWKs;
const BASE_URL = process.env.BASE_URL ?? "https://k8s.dev.gildarck.com";
exports.handler = async (event, context, callback) => {
  const token = extractToken(event);

  if (!token) {
    console.log("No authorization token provided");
    return callback("Unauthorized");
  }

  try {
    JWKs = await getJWKs();
  } catch (error) {
    console.error("Error getting JWKs:", error);
    return callback("Unauthorized");
  }

  const kid = getKid(token);
  if (!findKey(kid)) {
    console.log("Kid not found in current JWKs, attempting refresh");
    try {
      JWKs = null;
      JWKs = await getJWKs();
      if (!findKey(kid)) {
        console.error("Kid not found after refresh");
        return callback("Unauthorized");
      }
    } catch (error) {
      console.error("Error refreshing JWKs:", error);
      return callback("Unauthorized");
    }
  }

  try {
    // Decodifica el token sin verificar la firma.
    const publicKey = jwkToPem(findKey(kid));
    const verificationResult = verifyToken(token, publicKey);
    if (verificationResult instanceof Error) {
      console.error("Token verification failed:", verificationResult);
      return callback("Unauthorized");
    }

    //Token validado
    let policy = generatePolicy("flexibility", "Allow", event.methodArn);
    policy.context = {
      Authorization: `Bearer ${token}`,
    };
    callback(null, policy);
  } catch (err) {
    console.error("ERROR:::::", err);
    callback("Unauthorized");
  }
};

function extractToken(event) {
  try {
    const authHeader =
      event.headers.Authorization || event.headers.authorization;
    if (!authHeader) {
      console.log("No authorization header found");
      return null;
    }
    return authHeader.replace("Bearer ", "");
  } catch (error) {
    console.error("Error extracting token:", error);
    return null;
  }
}

async function getJWKs() {
  try {
    // Check if JWKs already exists
    if (JWKs) {
      return JWKs;
    }

    const response = await axios({
      method: "get",
      url: `${BASE_URL}/auth-server/oauth2/jwks`,
    });

    // Store the response in JWKs
    JWKs = response.data.keys ?? {};
    return JWKs;
  } catch (error) {
    console.error("Error retrieving JWKs:", error);
    throw new Error("Failed to retrieve JWKs");
  }
}

function generatePolicy(principalId, effect, resource) {
  var authResponse = {};

  authResponse.principalId = principalId;
  if (effect && resource) {
    var policyDocument = {};
    policyDocument.Version = "2012-10-17";
    policyDocument.Statement = [];
    var statementOne = {};
    statementOne.Action = "execute-api:Invoke";
    statementOne.Effect = effect;
    statementOne.Resource = resource;
    policyDocument.Statement[0] = statementOne;
    authResponse.policyDocument = policyDocument;
  }
  return authResponse;
}

function getKid(token) {
  try {
    const header64 = token.split(".")[0];
    const { kid } = JSON.parse(
      Buffer.from(header64, "base64").toString("ascii")
    );
    return kid;
  } catch (error) {
    console.error("Error extracting kid from token:", error);
    throw new AuthError("Invalid token format");
  }
}

function findKey(kid) {
  // Check if JWKs is an array
  if (Array.isArray(JWKs)) {
    // Find the key object that matches the provided kid
    const keyFound = JWKs.find((key) => key.kid === kid);

    // Return the key object if found, undefined if not found
    return keyFound;
  }

  // If JWKs is an object (original implementation)
  return JWKs[kid];
}

function verifyToken(token, key) {
  try {
    return jwt.verify(token, key, { algorithms: ["RS256"] });
  } catch (error) {
    console.error("Error verifying token:", error);
    return error;
  }
}
