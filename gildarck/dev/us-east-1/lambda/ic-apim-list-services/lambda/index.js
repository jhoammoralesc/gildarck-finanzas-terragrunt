const env = process.env.ENV;
const services = [
  {
    id: "1",
    name: "API RTP",
    scopesPrefix: "rtp",
    description:
      "Request To Pay ofrece APIs para que los vendedores gestionen el ciclo completo de débitos inmediatos con sus compradores. Esto incluye creación, procesamiento de pagos, consultas, seguimiento, eliminación y notificaciones. La plataforma facilita transacciones de compra-venta, soporta pagos recurrentes y programados, todo dentro de un entorno seguro y eficiente.",
    imageUrl:
      "https://img.freepik.com/vector-gratis/ilustracion-concepto-informacion-pago_114360-2886.jpg",
    swaggerUrl: `https://rtp.apim.${env}.gildarck.com/rtp-manager/v1/swagger-ui`,
    baseUrl: `https://rtp.apim.${env}.gildarck.com/rtp-manager`,
    showDocumentation: true,
  },
  {
    id: "2",
    name: "API AI Documents",
    scopesPrefix: "ai",
    description:
      "API con funcionalidad de automatización con AI para la lectura e interpretación de documentos fiscales PDF en Argentina. Optimiza la gestión de datos fiscales para empresas con alto volumen documental, reduciendo errores y eliminando procesos manuales.",
    imageUrl:
      "https://kmslh.com/wp-content/uploads/2021/06/shutterstock_1106002595-scaled.jpg",
    swaggerUrl: `https://ai.apim.${env}.gildarck.com/docs`,
    baseUrl: `https://ai.apim.${env}.gildarck.com`,
    showDocumentation: false,
  },
  {
    id: "3",
    name: "API Documentos deuda",
    scopesPrefix: "gildarck",
    description:
      "Servicio que habilita el envío de documentos de deuda (facturas, notas crédito, notas débito, etc) del lado de los sistemas cliente para ser disponibilizada y gestionada dentro de la plataforma de gildarck.",
    imageUrl:
      "https://images.unsplash.com/photo-1460925895917-afdab827c52f?ixlib=rb-4.0.3&auto=format&fit=crop&w=800&q=80",
    swaggerUrl: `https://gildarck.apim.${env}.gildarck.com/document-entry-manager/v1/swagger-ui`,
    baseUrl: `https://gildarck.apim.${env}.gildarck.com`,
    showDocumentation: true,
  },
];

exports.handler = async (event) => {
  try {
    return createResponse(200, {
      services,
    });
  } catch (error) {
    console.error("Error:", error);
    return handleError(error);
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

// Function to handle errors
const handleError = (error) => {
  const statusCode = error.statusCode || 500;
  const message = error.message || "Internal Server Error";

  return createResponse(statusCode, {
    error: error.code || "ERROR",
    message,
  });
};
