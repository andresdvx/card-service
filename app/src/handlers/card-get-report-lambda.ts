import type { APIGatewayEvent, APIGatewayProxyResult } from "aws-lambda";
import { DynamoDBService } from "../services/dynamodb/dynamodb.service.js";
import { S3Service } from "../services/s3/s3.service.js";

export const handler = async (
  event: APIGatewayEvent
): Promise<APIGatewayProxyResult> => {
  try {
    const body = JSON.parse(event.body || "{}");
    const TRANSACTION_TABLE_NAME = process.env.DYNAMODB_TRANSACTION_TABLE!;
    const S3_BUCKET = process.env.S3_BUCKET_NAME!;
    const REGION = "us-west-1";

    const { start, end } = body;

    if (!start || !end) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "start and end are required" }),
      };
    }

    const dynamoDBService = new DynamoDBService();
    const s3Service = new S3Service(S3_BUCKET);

    // Buscar transacciones en el rango de fechas
    const transactionsRes = await dynamoDBService.scanTable({
      TableName: TRANSACTION_TABLE_NAME,
      FilterExpression: "createdAt BETWEEN :start AND :end",
      ExpressionAttributeValues: {
        ":start": start,
        ":end": end,
      },
    });

    const transactions = transactionsRes.Items || [];

    // Crear contenido del archivo txt
    const fileContent = transactions
      .map((tx: Record<string, any>) => JSON.stringify(tx))
      .join("\n");
    const fileName = `report-${Date.now()}.txt`;

    // Subir archivo a S3
    await s3Service.uploadTxtFile(fileName, fileContent);

    // Construir URL pública del archivo
    const fileUrl = `https://${S3_BUCKET}.s3.${REGION}.amazonaws.com/${fileName}`;

    return {
      statusCode: 200,
      body: JSON.stringify({ url: fileUrl }),
    };
  } catch (error) {
    console.error(error);
    return {
      statusCode: 500,
      body: JSON.stringify({
        error: "Internal server error",
        details: error instanceof Error ? error.message : error,
      }),
    };
  }
};
