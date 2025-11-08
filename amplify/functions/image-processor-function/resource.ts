import { defineFunction } from "@aws-amplify/backend";

export const ImageProcessorFunction = defineFunction({
  name: "image-processor-function",
  environment: {
    DYNAMODB_TABLE_NAME: "finanzas_usuarios",
    TEXTRACT_REGION: "us-east-1",
  },
});
