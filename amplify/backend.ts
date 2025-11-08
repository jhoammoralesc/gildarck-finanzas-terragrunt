import { defineBackend } from "@aws-amplify/backend";
import { Stack } from "aws-cdk-lib";
import {
  AuthorizationType,
  CognitoUserPoolsAuthorizer,
  Cors,
  LambdaIntegration,
  RestApi,
} from "aws-cdk-lib/aws-apigateway";
import { Policy, PolicyStatement } from "aws-cdk-lib/aws-iam";
import { auth } from "./auth/resource";
import { data } from "./data/resource";
import { storage } from "./storage/resource";
import { ImageProcessorFunction } from "./functions/image-processor-function/resource";

/**
 * @see https://docs.amplify.aws/react/build-a-backend/ to add storage, functions, and more
 */
const backend = defineBackend({
  auth,
  data,
  storage,
  ImageProcessorFunction,
});

const apiStack = backend.createStack("api-stack");

// REST API para finanzas
const FinanzasRestApi = new RestApi(apiStack, "RestApi", {
  restApiName: "FinanzasRestApi",
  deploy: true,
  defaultCorsPreflightOptions: {
    allowOrigins: Cors.ALL_ORIGINS,
    allowMethods: Cors.ALL_METHODS,
    allowHeaders: Cors.DEFAULT_HEADERS,
  },
});

const lambdaIntegration = new LambdaIntegration(
  backend.ImageProcessorFunction.resources.lambda
);

// Endpoint para procesar imágenes
const processPath = FinanzasRestApi.root.addResource("process-image", {
  defaultMethodOptions: {
    authorizationType: AuthorizationType.NONE,
  },
});

processPath.addMethod("POST", lambdaIntegration);

// Endpoint para obtener transacciones
const transactionsPath = FinanzasRestApi.root.addResource("transactions", {
  defaultMethodOptions: {
    authorizationType: AuthorizationType.NONE,
  },
});

transactionsPath.addMethod("GET", lambdaIntegration);
transactionsPath.addMethod("POST", lambdaIntegration);

// Permisos para Textract
backend.ImageProcessorFunction.resources.lambda.addToRolePolicy(
  new PolicyStatement({
    actions: [
      "textract:AnalyzeDocument",
      "textract:DetectDocumentText",
    ],
    resources: ["*"],
  })
);

// Permisos para DynamoDB
backend.ImageProcessorFunction.resources.lambda.addToRolePolicy(
  new PolicyStatement({
    actions: [
      "dynamodb:PutItem",
      "dynamodb:GetItem",
      "dynamodb:UpdateItem",
      "dynamodb:Query",
      "dynamodb:Scan",
    ],
    resources: ["arn:aws:dynamodb:*:*:table/finanzas_usuarios"],
  })
);

// Permisos para S3 (bucket existente)
backend.ImageProcessorFunction.resources.lambda.addToRolePolicy(
  new PolicyStatement({
    actions: ["s3:GetObject"],
    resources: ["arn:aws:s3:::gildarck-bucket-audio-transcribe-dev/*"],
  })
);

backend.addOutput({
  custom: {
    API: {
      [FinanzasRestApi.restApiName]: {
        endpoint: FinanzasRestApi.url,
        region: Stack.of(FinanzasRestApi).region,
        apiName: FinanzasRestApi.restApiName,
      },
    },
  },
});
