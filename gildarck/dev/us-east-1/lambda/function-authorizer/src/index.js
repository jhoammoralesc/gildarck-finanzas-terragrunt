const {
  SSMClient,
  PutParameterCommand,
  GetParameterCommand,
} = require("@aws-sdk/client-ssm");
const jwt = require("jsonwebtoken");
const axios = require("axios").default;

class ConfigError extends Error {
  constructor(message) {
    super(message);
    this.name = "ConfigError";
    this.statusCode = 500;
  }
}

class ServerError extends Error {
  constructor(message) {
    super(message);
    this.name = "ServerError";
    this.statusCode = 500;
  }
}

// Configure SSMClient
const ssmClient = new SSMClient();

// Validate environment variables
if (!process.env.AUTH_SECRET || !process.env.AUDIENCE) {
  console.error("Missing required environment variables");
  throw new ConfigError("Missing required environment variables");
}

exports.handler = async (event, context, callback) => {
  try {
    // Extract and validate token
    const token = extractToken(event);
    if (!token) {
      console.log("No authorization token provided");
      return callback("Unauthorized");
    }

    // Get JWKs and validate token
    let JWKs;
    try {
      JWKs = await getJWKs();
    } catch (error) {
      console.error("Error getting JWKs:", error);
      throw new ConfigError("Failed to retrieve JWKs");
    }

    // Get kid and validate token signature
    const kid = getKid(token);
    if (!kid) {
      console.error("Kid not found in token");
      return callback("Unauthorized");
    }
    if (!JWKs[kid]) {
      console.log("Kid not found in current JWKs, attempting refresh");
      try {
        JWKs = await refreshJWKs();
        if (!JWKs) {
          console.error("Failed to refresh JWKs");
          return callback("Unauthorized");
        }
        if (!JWKs[kid]) {
          console.error("Kid not found after refresh");
          return callback("Unauthorized");
        }
      } catch (error) {
        console.error("Error refreshing JWKs:", error);
        return callback("Unauthorized");
      }
    }

    // Verify token
    const verificationResult = verifyToken(token, JWKs[kid]);
    if (verificationResult instanceof Error) {
      console.info("Token verification failed:", verificationResult);
      return callback("Unauthorized");
    }

    // Validate audience
    if (verificationResult.aud !== process.env.AUDIENCE) {
      console.info("Invalid token audience:", {
        expected: process.env.AUDIENCE,
        received: verificationResult.aud,
      });
      return callback("Unauthorized");
    }

    // Generate and return policy
    const policy = generatePolicy(
      verificationResult.user_id,
      "Allow",
      event.methodArn
    );

    // Add custom context
    policy.context = {
      user_id: verificationResult.user_id,
      token: `Bearer ${token}`,
    };
    return callback(null, policy);
  } catch (error) {
    console.error("Unexpected error in authorization flow:", {
      error,
    });
    throw new ServerError("Validate lambda logic failed: 500");
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
    console.info("Error extracting token:", error);
    return null;
  }
}

async function getJWKs() {
  try {
    const response = await ssmClient.send(
      new GetParameterCommand({
        Name: process.env.AUTH_SECRET,
        WithDecryption: true,
      })
    );
    return JSON.parse(response.Parameter.Value);
  } catch (error) {
    console.error("Error retrieving JWKs from parameter store:", error);
    throw new ConfigError("Failed to retrieve JWKs from parameter store");
  }
}

async function refreshJWKs() {
  try {
    const response = await axios.get(
      "https://www.googleapis.com/robot/v1/metadata/x509/securetoken@system.gserviceaccount.com"
    );
    const newJWKs = response.data;
    await saveNewFirebaseKeyParameterStore(newJWKs, process.env.AUTH_SECRET);
    return newJWKs;
  } catch (error) {
    console.error("Error refreshing Firebase keys:", error);
    throw new ConfigError("Error refreshing Firebase keys");
  }
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
    return null;
  }
}

function verifyToken(token, key) {
  try {
    return jwt.verify(token, key, { algorithms: ["RS256"] });
  } catch (error) {
    console.info("Error verifying token:", error);
    return error;
  }
}

async function saveNewFirebaseKeyParameterStore(keys, parameterName) {
  try {
    const command = new PutParameterCommand({
      Name: parameterName,
      Value: JSON.stringify(keys),
      Type: "SecureString",
      Overwrite: true,
    });
    return await ssmClient.send(command);
  } catch (error) {
    console.error("Error saving new Firebase keys to parameter store:", error);
    throw new ConfigError("Error saving new Firebase keys to parameter store");
  }
}

function generatePolicy(principalId, effect, resource) {
  const authResponse = {};
  authResponse.principalId = principalId;
  if (effect && resource) {
    const policyDocument = {};
    policyDocument.Version = "2012-10-17";
    policyDocument.Statement = [];
    const statementOne = {};
    statementOne.Action = "execute-api:Invoke";
    statementOne.Effect = effect;
    statementOne.Resource = resource;
    policyDocument.Statement[0] = statementOne;
    authResponse.policyDocument = policyDocument;
  }
  return authResponse;
}
