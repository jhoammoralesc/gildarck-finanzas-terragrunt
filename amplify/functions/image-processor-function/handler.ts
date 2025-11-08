import { S3Event, S3Handler } from 'aws-lambda';
import { TextractClient, AnalyzeDocumentCommand } from '@aws-sdk/client-textract';
import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb';
import { S3Client, GetObjectCommand } from '@aws-sdk/client-s3';

const textractClient = new TextractClient({ region: process.env.TEXTRACT_REGION || 'us-east-1' });
const dynamoClient = new DynamoDBClient({ region: process.env.AWS_REGION });
const s3Client = new S3Client({ region: process.env.AWS_REGION });

export const handler: S3Handler = async (event: S3Event) => {
  console.log('Processing S3 event:', JSON.stringify(event, null, 2));

  for (const record of event.Records) {
    const bucket = record.s3.bucket.name;
    const key = decodeURIComponent(record.s3.object.key.replace(/\+/g, ' '));
    
    // Solo procesar imágenes en la carpeta photos/
    if (!key.startsWith('photos/')) {
      console.log(`Skipping file ${key} - not in photos/ folder`);
      continue;
    }

    try {
      console.log(`Processing image: ${bucket}/${key}`);
      
      // Obtener la imagen de S3
      const getObjectCommand = new GetObjectCommand({
        Bucket: bucket,
        Key: key,
      });
      
      const s3Response = await s3Client.send(getObjectCommand);
      const imageBytes = await s3Response.Body?.transformToByteArray();
      
      if (!imageBytes) {
        throw new Error('Failed to get image bytes from S3');
      }

      // Procesar con Textract
      const textractCommand = new AnalyzeDocumentCommand({
        Document: {
          Bytes: imageBytes,
        },
        FeatureTypes: ['TABLES', 'FORMS'],
      });

      const textractResponse = await textractClient.send(textractCommand);
      
      // Extraer texto y datos
      const extractedData = extractFinancialData(textractResponse);
      
      // Guardar en DynamoDB
      if (extractedData.valid) {
        await saveTransaction(extractedData, key);
        console.log(`Successfully processed and saved transaction for ${key}`);
      } else {
        console.log(`Invalid financial data extracted from ${key}`);
      }
      
    } catch (error) {
      console.error(`Error processing ${key}:`, error);
    }
  }
};

function extractFinancialData(textractResponse: any) {
  const blocks = textractResponse.Blocks || [];
  let fullText = '';
  let amounts: number[] = [];
  
  // Extraer texto de todos los bloques
  blocks.forEach((block: any) => {
    if (block.BlockType === 'LINE') {
      fullText += block.Text + '\n';
      
      // Buscar números que parezcan precios
      const priceMatches = block.Text.match(/\$?[\d,\.]+/g);
      if (priceMatches) {
        priceMatches.forEach((price: string) => {
          const cleanPrice = price.replace(/[$,\.]/g, '');
          if (cleanPrice.length >= 3) {
            amounts.push(parseInt(cleanPrice));
          }
        });
      }
    }
  });

  // Determinar el total (número más grande)
  const totalAmount = amounts.length > 0 ? Math.max(...amounts) : 0;
  
  // Categorizar basado en el texto
  let category = 'otro_gasto';
  const text = fullText.toLowerCase();
  
  if (text.includes('supermercado') || text.includes('alimentos') || 
      text.includes('arroz') || text.includes('pollo') || text.includes('comida')) {
    category = 'comida';
  } else if (text.includes('gasolina') || text.includes('combustible')) {
    category = 'transporte';
  } else if (text.includes('farmacia') || text.includes('medicina')) {
    category = 'salud';
  } else if (text.includes('restaurante') || text.includes('bar')) {
    category = 'entretenimiento';
  }

  // Determinar si es ocio
  const isLeisure = category === 'entretenimiento' || 
                   text.includes('cine') || text.includes('bar') || 
                   text.includes('restaurante');

  return {
    user_id: 'system', // Se puede obtener del path del archivo
    transaction_id: `img_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`,
    amount: totalAmount,
    type: 'expense',
    description: `Compra procesada automáticamente: ${fullText.substring(0, 100)}`,
    category,
    is_leisure: isLeisure,
    timestamp: new Date().toISOString(),
    currency: 'COP',
    confidence: amounts.length > 0 ? 0.8 : 0.3,
    processing_method: 'textract_lambda',
    reasoning: `Procesado automáticamente desde imagen. Encontrados ${amounts.length} precios.`,
    original_text: fullText,
    date_only: new Date().toISOString().split('T')[0],
    month_year: new Date().toISOString().substring(0, 7),
    valid: totalAmount > 0,
  };
}

async function saveTransaction(data: any, imageKey: string) {
  const putCommand = new PutItemCommand({
    TableName: process.env.DYNAMODB_TABLE_NAME || 'finanzas_usuarios',
    Item: {
      user_id: { S: data.user_id },
      transaction_id: { S: data.transaction_id },
      amount: { N: data.amount.toString() },
      type: { S: data.type },
      description: { S: data.description },
      category: { S: data.category },
      is_leisure: { BOOL: data.is_leisure },
      timestamp: { S: data.timestamp },
      currency: { S: data.currency },
      confidence: { N: data.confidence.toString() },
      processing_method: { S: data.processing_method },
      reasoning: { S: data.reasoning },
      original_text: { S: data.original_text },
      date_only: { S: data.date_only },
      month_year: { S: data.month_year },
      image_key: { S: imageKey }, // Referencia a la imagen original
    },
  });

  await dynamoClient.send(putCommand);
}
