const axios = require("axios").default;
const API_URL = process.env.API_URL;

/**
 * Función principal del Lambda para eventos de EventBridge
 */
exports.handler = async (event, context) => {
  try {
    console.log("Evento recibido:", JSON.stringify(event));

    // Extraer el bucket y el key del evento EventBridge
    const bucket = event.detail.bucket.name;
    const key = event.detail.object.key;

    console.log(`Procesando archivo: ${key} en bucket: ${bucket}`);

    // Extraer el ID de compañía y el nombre del archivo
    const pathParts = key.split("/");
    const companyId = pathParts[0]; // Asumiendo que el ID de compañía está en la primera parte
    const filePath = `${companyId}/rtp/in/`;
    const fileName = pathParts[pathParts.length - 1];

    if (
      pathParts.length !== 4 ||
      pathParts[1] !== "rtp" ||
      pathParts[2] !== "in" ||
      !fileName.endsWith('.csv')
    ) {
      console.error("El path o el nombre del archivo no son válidos.");
      return {
        statusCode: 400,
        body: JSON.stringify({
          message: "El path o el nombre del archivo no son válidos.",
        }),
      };
    }

    // Hacer el llamado a la API
    const response = await axios.post(API_URL, {
      commercialId: companyId,
      fileName: fileName,
      filePath: filePath,
    });

    console.log("Response from API:", response);
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: "Lambda function executed successfully",
      }),
    };
  } catch (error) {
    console.error("Error en el Lambda:", error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: "Error to execute the Lambda function",
        error: error.message,
      }),
    };
  }
};
